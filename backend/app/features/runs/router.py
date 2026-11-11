"""The run progress WebSocket: a snapshot of the user's active runs, then every event live.

The REST snapshot endpoints (`GET /categorization/runs/{id}`) stay the source of truth for one
run; this socket only saves the app from polling them while something is in flight.
"""

import asyncio
import contextlib
import logging
import threading
from typing import Annotated

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.core.db import SessionFactory, get_session_factory
from app.core.errors import AuthError
from app.core.live_sessions import LiveSessions, get_live_sessions
from app.core.progress import (
    ProgressBus,
    RunEventMessage,
    RunSnapshotMessage,
    Subscription,
    get_progress_bus,
)
from app.core.websocket import CLOSE_UNAUTHENTICATED, sends
from app.features.auth.deps import bearer_token
from app.features.auth.repository import AuthRepository
from app.features.auth.service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/runs", tags=["runs"])


def _authenticate(websocket: WebSocket, session_factory: SessionFactory) -> tuple[str, str] | None:
    """Resolve the socket's bearer token to its user's and session's ids, or None.

    Uses a DB session closed straight after: a request-scoped `get_db` session would stay open
    for the life of the connection, and the token isn't re-read — revoking its session closes
    the socket through `LiveSessions` instead.
    """
    db = session_factory()
    try:
        token = bearer_token(websocket.headers.get("authorization"))
        user, session_id = AuthService(AuthRepository(db)).get_session(token)
        return user.id, session_id
    except AuthError:
        return None
    finally:
        db.close()


@router.websocket("/ws")
@sends(RunSnapshotMessage, RunEventMessage)
async def stream_runs(
    websocket: WebSocket,
    session_factory: Annotated[SessionFactory, Depends(get_session_factory)],
    bus: Annotated[ProgressBus, Depends(get_progress_bus)],
    live_sessions: Annotated[LiveSessions, Depends(get_live_sessions)],
) -> None:
    """Stream the caller's run events: a `RunSnapshotMessage`, then one `RunEventMessage` each.

    Authenticated on connect with the same `Authorization: Bearer` header as the REST API. A
    missing or invalid token is accepted then closed with code 4401, so the client can tell
    "log in again" from a network failure. The socket is also closed with 4401 when its
    session ends — logout, or a password reset revoking every session. Messages the client
    sends are ignored.
    """
    identity = _authenticate(websocket, session_factory)
    await websocket.accept()
    if identity is None:
        await _close_unauthenticated(websocket)
        return
    user_id, session_id = identity

    # Set from whichever thread revokes the session, before the subscription is ended.
    revoked = threading.Event()
    with bus.subscribe(user_id) as subscription:

        def end_revoked() -> None:
            revoked.set()
            subscription.close()

        with live_sessions.register(session_id, user_id, end_revoked):
            # A logout landing between the first check and the registration would be missed:
            # check again now that a revocation can no longer slip past.
            if _authenticate(websocket, session_factory) is None:
                await _close_unauthenticated(websocket)
                return
            await _stream(websocket, subscription)
    if revoked.is_set():
        await _close_unauthenticated(websocket)


async def _stream(websocket: WebSocket, subscription: Subscription) -> None:
    """Send the snapshot then every event, until the subscription ends or the client leaves."""
    watcher = asyncio.create_task(_close_on_disconnect(websocket, subscription))
    try:
        await websocket.send_json(
            RunSnapshotMessage(runs=subscription.snapshot).model_dump(mode="json")
        )
        async for event in subscription:
            await websocket.send_json(RunEventMessage(event=event).model_dump(mode="json"))
    except WebSocketDisconnect, RuntimeError:
        # The client went away between two events; the caller unsubscribes either way.
        pass
    finally:
        watcher.cancel()


async def _close_unauthenticated(websocket: WebSocket) -> None:
    """Close with 4401; quietly, if the client is already gone."""
    with contextlib.suppress(RuntimeError):
        await websocket.close(code=CLOSE_UNAUTHENTICATED, reason="Not authenticated")


async def _close_on_disconnect(websocket: WebSocket, subscription: Subscription) -> None:
    """Read until the client disconnects, then end the subscription's iteration.

    Without a reader nobody would notice a client that left while no run was publishing, and
    its subscription would linger until the next event failed to send.
    """
    try:
        while (await websocket.receive())["type"] != "websocket.disconnect":
            pass
    except Exception:  # noqa: BLE001 — any failure to read means the connection is over.
        logger.debug("Run progress socket read failed; treating it as a disconnect.")
    finally:
        subscription.close()
