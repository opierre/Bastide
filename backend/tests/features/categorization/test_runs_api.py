"""Tests for the run endpoints: the 202 shape, single-in-flight, history, cancel, scoping."""

from fastapi.testclient import TestClient

from app.core.db import SessionFactory
from tests.features.categorization.conftest import (
    GROCERIES_ID,
    Ledger,
    RunLauncherSpy,
    StubRuntime,
    assign_all,
    read_transaction,
    seed_ledger,
)

RUNS = "/api/v1/categorization/runs"

RUN_FIELDS = {
    "id",
    "account_id",
    "import_batch_id",
    "trigger",
    "status",
    "model_tag",
    "total_count",
    "processed_count",
    "assigned_count",
    "deferred_count",
    "failed_count",
    "error_message",
    "started_at",
    "finished_at",
    "created_at",
}


def _register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    return {"Authorization": f"Bearer {response.json()['token']}"}


def _me(client: TestClient, headers: dict[str, str]) -> str:
    return client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"]


def _seed(
    api_session_factory: SessionFactory,
    client: TestClient,
    headers: dict[str, str],
    row_count: int = 3,
) -> Ledger:
    """Give a registered user an account with ``row_count`` uncategorised transactions."""
    return seed_ledger(
        api_session_factory,
        [(f"CARREFOUR {index}", "uncategorized", True) for index in range(row_count)],
        user_id=_me(client, headers),
    )


def test_post_returns_202_with_the_full_run_shape(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    _seed(api_session_factory, client, headers)

    response = client.post(RUNS, json={"scope": "pending"}, headers=headers)

    assert response.status_code == 202
    body = response.json()
    assert set(body) == RUN_FIELDS
    # Accepted, not done: the row counts are what the run intends, not what it achieved.
    assert body["status"] == "pending"
    assert body["trigger"] == "manual"
    assert body["total_count"] == 3
    assert body["processed_count"] == 0
    assert body["started_at"] is None
    assert body["finished_at"] is None
    launcher.discard()


def test_the_run_executes_in_the_background_and_the_poll_shows_it_finished(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    ledger = _seed(api_session_factory, client, headers)
    runtime.default = assign_all(3)

    accepted = client.post(RUNS, json={"scope": "pending"}, headers=headers).json()
    assert launcher.drain() == 1

    polled = client.get(f"{RUNS}/{accepted['id']}", headers=headers)

    assert polled.status_code == 200
    assert polled.json()["status"] == "success"
    assert polled.json()["assigned_count"] == 3
    assert read_transaction(api_session_factory, ledger.transaction_ids[0]).category_id == (
        GROCERIES_ID
    )


def test_a_second_post_while_one_is_in_flight_returns_the_existing_run(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    _seed(api_session_factory, client, headers)

    first = client.post(RUNS, json={"scope": "pending"}, headers=headers).json()
    second = client.post(RUNS, json={"scope": "pending"}, headers=headers)

    assert second.status_code == 202
    assert second.json()["id"] == first["id"]
    # And no second executor was scheduled over the same rows.
    assert len(launcher.pending) == 1
    assert len(client.get(RUNS, headers=headers).json()) == 1
    launcher.discard()


def test_a_new_run_is_accepted_once_the_previous_one_finished(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    _seed(api_session_factory, client, headers)
    runtime.default = assign_all(3)

    first = client.post(RUNS, json={"scope": "pending"}, headers=headers).json()
    launcher.drain()
    second = client.post(RUNS, json={"scope": "all"}, headers=headers).json()

    assert second["id"] != first["id"]
    launcher.discard()


def test_history_is_newest_first_and_honours_limit(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    _seed(api_session_factory, client, headers)

    created = []
    for _ in range(3):
        created.append(client.post(RUNS, json={"scope": "pending"}, headers=headers).json()["id"])
        launcher.drain()

    history = client.get(RUNS, headers=headers)
    limited = client.get(RUNS, params={"limit": 2}, headers=headers)

    assert history.status_code == 200
    assert [run["id"] for run in history.json()] == list(reversed(created))
    assert [run["id"] for run in limited.json()] == list(reversed(created))[:2]


def test_cancel_stops_an_in_flight_run(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    ledger = _seed(api_session_factory, client, headers)

    accepted = client.post(RUNS, json={"scope": "pending"}, headers=headers).json()
    cancelled = client.post(f"{RUNS}/{accepted['id']}/cancel", headers=headers)

    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"
    assert cancelled.json()["finished_at"] is not None

    # The executor, when it does get its turn, notices and never asks the runtime anything.
    launcher.drain()
    assert runtime.calls == []
    assert read_transaction(api_session_factory, ledger.transaction_ids[0]).needs_review is True


def test_cancelling_a_finished_run_is_a_409(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    _seed(api_session_factory, client, headers)
    runtime.default = assign_all(3)
    accepted = client.post(RUNS, json={"scope": "pending"}, headers=headers).json()
    launcher.drain()

    response = client.post(f"{RUNS}/{accepted['id']}/cancel", headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "CATEGORIZATION_RUN_NOT_CANCELLABLE"
    # Not a silent no-op: the run still reports the success it actually had.
    assert client.get(f"{RUNS}/{accepted['id']}", headers=headers).json()["status"] == "success"


def test_an_unknown_run_is_a_404_in_the_error_envelope(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)

    response = client.get(f"{RUNS}/does-not-exist", headers=headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "CATEGORIZATION_RUN_NOT_FOUND"


def test_a_run_for_an_account_the_user_does_not_own_is_a_404(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    alice = _register(client, "alice@example.com")
    bob = _register(client, "bob@example.com")
    bobs_ledger = _seed(api_session_factory, client, bob)

    response = client.post(
        RUNS, json={"scope": "pending", "account_id": bobs_ledger.account_id}, headers=alice
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"
    assert launcher.pending == []


def test_runs_are_user_scoped(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    alice = _register(client, "alice@example.com")
    bob = _register(client, "bob@example.com")
    _seed(api_session_factory, client, alice)
    _seed(api_session_factory, client, bob)

    alices_run = client.post(RUNS, json={"scope": "pending"}, headers=alice).json()

    assert client.get(RUNS, headers=bob).json() == []
    assert client.get(f"{RUNS}/{alices_run['id']}", headers=bob).status_code == 404
    assert client.post(f"{RUNS}/{alices_run['id']}/cancel", headers=bob).status_code == 404
    launcher.discard()


def test_one_users_in_flight_run_does_not_block_another_users(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    alice = _register(client, "alice@example.com")
    bob = _register(client, "bob@example.com")
    _seed(api_session_factory, client, alice)
    _seed(api_session_factory, client, bob)

    alices_run = client.post(RUNS, json={"scope": "pending"}, headers=alice).json()
    bobs_run = client.post(RUNS, json={"scope": "pending"}, headers=bob)

    assert bobs_run.status_code == 202
    assert bobs_run.json()["id"] != alices_run["id"]
    launcher.discard()


def test_the_endpoints_require_authentication(client: TestClient) -> None:
    assert client.post(RUNS, json={"scope": "pending"}).status_code == 401
    assert client.get(RUNS).status_code == 401
    assert client.get(f"{RUNS}/any").status_code == 401
    assert client.post(f"{RUNS}/any/cancel").status_code == 401


def test_an_unknown_scope_is_rejected(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)

    assert client.post(RUNS, json={"scope": "everything"}, headers=headers).status_code == 422
    assert client.post(RUNS, json={}, headers=headers).status_code == 422
