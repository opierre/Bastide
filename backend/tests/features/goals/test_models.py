"""The goals tables' own guarantees: allocations go with their goal."""

from datetime import date

from sqlalchemy.orm import Session

from app.features.goals.models import Goal, GoalAllocation
from tests.factories import make_user


def test_deleting_a_goal_cascades_to_its_allocations(db_session: Session) -> None:
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
