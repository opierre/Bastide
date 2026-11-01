"""Recurring-series endpoints: detection, the subscription lifecycle, and the panel summary."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categories.repository import CategoryRepository
from app.features.recurring.merge import RecurringMergeService
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import (
    AttachRequest,
    DetectionResultRead,
    DetectRequest,
    MergeDismissRequest,
    MergeRequest,
    MergeSuggestionRead,
    OccurrenceRead,
    PreviewRequest,
    RecurringPreviewRead,
    RecurringSummary,
    SeriesCreate,
    SeriesDetailRead,
    SeriesPreview,
    SeriesRead,
    SeriesStatus,
    SeriesUpdate,
)
from app.features.recurring.service import RecurringDetectionService, RecurringService
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import TransactionPage, TransactionRead

router = APIRouter(prefix="/api/v1/recurring", tags=["recurring"])


#: Outflows per page of `GET /recurring/{series_id}/candidates`. The picker shows the closest
#: ones first, so one page is usually all it needs.
CANDIDATE_PAGE_SIZE = 50


def _detection_service(db: Annotated[Session, Depends(get_db)]) -> RecurringDetectionService:
    return RecurringDetectionService(
        RecurringRepository(db),
        TransactionRepository(db),
        AccountService(AccountRepository(db), db),
        db,
    )


def _service(db: Annotated[Session, Depends(get_db)]) -> RecurringService:
    return RecurringService(
        RecurringRepository(db),
        TransactionRepository(db),
        AccountService(AccountRepository(db), db),
        CategoryRepository(db),
    )


def _merge_service(
    db: Annotated[Session, Depends(get_db)],
    series: Annotated[RecurringService, Depends(_service)],
    detection: Annotated[RecurringDetectionService, Depends(_detection_service)],
) -> RecurringMergeService:
    return RecurringMergeService(RecurringRepository(db), series, detection)


@router.get("", response_model=list[SeriesRead])
async def list_series(
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    series_status: Annotated[
        SeriesStatus | None,
        Query(alias="status", description="Return only series in this lifecycle status."),
    ] = None,
    account_id: Annotated[
        str | None, Query(description="Return only series of this account.")
    ] = None,
    archived: Annotated[
        bool, Query(description="Return the archived series instead of the live ones.")
    ] = False,
) -> list[SeriesRead]:
    """List the caller's series, soonest charge first.

    Cancelled and dismissed series are included: the panel dims a cancelled row rather than
    hiding it, and a client that wants one kind asks for it by `status`. Archived series are
    absent unless asked for with `?archived=true`, which returns only them.
    """
    return [
        SeriesRead.model_validate(series)
        for series in service.list_for_user(
            user.id, status=series_status, account_id=account_id, archived=archived
        )
    ]


@router.post("", response_model=SeriesRead, status_code=status.HTTP_201_CREATED)
async def create_series(
    payload: SeriesCreate,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Create a series from its charges (`is_manual = true`).

    `transaction_ids`, typically the ones ticked in a preview, become its occurrences; at least
    one is required, so every series starts from real charges detection can follow.
    """
    return SeriesRead.model_validate(service.create(user.id, payload))


@router.post("/preview", response_model=RecurringPreviewRead)
async def preview_series(
    payload: PreviewRequest,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RecurringPreviewRead:
    """What series one outflow would start, with a confidence level and its reasons.

    Nothing is written: confirming goes through `POST /recurring` with the ticked
    `transaction_ids`. A transaction already in a series, or whose merchant one already tracks,
    returns that series instead — with the charges it could still take in
    `addable_transactions`, which `POST /recurring/{series_id}/occurrences` adds. An inflow is
    refused with `RECURRING_PREVIEW_INFLOW`.
    """
    result = service.preview(user.id, payload.transaction_id)
    if result.series is not None:
        return RecurringPreviewRead(
            series=SeriesRead.model_validate(result.series),
            addable_transactions=[TransactionRead.model_validate(t) for t in result.addable],
        )
    grade = result.grade
    assert grade is not None
    seed = grade.transactions[0]
    return RecurringPreviewRead(
        preview=SeriesPreview(
            confidence=grade.confidence,
            reasons=list(grade.reasons),
            cadence=grade.cadence,
            median_interval_days=grade.median_interval_days,
            label=grade.label,
            expected_amount_minor=grade.expected_amount_minor,
            currency=seed.currency,
            account_id=seed.account_id,
            transactions=[TransactionRead.model_validate(t) for t in grade.transactions],
        )
    )


@router.post("/detect", response_model=DetectionResultRead)
async def detect_recurring(
    payload: DetectRequest,
    service: Annotated[RecurringDetectionService, Depends(_detection_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> DetectionResultRead:
    """Run a detection pass and report what it created and refreshed.

    Synchronous, unlike a categorisation run: this is one indexed scan of the account's rows
    and some arithmetic, with no model in the loop to wait on.
    """
    result = service.detect(user.id, payload.account_id)
    return DetectionResultRead(
        created_count=result.created_count, updated_count=result.updated_count
    )


@router.get("/summary", response_model=RecurringSummary)
async def get_summary(
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RecurringSummary:
    """The monthly burden, the counts, and the price-increase and missed-charge signals.

    Declared above `/{series_id}` so the literal path wins the match, and takes `date.today()`
    here rather than in the service so the read-time signals stay testable without freezing the
    clock — the same arrangement as the dashboard's trends.
    """
    return service.summary(user.id, user.currency, date.today())


@router.get("/merge-suggestions", response_model=list[MergeSuggestionRead])
async def list_merge_suggestions(
    service: Annotated[RecurringMergeService, Depends(_merge_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[MergeSuggestionRead]:
    """Pairs of series that look like one subscription the bank renamed.

    Declared above `/{series_id}` so the literal path wins the match. Pairs the user kept apart
    are not proposed again.
    """
    return [
        MergeSuggestionRead(
            target=SeriesRead.model_validate(proposal.target),
            source=SeriesRead.model_validate(proposal.source),
        )
        for proposal in service.proposals(user.id)
    ]


@router.post("/merge-suggestions/dismiss", status_code=status.HTTP_204_NO_CONTENT)
async def dismiss_merge_suggestion(
    payload: MergeDismissRequest,
    service: Annotated[RecurringMergeService, Depends(_merge_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Remember that two series are distinct subscriptions, so the pair is never proposed."""
    service.dismiss(user.id, payload.target_id, payload.source_id)


@router.get("/{series_id}", response_model=SeriesDetailRead)
async def get_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesDetailRead:
    """One series with the occurrence history it was deduced from, newest charge first."""
    series, occurrences = service.occurrences(user.id, series_id)
    return SeriesDetailRead(
        **SeriesRead.model_validate(series).model_dump(),
        occurrences=[
            OccurrenceRead(
                id=occurrence.id,
                created_at=occurrence.created_at,
                transaction=TransactionRead.model_validate(transaction),
            )
            for occurrence, transaction in occurrences
        ],
    )


@router.patch("/{series_id}", response_model=SeriesRead)
async def update_series(
    series_id: str,
    payload: SeriesUpdate,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Patch a series; a `status` outside the lifecycle is a 409, not a write."""
    return SeriesRead.model_validate(service.update(user.id, series_id, payload))


@router.post("/{series_id}/archive", response_model=SeriesRead)
async def archive_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Put a series away: out of the list, the summary and detection, history kept.

    Idempotent. `POST /recurring/{series_id}/unarchive` restores it as it was.
    """
    return SeriesRead.model_validate(service.set_archived(user.id, series_id, archived=True))


@router.post("/{series_id}/unarchive", response_model=SeriesRead)
async def unarchive_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Restore an archived series to the list, the summary and detection. Idempotent."""
    return SeriesRead.model_validate(service.set_archived(user.id, series_id, archived=False))


@router.post("/{series_id}/merge", response_model=SeriesRead)
async def merge_series(
    series_id: str,
    payload: MergeRequest,
    service: Annotated[RecurringMergeService, Depends(_merge_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Fold `source_id` into this series and return it rebuilt from both histories.

    The merged-away label is remembered, so later imports group under this series.
    """
    return SeriesRead.model_validate(service.merge(user.id, series_id, payload.source_id))


@router.post("/{series_id}/occurrences", response_model=SeriesRead)
async def attach_occurrences(
    series_id: str,
    payload: AttachRequest,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Add transactions to this series as occurrences; its dates and count follow.

    Each must be an outflow of the caller's not already in a series
    (`RECURRING_TRANSACTIONS_INVALID`, `RECURRING_TRANSACTION_LINKED`).
    """
    return SeriesRead.model_validate(service.attach(user.id, series_id, payload.transaction_ids))


@router.get("/{series_id}/candidates", response_model=TransactionPage)
async def list_candidates(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    q: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
) -> TransactionPage:
    """Outflows in no series that could be added to this one, closest first, paginated.

    Any of the caller's accounts. Ranked by merchant key (the series' own or an alias, then a
    similar one), then an amount close to the expected one, then the most recent; `q` keeps the
    ones whose label or merchant contains it. Adding them goes through
    `POST /recurring/{series_id}/occurrences`.
    """
    items, total = service.candidates(
        user.id, series_id, q=q, page=page, page_size=CANDIDATE_PAGE_SIZE
    )
    return TransactionPage(
        items=[TransactionRead.model_validate(t) for t in items],
        page=page,
        page_size=CANDIDATE_PAGE_SIZE,
        total=total,
    )


@router.delete("/{series_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Delete a declared series; dismiss a detected one."""
    service.delete(user.id, series_id)
