"""Tests for the run progress WebSocket: auth, snapshot, live delivery, cleanup, scoping."""

import time
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any, cast

import pytest
from fastapi import FastAPI, WebSocket
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.core.db import SessionFactory
from app.core.live_sessions import LiveSessions, get_live_sessions
from app.core.progress import ProgressBus, RunEvent, RunEventType, get_progress_bus
from app.core.session import SESSION_TOKEN_HEADER, SessionTokenMiddleware
from app.core.websocket import CLOSE_POLICY_VIOLATION, CLOSE_UNAUTHENTICATED
from tests.api import PASSWORD, register_user
from tests.features.categorization.conftest import (
    RunLauncherSpy,
    StubRuntime,
    assign_all,
    seed_ledger,
)

WS = "/api/v1/runs/ws"
RUNS = "/api/v1/categorization/runs"


@pytest.fixture
def bus(client: TestClient) -> ProgressBus:
    """A fresh bus per test, so no event or subscriber leaks between tests."""
    fresh = ProgressBus()
    cast(FastAPI, client.app).dependency_overrides[get_progress_bus] = lambda: fresh
    return fresh


@pytest.fixture
def live_sessions(client: TestClient) -> LiveSessions:
    """A fresh registry per test, shared by the socket and the auth routes revoking sessions."""
    fresh = LiveSessions()
    cast(FastAPI, client.app).dependency_overrides[get_live_sessions] = lambda: fresh
    return fresh


def _login(client: TestClient, identifier: str) -> dict[str, str]:
    """Open another session of an existing user."""
    response = client.post(
        "/api/v1/auth/login", json={"identifier": identifier, "password": PASSWORD}
    )
    assert response.status_code == 200, response.json()
    return {"Authorization": f"Bearer {response.json()['token']}"}


def _event(run_id: str, event: RunEventType, done: int = 0) -> RunEvent:
    return RunEvent(
        run_id=run_id,
        kind="categorization",
        event=event,
        done=done,
        total=8,
        occurred_at=datetime(2026, 1, 15, 9, 30, tzinfo=UTC),
    )


def _wait_for(condition: Callable[[], bool], timeout: float = 5.0) -> None:
    """Poll ``condition`` until it holds: the server side reacts on its own thread."""
    deadline = time.monotonic() + timeout
    while not condition():
        assert time.monotonic() < deadline, "condition never became true"
        time.sleep(0.01)


def test_a_socket_without_a_token_is_closed_with_4401(client: TestClient, bus: ProgressBus) -> None:
    with client.websocket_connect(WS) as socket, pytest.raises(WebSocketDisconnect) as closed:
        socket.receive_json()

    assert closed.value.code == CLOSE_UNAUTHENTICATED
    assert bus.subscriber_count() == 0


def test_a_socket_with_an_unknown_token_is_closed_with_4401(
    client: TestClient, bus: ProgressBus
) -> None:
    headers = {"Authorization": "Bearer not-a-real-token"}
    with (
        client.websocket_connect(WS, headers=headers) as socket,
        pytest.raises(WebSocketDisconnect) as closed,
    ):
        socket.receive_json()

    assert closed.value.code == CLOSE_UNAUTHENTICATED


def test_connecting_sends_a_snapshot_of_the_users_active_runs(
    client: TestClient, bus: ProgressBus
) -> None:
    user = register_user(client)
    bus.publish(user.user_id, _event("run-active", "started"))
    bus.publish(user.user_id, _event("run-active", "progress", 3))
    bus.publish(user.user_id, _event("run-done", "started"))
    bus.publish(user.user_id, _event("run-done", "finished", 8))
    bus.publish("someone-else", _event("run-theirs", "started"))

    with client.websocket_connect(WS, headers=user.headers) as socket:
        snapshot = socket.receive_json()

    assert snapshot["type"] == "snapshot"
    assert [(run["run_id"], run["event"], run["done"]) for run in snapshot["runs"]] == [
        ("run-active", "progress", 3)
    ]


def test_events_are_delivered_in_order_and_only_to_their_user(
    client: TestClient, bus: ProgressBus
) -> None:
    user = register_user(client)
    other = register_user(client, "bruno@example.com")

    with client.websocket_connect(WS, headers=user.headers) as socket:
        assert socket.receive_json() == {"type": "snapshot", "runs": []}
        bus.publish(other.user_id, _event("run-theirs", "started"))
        for message in [
            _event("run-1", "started"),
            _event("run-1", "progress", 4),
            _event("run-1", "progress", 8),
            _event("run-1", "finished", 8),
        ]:
            bus.publish(user.user_id, message)

        received = [socket.receive_json() for _ in range(4)]

    assert all(message["type"] == "event" for message in received)
    assert [(m["event"]["run_id"], m["event"]["event"], m["event"]["done"]) for m in received] == [
        ("run-1", "started", 0),
        ("run-1", "progress", 4),
        ("run-1", "progress", 8),
        ("run-1", "finished", 8),
    ]


def test_disconnecting_removes_the_subscriber(client: TestClient, bus: ProgressBus) -> None:
    user = register_user(client)

    with client.websocket_connect(WS, headers=user.headers) as socket:
        socket.receive_json()
        _wait_for(lambda: bus.subscriber_count(user.user_id) == 1)

    _wait_for(lambda: bus.subscriber_count() == 0)


def test_logging_out_closes_that_sessions_socket_only(
    client: TestClient, bus: ProgressBus, live_sessions: LiveSessions
) -> None:
    user = register_user(client)
    laptop = _login(client, "amelie@example.com")

    with (
        client.websocket_connect(WS, headers=user.headers) as leaving,
        client.websocket_connect(WS, headers=laptop) as staying,
    ):
        leaving.receive_json()
        staying.receive_json()
        _wait_for(lambda: live_sessions.count(user.user_id) == 2)

        assert client.post("/api/v1/auth/logout", headers=user.headers).status_code == 204

        with pytest.raises(WebSocketDisconnect) as closed:
            leaving.receive_json()
        assert closed.value.code == CLOSE_UNAUTHENTICATED
        assert closed.value.reason == "Not authenticated"

        # The other session's socket keeps streaming.
        bus.publish(user.user_id, _event("run-1", "started"))
        assert staying.receive_json()["event"]["run_id"] == "run-1"
        assert live_sessions.count(user.user_id) == 1

    _wait_for(lambda: bus.subscriber_count() == 0 and live_sessions.count() == 0)


def test_a_password_reset_closes_every_socket_of_the_user(
    client: TestClient, bus: ProgressBus, live_sessions: LiveSessions
) -> None:
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "email": "amelie@example.com",
            "password": PASSWORD,
            "display_name": "amelie",
            "locale": "fr",
            "currency": "eur",
        },
    ).json()
    first = {"Authorization": f"Bearer {registered['token']}"}
    second = _login(client, "amelie")
    other = register_user(client, "bruno@example.com")

    with (
        client.websocket_connect(WS, headers=first) as one,
        client.websocket_connect(WS, headers=second) as two,
        client.websocket_connect(WS, headers=other.headers) as theirs,
    ):
        for socket in (one, two, theirs):
            socket.receive_json()
        _wait_for(lambda: live_sessions.count() == 3)

        reset = client.post(
            "/api/v1/auth/password-reset",
            json={
                "identifier": "amelie",
                "recovery_code": registered["recovery_code"],
                "new_password": "a-brand-new-passphrase",
            },
        )
        assert reset.status_code == 200, reset.json()

        for socket in (one, two):
            with pytest.raises(WebSocketDisconnect) as closed:
                socket.receive_json()
            assert closed.value.code == CLOSE_UNAUTHENTICATED

        # Another user's socket is untouched.
        bus.publish(other.user_id, _event("run-theirs", "started"))
        assert theirs.receive_json()["event"]["run_id"] == "run-theirs"


def test_a_categorization_run_streams_its_progress_end_to_end(
    client: TestClient,
    bus: ProgressBus,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    user = register_user(client)
    seed_ledger(
        api_session_factory,
        [(f"CAFE DU PORT {index}", "uncategorized", True) for index in range(3)],
        user_id=user.user_id,
    )
    runtime.default = assign_all(3)

    with client.websocket_connect(WS, headers=user.headers) as socket:
        assert socket.receive_json()["runs"] == []
        run = client.post(RUNS, json={"scope": "pending"}, headers=user.headers).json()
        launcher.drain()

        events = [socket.receive_json()["event"] for _ in range(3)]

    assert [event["event"] for event in events] == ["started", "progress", "finished"]
    assert all(event["run_id"] == run["id"] for event in events)
    assert events[-1]["done"] == events[-1]["total"] == 3
    assert events[-1]["counts"] == {"assigned": 3, "deferred": 0, "failed": 0}
    # And the REST snapshot agrees with the last event.
    polled = client.get(f"{RUNS}/{run['id']}", headers=user.headers).json()
    assert polled["status"] == "success"
    assert polled["processed_count"] == 3


def test_cancelling_a_run_publishes_cancelled(
    client: TestClient,
    bus: ProgressBus,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    user = register_user(client)
    seed_ledger(
        api_session_factory,
        [("CAFE DU PORT", "uncategorized", True)],
        user_id=user.user_id,
    )
    run = client.post(RUNS, json={"scope": "pending"}, headers=user.headers).json()
    # The run is still pending: put it on the bus as the executor would on starting it.
    bus.publish(user.user_id, _event(run["id"], "started"))

    with client.websocket_connect(WS, headers=user.headers) as socket:
        assert [entry["run_id"] for entry in socket.receive_json()["runs"]] == [run["id"]]
        client.post(f"{RUNS}/{run['id']}/cancel", headers=user.headers)
        cancelled = socket.receive_json()["event"]

    assert (cancelled["run_id"], cancelled["event"]) == (run["id"], "cancelled")
    assert bus.active_runs(user.user_id) == []
    launcher.discard()


def test_the_session_token_middleware_refuses_a_socket_at_the_handshake() -> None:
    app = FastAPI()

    @app.websocket("/ws")
    async def echo(websocket: WebSocket) -> None:
        await websocket.accept()
        await websocket.close()

    guarded: Any = SessionTokenMiddleware(app, token="launch-token")
    with TestClient(guarded) as client:
        with pytest.raises(WebSocketDisconnect) as refused, client.websocket_connect("/ws"):
            pass
        assert refused.value.code == CLOSE_POLICY_VIOLATION

        with client.websocket_connect("/ws", headers={SESSION_TOKEN_HEADER: "launch-token"}):
            pass
