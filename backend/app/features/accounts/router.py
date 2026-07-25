"""Account endpoints: user-scoped CRUD with archive-on-delete."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.accounts.models import Account
from app.features.accounts.repository import AccountRepository
from app.features.accounts.schemas import AccountCreate, AccountRead, AccountUpdate
from app.features.accounts.service import AccountService
from app.features.auth.deps import get_current_user
from app.features.auth.models import User

router = APIRouter(prefix="/api/v1/accounts", tags=["accounts"])


def _service(db: Annotated[Session, Depends(get_db)]) -> AccountService:
    return AccountService(AccountRepository(db))


def _to_read(account: Account) -> AccountRead:
    return AccountRead(
        id=account.id,
        name=account.name,
        type=account.type,
        institution=account.institution,
        currency=account.currency,
        opening_balance_minor=account.opening_balance_minor,
        balance_minor=account.cached_balance_minor,
        archived=account.archived,
        created_at=account.created_at,
        updated_at=account.updated_at,
    )


@router.get("", response_model=list[AccountRead])
async def list_accounts(
    service: Annotated[AccountService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[AccountRead]:
    """List the caller's non-archived accounts."""
    return [_to_read(account) for account in service.list_for_user(user.id)]


@router.post("", response_model=AccountRead, status_code=status.HTTP_201_CREATED)
async def create_account(
    payload: AccountCreate,
    service: Annotated[AccountService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> AccountRead:
    """Open a new account; currency defaults to the caller's."""
    return _to_read(service.create(user, payload))


@router.get("/{account_id}", response_model=AccountRead)
async def get_account(
    account_id: str,
    service: Annotated[AccountService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> AccountRead:
    """Fetch a single account, including its derived current balance."""
    return _to_read(service.get(user.id, account_id))


@router.patch("/{account_id}", response_model=AccountRead)
async def update_account(
    account_id: str,
    payload: AccountUpdate,
    service: Annotated[AccountService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> AccountRead:
    """Patch mutable account fields."""
    return _to_read(service.update(user.id, account_id, payload))


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    account_id: str,
    service: Annotated[AccountService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Archive an account (never hard-deletes)."""
    service.archive(user.id, account_id)
