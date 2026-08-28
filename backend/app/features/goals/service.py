"""Business logic for savings goals: CRUD over the virtual envelopes and their progress.

Nothing in here writes a transaction or moves an account balance. A goal is a virtual
envelope (`PROJECT.md` §13): it is bookkeeping *about* money the user already has.
"""

from app.core.errors import NotFoundError
from app.features.auth.models import User
from app.features.goals.models import Goal
from app.features.goals.repository import GoalRepository
from app.features.goals.schemas import GoalCreate, GoalStatus, GoalUpdate

#: The status a goal starts in, and the one it falls back to when progress drops below target.
ACTIVE: GoalStatus = "active"

#: Progress has reached the target. Never auto-archived: reaching a goal is the moment the UI
#: is built around (`PROJECT.md` §13).
REACHED: GoalStatus = "reached"

#: Out of the way, but not gone — the allocation history survives and the goal can be restored.
ARCHIVED: GoalStatus = "archived"

#: What `GET /goals` returns without a `status` filter: everything the panel's grid shows.
DEFAULT_STATUSES: tuple[GoalStatus, ...] = (ACTIVE, REACHED)


class GoalNotFoundError(NotFoundError):
    """Raised when a goal doesn't exist or doesn't belong to the caller."""

    code = "GOAL_NOT_FOUND"


class GoalService:
    """Goal CRUD, scoped to a user."""

    def __init__(self, repository: GoalRepository) -> None:
        self._repository = repository

    def list_for_user(
        self, user_id: str, status: GoalStatus | None = None
    ) -> list[tuple[Goal, int]]:
        """The user's goals with their progress, oldest first.

        Archived goals are excluded unless asked for by name: they leave the grid, and
        `?status=archived` is what the panel's « Afficher les objectifs archivés » link calls.
        """
        statuses = (status,) if status is not None else DEFAULT_STATUSES
        return self._repository.list_for_user(user_id, statuses)

    def get(self, user_id: str, goal_id: str) -> tuple[Goal, int]:
        """One goal the user owns, with its progress.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        found = self._repository.get_for_user(goal_id, user_id)
        if found is None:
            raise GoalNotFoundError("Goal not found.")
        return found

    def create(self, user: User, data: GoalCreate) -> tuple[Goal, int]:
        """Create a goal. Currency is copied from the user, per the Phase 1 one-currency rule."""
        goal = Goal(
            user_id=user.id,
            name=data.name,
            target_minor=data.target_minor,
            currency=user.currency,
            target_date=data.target_date,
            icon=data.icon,
            color=data.color,
            status=ACTIVE,
        )
        return self._repository.add(goal), 0

    def update(self, user_id: str, goal_id: str, data: GoalUpdate) -> tuple[Goal, int]:
        """Patch a goal, including archiving and restoring it.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        goal, progress_minor = self.get(user_id, goal_id)
        if data.name is not None:
            goal.name = data.name
        if data.target_minor is not None:
            goal.target_minor = data.target_minor
        if data.target_date is not None:
            goal.target_date = data.target_date
        if data.icon is not None:
            goal.icon = data.icon
        if data.color is not None:
            goal.color = data.color
        if data.status is not None:
            goal.status = data.status
        return self._repository.save(goal), progress_minor

    def archive(self, user_id: str, goal_id: str) -> None:
        """Archive a goal. Never hard-deletes: the allocations are history and survive.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        goal, _ = self.get(user_id, goal_id)
        goal.status = ARCHIVED
        self._repository.save(goal)
