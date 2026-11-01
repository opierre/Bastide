"""Merging two recurring series the bank split by renaming the merchant.

Proposals come from `similarity`; this service applies the user's answer. A merge folds one
series into another and records the merged-away label as an alias, then re-runs detection on
the account so the kept series is rebuilt from the whole history — its first charge, its
cadence and any price change across the rename. A « these are two » is recorded too, so the
pair is never proposed again.
"""

from app.core.errors import ConflictError
from app.features.recurring.models import (
    RecurringMerchantAlias,
    RecurringMergeDismissal,
    RecurringSeries,
)
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.service import (
    RecurringDetectionService,
    RecurringService,
)
from app.features.recurring.similarity import (
    MergeProposal,
    dismissal_key,
    propose_merges,
    side,
)


class SeriesMergeInvalidError(ConflictError):
    """Raised when two series cannot be merged: the same one, or one declared by hand."""

    code = "RECURRING_MERGE_INVALID"


class RecurringMergeService:
    """Proposes, applies and dismisses merges of a user's recurring series."""

    def __init__(
        self,
        repository: RecurringRepository,
        series: RecurringService,
        detection: RecurringDetectionService,
    ) -> None:
        self._repository = repository
        self._series = series
        self._detection = detection

    def proposals(self, user_id: str) -> list[MergeProposal]:
        """The pairs of the user's live series that look like one subscription.

        Archived series are left out: the user put them away, so proposing one would bring it
        back into view through the side door.
        """
        return propose_merges(
            self._repository.list_for_user(user_id, archived=False),
            self._repository.dismissed_pairs(user_id),
        )

    def merge(self, user_id: str, target_id: str, source_id: str) -> RecurringSeries:
        """Fold ``source_id`` into ``target_id`` and return the rebuilt target.

        The target keeps its label and status, takes the source's category when it has none,
        and becomes confirmed when the source was: the user's word on either is kept.

        Raises:
            SeriesNotFoundError: either series does not exist or is another user's.
            SeriesMergeInvalidError: both ids name one series, or either was declared by hand.
                The accounts may differ: a subscription moved between accounts is still one.
        """
        target = self._series.get(user_id, target_id)
        source = self._series.get(user_id, source_id)
        if target.id == source.id or target.is_manual or source.is_manual:
            raise SeriesMergeInvalidError("These two series cannot be merged.")

        if target.category_id is None:
            target.category_id = source.category_id
        if target.status == "detected" and source.status == "confirmed":
            target.status = "confirmed"
        self._repository.repoint_to(source.id, target.id)
        self._repository.stage_alias(
            RecurringMerchantAlias(
                user_id=user_id,
                account_id=source.account_id,
                series_id=target.id,
                merchant_key=source.merchant_key,
            )
        )
        self._repository.stage_delete(source)
        self._repository.flush()
        # Commits the merge with the rebuilt series, in one transaction. Scoped to the target's
        # account, which now reaches the source's through the alias.
        self._detection.detect(user_id, target.account_id)
        self._repository.refresh(target)
        return target

    def dismiss(self, user_id: str, first_id: str, second_id: str) -> None:
        """Remember that two series are distinct subscriptions.

        Raises:
            SeriesNotFoundError: either series does not exist or is another user's.
            SeriesMergeInvalidError: both ids name one series.
        """
        first = self._series.get(user_id, first_id)
        second = self._series.get(user_id, second_id)
        if first.id == second.id:
            raise SeriesMergeInvalidError("These two series cannot be compared.")
        key = dismissal_key(side(first), side(second))
        if key in self._repository.dismissed_pairs(user_id):
            return
        (first_account, first_key), (second_account, second_key) = key
        self._repository.add_dismissal(
            RecurringMergeDismissal(
                user_id=user_id,
                first_account_id=first_account,
                first_key=first_key,
                second_account_id=second_account,
                second_key=second_key,
            )
        )
