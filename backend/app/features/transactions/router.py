"""Transaction endpoints: user-scoped list with filters/search/pagination, detail, and patch."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categories.repository import CategoryRepository
from app.features.rules.deps import get_logo_resolver
from app.features.rules.logos import RuleLogoResolver
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import (
    TransactionCategory,
    TransactionPage,
    TransactionRead,
    TransactionUpdate,
)
from app.features.transactions.service import PAGE_SIZE, TransactionService

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])


def _service(db: Annotated[Session, Depends(get_db)]) -> TransactionService:
    return TransactionService(
        TransactionRepository(db),
        CategoryRepository(db),
    )


def _to_read(transaction: Transaction, logos: RuleLogoResolver) -> TransactionRead:
    read = TransactionRead(
        id=transaction.id,
        account_id=transaction.account_id,
        booked_date=transaction.booked_date,
        value_date=transaction.value_date,
        amount_minor=transaction.amount_minor,
        currency=transaction.currency,
        description_raw=transaction.description_raw,
        description_clean=transaction.description_clean,
        memo=transaction.memo,
        merchant=transaction.merchant,
        category=(
            TransactionCategory.model_validate(transaction.category)
            if transaction.category is not None
            else None
        ),
        categorization_source=transaction.categorization_source,
        categorization_confidence=transaction.categorization_confidence,
        needs_review=transaction.needs_review,
        fitid=transaction.fitid,
        dedup_hash=transaction.dedup_hash,
        recurring_series_id=transaction.recurring_series_id,
        created_at=transaction.created_at,
        updated_at=transaction.updated_at,
    )
    logos.fill(read, read)
    return read


@router.get("", response_model=TransactionPage)
async def list_transactions(
    service: Annotated[TransactionService, Depends(_service)],
    logos: Annotated[RuleLogoResolver, Depends(get_logo_resolver)],
    user: Annotated[User, Depends(get_current_user)],
    account_id: str | None = None,
    from_: Annotated[date | None, Query(alias="from")] = None,
    to: date | None = None,
    category_id: str | None = None,
    needs_review: bool | None = None,
    q: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    include_linked_cards: bool = False,
) -> TransactionPage:
    """List the caller's transactions, filtered, searched, and paginated.

    `include_linked_cards` widens an `account_id` filter to the deferred cards settled on that
    account. Each row keeps its own `account_id`, so a client can tell the card's apart.
    """
    items, total = service.list_for_user(
        user.id,
        account_id=account_id,
        date_from=from_,
        date_to=to,
        category_id=category_id,
        needs_review=needs_review,
        q=q,
        page=page,
        include_linked_cards=include_linked_cards,
    )
    return TransactionPage(
        items=[_to_read(transaction, logos) for transaction in items],
        page=page,
        page_size=PAGE_SIZE,
        total=total,
    )


@router.get("/{transaction_id}", response_model=TransactionRead)
async def get_transaction(
    transaction_id: str,
    service: Annotated[TransactionService, Depends(_service)],
    logos: Annotated[RuleLogoResolver, Depends(get_logo_resolver)],
    user: Annotated[User, Depends(get_current_user)],
) -> TransactionRead:
    """Fetch a single transaction the caller owns."""
    return _to_read(service.get(user.id, transaction_id), logos)


@router.patch("/{transaction_id}", response_model=TransactionRead)
async def update_transaction(
    transaction_id: str,
    payload: TransactionUpdate,
    service: Annotated[TransactionService, Depends(_service)],
    logos: Annotated[RuleLogoResolver, Depends(get_logo_resolver)],
    user: Annotated[User, Depends(get_current_user)],
) -> TransactionRead:
    """Patch category/description/merchant. A category edit sets `source=user`."""
    return _to_read(service.update(user.id, transaction_id, payload), logos)
