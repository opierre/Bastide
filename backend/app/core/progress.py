"""The in-process progress bus: background runs publish, WebSocket clients subscribe.

Long-running work — a categorisation run, a rule pack import downloading its logos — reports
its progress here, keyed by user and run id, and every WebSocket the same user has open receives
it. The bus also remembers the latest event of every run still in flight, which is the
snapshot a reconnecting client catches up from.

It is deliberately in-process and generic: the sidecar is one process serving one user, so a
broker would buy nothing, and the bus knows nothing about any run kind beyond its name.

Producers and subscribers may sit on different threads and event loops (a run can execute in a
worker thread or another loop, the WebSocket lives on the server's loop), so publishing is
serialised under a lock and hands each event to the subscriber's own loop with
`call_soon_threadsafe`. Callbacks scheduled on one loop run in the order they were scheduled,
which is what keeps every subscriber's events in publication order.
"""

import asyncio
import logging
import threading
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from datetime import UTC, datetime
from types import TracebackType
from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field

logger = logging.getLogger(__name__)

#: What a run is doing. Extend this as a new kind of background work starts publishing.
RunKind = Literal["categorization", "rule_pack_import"]

#: ``started`` opens a run on the bus and ``progress`` updates it; the other three are terminal
#: and close it. A run is "active" — part of the snapshot — between the two.
RunEventType = Literal["started", "progress", "finished", "failed", "cancelled"]

TERMINAL_EVENTS: frozenset[RunEventType] = frozenset({"finished", "failed", "cancelled"})


class RunEvent(BaseModel):
    """One step of one run, as a subscriber receives it.

    ``done``/``total`` are the run's own unit of work (rows for a categorisation run, logos for
    a pack import). ``counts`` carries kind-specific tallies — `assigned`/`deferred`/`failed` for
    a categorisation run — so a client can render more than a bar without the bus knowing what
    they mean.
    """

    # Every field goes out on every event, defaults included.
    model_config = ConfigDict(json_schema_serialization_defaults_required=True)

    run_id: str
    kind: RunKind
    event: RunEventType
    done: int = Field(ge=0)
    total: int = Field(ge=0)
    counts: dict[str, int] = Field(default_factory=dict)
    #: Set on ``failed`` only: what went wrong, user-safe.
    error_message: str | None = None
    occurred_at: datetime


class RunSnapshotMessage(BaseModel):
    """First message on every connection: the latest event of each of the user's active runs."""

    # `type` always goes out, so the reference must not call it optional.
    model_config = ConfigDict(json_schema_serialization_defaults_required=True)

    type: Literal["snapshot"] = "snapshot"
    runs: list[RunEvent]


class RunEventMessage(BaseModel):
    """Every later message: one run event, in the order the run published it."""

    # `type` always goes out, so the reference must not call it optional.
    model_config = ConfigDict(json_schema_serialization_defaults_required=True)

    type: Literal["event"] = "event"
    event: RunEvent


@dataclass(eq=False)
class Subscription:
    """One subscriber's feed of a user's run events.

    Use it as a context manager so it is removed from the bus however the connection ends;
    iterate it for events until `close` is called.
    """

    bus: ProgressBus
    user_id: str
    #: The user's active runs at the instant of subscribing — no event is both in here and in
    #: the feed, and none published after subscribing is missing from the feed.
    snapshot: list[RunEvent]
    _loop: asyncio.AbstractEventLoop
    _queue: asyncio.Queue[RunEvent | None] = field(default_factory=asyncio.Queue)

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.bus.unsubscribe(self)

    def close(self) -> None:
        """End the iteration; safe to call from any thread, and more than once."""
        self._deliver(None)

    def _deliver(self, event: RunEvent | None) -> bool:
        """Hand ``event`` to the subscriber's loop; False when that loop is gone."""
        try:
            self._loop.call_soon_threadsafe(self._queue.put_nowait, event)
        except RuntimeError:
            return False
        return True

    async def __aiter__(self) -> AsyncIterator[RunEvent]:
        while (event := await self._queue.get()) is not None:
            yield event


class ProgressBus:
    """Fans run events out to the subscribers of the run's user and tracks active runs."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._subscribers: dict[str, list[Subscription]] = {}
        self._active: dict[str, dict[str, RunEvent]] = {}

    def publish(self, user_id: str, event: RunEvent) -> None:
        """Record ``event`` for the user's run and deliver it to the user's subscribers.

        A run must publish ``started`` first: a ``progress`` for a run the bus does not know as
        active — never started, or already terminal — is dropped, so a client never sees a run
        move after it was reported finished or cancelled. Terminal events are always delivered.
        Never raises: progress reporting must not be able to fail the run reporting it.
        """
        with self._lock:
            if event.event == "progress" and event.run_id not in self._active.get(user_id, {}):
                return
            runs = self._active.setdefault(user_id, {})
            if event.event in TERMINAL_EVENTS:
                runs.pop(event.run_id, None)
            else:
                runs[event.run_id] = event
            if not runs:
                del self._active[user_id]

            subscribers = self._subscribers.get(user_id, [])
            gone = [sub for sub in subscribers if not sub._deliver(event)]
            for subscription in gone:
                subscribers.remove(subscription)

    def subscribe(self, user_id: str) -> Subscription:
        """Start receiving ``user_id``'s events on the running loop, with a snapshot.

        Must be called from inside the event loop that will iterate the subscription.
        """
        loop = asyncio.get_running_loop()
        with self._lock:
            snapshot = list(self._active.get(user_id, {}).values())
            subscription = Subscription(self, user_id, snapshot, loop)
            self._subscribers.setdefault(user_id, []).append(subscription)
        return subscription

    def unsubscribe(self, subscription: Subscription) -> None:
        """Remove ``subscription``; a no-op if it is already gone."""
        with self._lock:
            subscribers = self._subscribers.get(subscription.user_id, [])
            if subscription in subscribers:
                subscribers.remove(subscription)
            if not subscribers:
                self._subscribers.pop(subscription.user_id, None)
        subscription.close()

    def active_runs(self, user_id: str) -> list[RunEvent]:
        """The latest event of each of the user's runs that has started and not ended."""
        with self._lock:
            return list(self._active.get(user_id, {}).values())

    def subscriber_count(self, user_id: str | None = None) -> int:
        """How many subscriptions are open, for one user or for everyone."""
        with self._lock:
            if user_id is not None:
                return len(self._subscribers.get(user_id, []))
            return sum(len(subs) for subs in self._subscribers.values())


class RunReporter:
    """Publishes one run's events, so a producer never builds a `RunEvent` by hand."""

    def __init__(self, bus: ProgressBus, user_id: str, run_id: str, kind: RunKind) -> None:
        self._bus = bus
        self._user_id = user_id
        self._run_id = run_id
        self._kind = kind

    def started(self, total: int, *, done: int = 0, counts: dict[str, int] | None = None) -> None:
        self._publish("started", done, total, counts)

    def progress(self, done: int, total: int, *, counts: dict[str, int] | None = None) -> None:
        self._publish("progress", done, total, counts)

    def finished(self, done: int, total: int, *, counts: dict[str, int] | None = None) -> None:
        self._publish("finished", done, total, counts)

    def failed(
        self, done: int, total: int, message: str, *, counts: dict[str, int] | None = None
    ) -> None:
        self._publish("failed", done, total, counts, message)

    def cancelled(self, done: int, total: int, *, counts: dict[str, int] | None = None) -> None:
        self._publish("cancelled", done, total, counts)

    def _publish(
        self,
        event: RunEventType,
        done: int,
        total: int,
        counts: dict[str, int] | None,
        error_message: str | None = None,
    ) -> None:
        try:
            self._bus.publish(
                self._user_id,
                RunEvent(
                    run_id=self._run_id,
                    kind=self._kind,
                    event=event,
                    done=done,
                    total=total,
                    counts=counts or {},
                    error_message=error_message,
                    occurred_at=datetime.now(UTC),
                ),
            )
        except Exception:
            logger.exception("Could not publish %s for run %s.", event, self._run_id)


_bus = ProgressBus()


def get_progress_bus() -> ProgressBus:
    """The process-wide bus, as a dependency so tests can hand in their own."""
    return _bus
