"""Transaction endpoints: user-scoped list with filters/search/pagination, detail, and patch."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
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
    return TransactionService(TransactionRepository(db))


def _to_read(transaction: Transaction) -> TransactionRead:
    return TransactionRead(
        id=transaction.id,
        account_id=transaction.account_id,
        booked_date=transaction.booked_date,
        value_date=transaction.value_date,
        amount_minor=transaction.amount_minor,
        currency=transaction.currency,
        description_raw=transaction.description_raw,
        description_clean=transaction.description_clean,
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
        created_at=transaction.created_at,
        updated_at=transaction.updated_at,
    )


@router.get("", response_model=TransactionPage)
async def list_transactions(
    service: Annotated[TransactionService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    account_id: str | None = None,
    from_: Annotated[date | None, Query(alias="from")] = None,
    to: date | None = None,
    category_id: str | None = None,
    needs_review: bool | None = None,
    q: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
) -> TransactionPage:
    """List the caller's transactions, filtered, searched, and paginated."""
    items, total = service.list_for_user(
        user.id,
        account_id=account_id,
        date_from=from_,
        date_to=to,
        category_id=category_id,
        needs_review=needs_review,
        q=q,
        page=page,
    )
    return TransactionPage(
        items=[_to_read(transaction) for transaction in items],
        page=page,
        page_size=PAGE_SIZE,
        total=total,
    )


@router.get("/{transaction_id}", response_model=TransactionRead)
async def get_transaction(
    transaction_id: str,
    service: Annotated[TransactionService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> TransactionRead:
    """Fetch a single transaction the caller owns."""
    return _to_read(service.get(user.id, transaction_id))


@router.patch("/{transaction_id}", response_model=TransactionRead)
async def update_transaction(
    transaction_id: str,
    payload: TransactionUpdate,
    service: Annotated[TransactionService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> TransactionRead:
    """Patch category/description/merchant. A category edit sets `source=user`."""
    return _to_read(service.update(user.id, transaction_id, payload))
