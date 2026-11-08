"""The run progress WebSocket: a snapshot of the user's active runs, then every event live.

The REST snapshot endpoints (`GET /categorization/runs/{id}`) stay the source of truth for one
run; this socket only saves the app from polling them while something is in flight.
"""

import asyncio
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.core.db import SessionFactory, get_session_factory
from app.core.errors import AuthError
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


def _authenticate(websocket: WebSocket, session_factory: SessionFactory) -> str | None:
    """Resolve the socket's bearer token to its user's id, on a session closed straight after.

    A request-scoped `get_db` session would stay open for the life of the connection; the
    token is checked once, on connect, so the session needn't outlive that.
    """
    db = session_factory()
    try:
        token = bearer_token(websocket.headers.get("authorization"))
        return AuthService(AuthRepository(db)).get_current_user(token).id
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
) -> None:
    """Stream the caller's run events: a `RunSnapshotMessage`, then one `RunEventMessage` each.

    Authenticated on connect with the same `Authorization: Bearer` header as the REST API. A
    missing or invalid token is accepted then closed with code 4401, so the client can tell
    "log in again" from a network failure. Messages the client sends are ignored.
    """
    user_id = _authenticate(websocket, session_factory)
    await websocket.accept()
    if user_id is None:
        await websocket.close(code=CLOSE_UNAUTHENTICATED, reason="Not authenticated")
        return

    with bus.subscribe(user_id) as subscription:
        watcher = asyncio.create_task(_close_on_disconnect(websocket, subscription))
        try:
            await websocket.send_json(
                RunSnapshotMessage(runs=subscription.snapshot).model_dump(mode="json")
            )
            async for event in subscription:
                await websocket.send_json(RunEventMessage(event=event).model_dump(mode="json"))
        except WebSocketDisconnect, RuntimeError:
            # The client went away between two events; the `with` unsubscribes either way.
            pass
        finally:
            watcher.cancel()


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
