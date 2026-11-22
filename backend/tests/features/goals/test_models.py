"""The goals tables' own guarantees: allocations and the banner image go with their goal."""

from datetime import UTC, date, datetime

from sqlalchemy.orm import Session

from app.features.goals.models import Goal, GoalAllocation, GoalImage
from app.features.goals.repository import GoalRepository
from tests.factories import make_user


def _goal(db_session: Session) -> Goal:
    goal = Goal(
        user_id=make_user(db_session).id,
        name="Vacances",
        target_minor=200_000,
        currency="EUR",
        icon="beach",
        color="iris",
        status="active",
    )
    db_session.add(goal)
    db_session.commit()
    return goal


def test_deleting_a_goal_cascades_to_its_allocations(db_session: Session) -> None:
    goal = _goal(db_session)
    db_session.add_all(
        [
            GoalAllocation(goal_id=goal.id, amount_minor=50_000, allocated_on=date(2026, 1, 31)),
            # Signed: taking money back out of the envelope is a negative allocation.
            GoalAllocation(goal_id=goal.id, amount_minor=-10_000, allocated_on=date(2026, 2, 28)),
        ]
    )
    db_session.commit()
    assert db_session.query(GoalAllocation).count() == 2

    db_session.delete(goal)
    db_session.commit()

    assert db_session.query(GoalAllocation).count() == 0


def test_the_repository_deletes_a_goal_with_its_allocations_and_image(
    db_session: Session,
) -> None:
    goal = _goal(db_session)
    db_session.add_all(
        [
            GoalAllocation(goal_id=goal.id, amount_minor=50_000, allocated_on=date(2026, 1, 31)),
            GoalImage(
                goal_id=goal.id,
                image=b"png",
                content_type="image/png",
                updated_at=datetime(2026, 2, 1, tzinfo=UTC),
            ),
        ]
    )
    db_session.commit()

    GoalRepository(db_session).delete_goal(goal)

    assert db_session.query(Goal).count() == 0
    assert db_session.query(GoalAllocation).count() == 0
    assert db_session.query(GoalImage).count() == 0
