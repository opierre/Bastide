"""Tests for the progress bus itself: ordering, scoping, the active-run snapshot, cleanup."""

import asyncio
import threading
from datetime import UTC, datetime

from app.core.progress import ProgressBus, RunEvent, RunEventType, RunReporter

ALICE = "user-alice"
BRUNO = "user-bruno"


def _event(run_id: str, event: RunEventType, done: int = 0, total: int = 10) -> RunEvent:
    return RunEvent(
        run_id=run_id,
        kind="categorization",
        event=event,
        done=done,
        total=total,
        occurred_at=datetime(2026, 1, 15, 9, 30, tzinfo=UTC),
    )


async def _collect(bus: ProgressBus, user_id: str, publish: list[RunEvent]) -> list[RunEvent]:
    """Subscribe, publish ``publish`` from another thread, and read back until it closes."""
    received: list[RunEvent] = []
    with bus.subscribe(user_id) as subscription:

        def produce() -> None:
            for event in publish:
                bus.publish(user_id, event)
            subscription.close()

        thread = threading.Thread(target=produce)
        thread.start()
        async for event in subscription:
            received.append(event)
        thread.join()
    return received


def test_events_published_from_another_thread_arrive_in_order() -> None:
    bus = ProgressBus()
    sent = [
        _event("run-1", "started"),
        *[_event("run-1", "progress", done) for done in range(1, 10)],
        _event("run-1", "finished", 10),
    ]

    received = asyncio.run(_collect(bus, ALICE, sent))

    assert received == sent


def test_a_subscriber_only_receives_its_own_users_events() -> None:
    bus = ProgressBus()

    async def scenario() -> list[RunEvent]:
        with bus.subscribe(ALICE) as subscription:
            bus.publish(BRUNO, _event("run-bruno", "started"))
            bus.publish(ALICE, _event("run-alice", "started"))
            subscription.close()
            return [event async for event in subscription]

    received = asyncio.run(scenario())

    assert [event.run_id for event in received] == ["run-alice"]


def test_the_snapshot_holds_the_latest_event_of_each_active_run_only() -> None:
    bus = ProgressBus()
    bus.publish(ALICE, _event("run-1", "started"))
    bus.publish(ALICE, _event("run-1", "progress", 4))
    bus.publish(ALICE, _event("run-2", "started"))
    bus.publish(ALICE, _event("run-2", "cancelled", 1))
    bus.publish(BRUNO, _event("run-3", "started"))

    async def scenario() -> list[RunEvent]:
        with bus.subscribe(ALICE) as subscription:
            return subscription.snapshot

    snapshot = asyncio.run(scenario())

    assert [(event.run_id, event.event, event.done) for event in snapshot] == [
        ("run-1", "progress", 4)
    ]


def test_progress_for_a_run_that_is_not_active_is_dropped() -> None:
    bus = ProgressBus()

    async def scenario() -> list[RunEvent]:
        with bus.subscribe(ALICE) as subscription:
            bus.publish(ALICE, _event("never-started", "progress", 3))
            bus.publish(ALICE, _event("run-1", "started"))
            bus.publish(ALICE, _event("run-1", "finished", 10))
            # A late batch reporting after the run was already reported finished.
            bus.publish(ALICE, _event("run-1", "progress", 10))
            subscription.close()
            return [event async for event in subscription]

    received = asyncio.run(scenario())

    assert [event.event for event in received] == ["started", "finished"]
    assert bus.active_runs(ALICE) == []


def test_leaving_the_subscription_unsubscribes_it() -> None:
    bus = ProgressBus()

    async def scenario() -> int:
        with bus.subscribe(ALICE):
            assert bus.subscriber_count(ALICE) == 1
        return bus.subscriber_count()

    assert asyncio.run(scenario()) == 0


def test_a_subscriber_whose_loop_is_gone_is_dropped_on_the_next_publish() -> None:
    bus = ProgressBus()

    async def subscribe_and_leave_open() -> None:
        bus.subscribe(ALICE)

    asyncio.run(subscribe_and_leave_open())
    assert bus.subscriber_count(ALICE) == 1

    bus.publish(ALICE, _event("run-1", "started"))

    assert bus.subscriber_count(ALICE) == 0


def test_the_reporter_builds_each_event_and_never_raises() -> None:
    bus = ProgressBus()
    reporter = RunReporter(bus, ALICE, "run-1", "categorization")

    reporter.started(5)
    reporter.progress(2, 5, counts={"assigned": 2})
    assert [(e.event, e.done, e.counts) for e in bus.active_runs(ALICE)] == [
        ("progress", 2, {"assigned": 2})
    ]

    reporter.failed(2, 5, "The runtime did not answer.")
    assert bus.active_runs(ALICE) == []

    # A negative count is invalid; reporting it is logged, not raised into the run.
    reporter.progress(-1, 5)
