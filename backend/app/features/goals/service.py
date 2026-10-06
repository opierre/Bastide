"""Business logic for savings goals: CRUD, the signed allocation ledger, and derived status.

Nothing in here writes a transaction or moves an account balance. A goal is a virtual
envelope: allocating is bookkeeping *about* money the user already has, so
this feature never touches the ledger, and never compares an allocation against a balance —
the backend has no basis for deciding which money is "savings".
"""

from app.core.errors import NotFoundError
from app.features.auth.models import User
from app.features.goals.models import Goal, GoalAllocation
from app.features.goals.repository import GoalRepository
from app.features.goals.schemas import AllocationCreate, GoalCreate, GoalStatus, GoalUpdate

#: The status a goal starts in, and the one it falls back to when progress drops below target.
ACTIVE: GoalStatus = "active"

#: Progress has reached the target. Never auto-archived: reaching a goal is the moment the UI
#: is built around.
REACHED: GoalStatus = "reached"

#: Out of the way, but not gone — the allocation history survives and the goal can be restored.
ARCHIVED: GoalStatus = "archived"

#: What `GET /goals` returns without a `status` filter: everything the panel's grid shows.
DEFAULT_STATUSES: tuple[GoalStatus, ...] = (ACTIVE, REACHED)


class GoalNotFoundError(NotFoundError):
    """Raised when a goal doesn't exist or doesn't belong to the caller."""

    code = "GOAL_NOT_FOUND"


class AllocationNotFoundError(NotFoundError):
    """Raised when an allocation doesn't exist or belongs to another goal."""

    code = "GOAL_ALLOCATION_NOT_FOUND"


def _settled_status(goal: Goal, progress_minor: int) -> GoalStatus:
    """The status this goal's progress implies.

    Archived is the user's own decision and outranks the arithmetic — an archived goal stays
    archived however its ledger moves, and its status is recomputed only when it is restored.
    """
    if goal.status == ARCHIVED:
        return ARCHIVED
    return REACHED if progress_minor >= goal.target_minor else ACTIVE


class GoalService:
    """Goal CRUD and the allocation ledger, scoped to a user."""

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
        """Create a goal. Currency is copied from the user, per the one-currency rule."""
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

        Whatever the patch touched, the status is re-derived from the ledger afterwards, so
        `reached` is never a claim about arithmetic that no longer holds: raising a target
        above the money already set aside drops the goal back to `active`, lowering one under
        it reports `reached`, and a restore recomputes rather than trusting the status the
        goal carried when it was archived. Archiving still outranks the arithmetic.

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
        goal.status = _settled_status(goal, progress_minor)
        return self._repository.save(goal), progress_minor

    def archive(self, user_id: str, goal_id: str) -> None:
        """Archive a goal. Never hard-deletes: the allocations are history and survive.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        goal, _ = self.get(user_id, goal_id)
        goal.status = ARCHIVED
        self._repository.save(goal)

    def list_allocations(self, user_id: str, goal_id: str) -> list[GoalAllocation]:
        """A goal's allocation history, newest first.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        goal, _ = self.get(user_id, goal_id)
        return self._repository.list_allocations(goal.id)

    def add_allocation(self, user_id: str, goal_id: str, data: AllocationCreate) -> GoalAllocation:
        """Append one signed line to a goal's ledger and settle the goal's status.

        Over-allocation is accepted silently, here and across goals: total allocations may
        exceed whatever the user actually holds, and the UI is what says so.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
        """
        goal, _ = self.get(user_id, goal_id)
        allocation = self._repository.add_allocation(
            GoalAllocation(
                goal_id=goal.id,
                amount_minor=data.amount_minor,
                allocated_on=data.allocated_on,
                note=data.note,
            )
        )
        self._settle(goal)
        return allocation

    def delete_allocation(self, user_id: str, goal_id: str, allocation_id: str) -> None:
        """Remove one line of the ledger and settle the goal's status.

        The one mutation the history allows, and only because a mistyped line is not history.
        Undoing an allocation the user meant is done with an offsetting negative line instead.

        Raises:
            GoalNotFoundError: no such goal, or it belongs to another user.
            AllocationNotFoundError: no such allocation on this goal.
        """
        goal, _ = self.get(user_id, goal_id)
        allocation = self._repository.get_allocation(allocation_id, goal.id)
        if allocation is None:
            raise AllocationNotFoundError("Allocation not found.")
        self._repository.delete_allocation(allocation)
        self._settle(goal)

    def _settle(self, goal: Goal) -> None:
        """Re-derive `reached` / `active` from the ledger after it changed."""
        status = _settled_status(goal, self._repository.progress_for(goal.id))
        if status != goal.status:
            goal.status = status
            self._repository.save(goal)
