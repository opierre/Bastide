"""Data access for `Goal` and `GoalAllocation` rows. The only place either table is queried."""

from collections.abc import Sequence

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.features.goals.models import Goal, GoalAllocation

#: `sum()` over no rows is NULL, and a goal with no allocations has progress 0, not "unknown".
_PROGRESS = func.coalesce(func.sum(GoalAllocation.amount_minor), 0)


class GoalRepository:
    """Queries and writes for goals and their allocations, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str, statuses: Sequence[str]) -> list[tuple[Goal, int]]:
        """The user's goals in the given statuses, each with its progress, oldest first.

        Progress arrives as one grouped aggregate rather than a ledger load per goal:
        the panel shows every goal at once, so summing in Python would
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

    def progress_for(self, goal_id: str) -> int:
        """The signed sum of a goal's allocations, computed by the database."""
        return int(self._db.scalar(select(_PROGRESS).where(GoalAllocation.goal_id == goal_id)) or 0)

    def add(self, goal: Goal) -> Goal:
        self._db.add(goal)
        self._db.commit()
        self._db.refresh(goal)
        return goal

    def save(self, goal: Goal) -> Goal:
        self._db.commit()
        self._db.refresh(goal)
        return goal

    def list_allocations(self, goal_id: str) -> list[GoalAllocation]:
        """A goal's allocations, newest first — the order the history table reads in."""
        return list(
            self._db.scalars(
                select(GoalAllocation)
                .where(GoalAllocation.goal_id == goal_id)
                .order_by(GoalAllocation.allocated_on.desc(), GoalAllocation.created_at.desc())
            )
        )

    def get_allocation(self, allocation_id: str, goal_id: str) -> GoalAllocation | None:
        """One allocation of this goal, or `None` — including one belonging to another goal."""
        return self._db.scalar(
            select(GoalAllocation).where(
                GoalAllocation.id == allocation_id, GoalAllocation.goal_id == goal_id
            )
        )

    def add_allocation(self, allocation: GoalAllocation) -> GoalAllocation:
        self._db.add(allocation)
        self._db.commit()
        self._db.refresh(allocation)
        return allocation

    def delete_allocation(self, allocation: GoalAllocation) -> None:
        self._db.delete(allocation)
        self._db.commit()

    @staticmethod
    def _with_progress(query: Select[tuple[Goal]]) -> Select[tuple[Goal, int]]:
        """Attach the progress aggregate. Outer-joined: a goal with no allocations still exists."""
        return (
            query.add_columns(_PROGRESS)
            .outerjoin(GoalAllocation, GoalAllocation.goal_id == Goal.id)
            .group_by(Goal.id)
        )
