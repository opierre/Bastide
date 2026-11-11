"""Long-lived connections tied to the auth session they opened with, ended when it is revoked.

A REST request re-checks its bearer token every time; a WebSocket checks it once, on connect.
So a connection registers here under its session's id, and whatever deletes sessions — logout,
a password reset revoking every session — reports it, which runs each matching connection's
`on_revoke` callback. Neither side imports the other: auth reports revocations, a feature
holding sockets registers them, both through this core registry.

Only session ids are kept, never the bearer token itself. Revocation may be reported from any
thread, so callbacks must be thread-safe; they run outside the registry's lock.
"""

import logging
import threading
from collections.abc import Callable
from dataclasses import dataclass
from types import TracebackType
from typing import Self

logger = logging.getLogger(__name__)


@dataclass(eq=False)
class LiveSession:
    """One registered connection; a context manager that unregisters it on exit."""

    registry: LiveSessions
    session_id: str
    user_id: str
    on_revoke: Callable[[], None]

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.registry.unregister(self)


class LiveSessions:
    """The connections currently open under each auth session."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._connections: list[LiveSession] = []

    def register(self, session_id: str, user_id: str, on_revoke: Callable[[], None]) -> LiveSession:
        """Call ``on_revoke`` once if session ``session_id`` of ``user_id`` is revoked."""
        connection = LiveSession(self, session_id, user_id, on_revoke)
        with self._lock:
            self._connections.append(connection)
        return connection

    def unregister(self, connection: LiveSession) -> None:
        """Forget ``connection``; a no-op if it is already gone."""
        with self._lock:
            if connection in self._connections:
                self._connections.remove(connection)

    def revoke_session(self, session_id: str) -> None:
        """End every connection opened under session ``session_id``."""
        self._revoke(lambda connection: connection.session_id == session_id)

    def revoke_user(self, user_id: str) -> None:
        """End every connection of ``user_id``, whichever session opened it."""
        self._revoke(lambda connection: connection.user_id == user_id)

    def count(self, user_id: str | None = None) -> int:
        """How many connections are registered, for one user or for everyone."""
        with self._lock:
            return sum(1 for c in self._connections if user_id is None or c.user_id == user_id)

    def _revoke(self, matches: Callable[[LiveSession], bool]) -> None:
        with self._lock:
            revoked = [c for c in self._connections if matches(c)]
            self._connections = [c for c in self._connections if not matches(c)]
        for connection in revoked:
            try:
                connection.on_revoke()
            except Exception:
                # A connection that can't be told must not stop the others, nor the logout.
                logger.exception("Could not end a connection of a revoked session.")


_registry = LiveSessions()


def get_live_sessions() -> LiveSessions:
    """The process-wide registry, as a dependency so tests can hand in their own."""
    return _registry
