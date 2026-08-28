"""Data access for `Goal` rows and the progress aggregate over their allocations."""

from collections.abc import Sequence

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.features.goals.models import Goal, GoalAllocation

#: `sum()` over no rows is NULL, and a goal with no allocations has progress 0, not "unknown".
_PROGRESS = func.coalesce(func.sum(GoalAllocation.amount_minor), 0)


class GoalRepository:
    """Queries and writes for goals, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str, statuses: Sequence[str]) -> list[tuple[Goal, int]]:
        """The user's goals in the given statuses, each with its progress, oldest first.

        Progress arrives as one grouped aggregate rather than a ledger load per goal
        (`PROJECT.md` §13): the panel shows every goal at once, so summing in Python would
        mean reading the whole allocation history to render four progress bars.
        """
        rows = self._db.execute(
            self._with_progress(select(Goal))
            .where(Goal.user_id == user_id, Goal.status.in_(statuses))
            .order_by(Goal.created_at)
        )
        return [(goal, int(progress)) for goal, progress in rows]

    def get_for_user(self, goal_id: str, user_id: str) -> tuple[Goal, int] | None:
        """One goal the user owns with its progress, or `None` — including another user's."""
        row = self._db.execute(
            self._with_progress(select(Goal)).where(Goal.id == goal_id, Goal.user_id == user_id)
        ).first()
        if row is None:
            return None
        goal, progress = row
        return goal, int(progress)

    def add(self, goal: Goal) -> Goal:
        self._db.add(goal)
        self._db.commit()
        self._db.refresh(goal)
        return goal

    def save(self, goal: Goal) -> Goal:
        self._db.commit()
        self._db.refresh(goal)
        return goal

    @staticmethod
    def _with_progress(query: Select[tuple[Goal]]) -> Select[tuple[Goal, int]]:
        """Attach the progress aggregate. Outer-joined: a goal with no allocations still exists."""
        return (
            query.add_columns(_PROGRESS)
            .outerjoin(GoalAllocation, GoalAllocation.goal_id == Goal.id)
            .group_by(Goal.id)
        )
