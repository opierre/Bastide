"""Categorization rule endpoints: user-scoped CRUD plus the re-apply action."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categories.repository import CategoryRepository
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.rules.schemas import (
    RuleApplyRequest,
    RuleApplyResult,
    RuleCreate,
    RuleFromTransactionRequest,
    RuleFromTransactionResult,
    RulePreviewRequest,
    RulePreviewResult,
    RuleRead,
    RuleSuggestionRead,
    RuleUpdate,
)
from app.features.rules.service import RuleService
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import TransactionRead

router = APIRouter(prefix="/api/v1/rules", tags=["rules"])


def _service(db: Annotated[Session, Depends(get_db)]) -> RuleService:
    return RuleService(RuleRepository(db), TransactionRepository(db), CategoryRepository(db), db)


def _to_read(rule: CategorizationRule) -> RuleRead:
    return RuleRead(
        id=rule.id,
        priority=rule.priority,
        match_field=rule.match_field,
        match_type=rule.match_type,
        pattern=rule.pattern,
        category_id=rule.category_id,
        enabled=rule.enabled,
        created_at=rule.created_at,
    )


@router.get("", response_model=list[RuleRead])
async def list_rules(
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[RuleRead]:
    """List the caller's rules in priority order."""
    return [_to_read(rule) for rule in service.list_for_user(user.id)]


@router.post("", response_model=RuleRead, status_code=status.HTTP_201_CREATED)
async def create_rule(
    payload: RuleCreate,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleRead:
    """Create a new categorization rule."""
    return _to_read(service.create(user.id, payload))


@router.get("/suggestion", response_model=RuleSuggestionRead)
async def suggest_rule_for_transaction(
    transaction_id: str,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleSuggestionRead:
    """Pre-fill for the rule form, derived from the transaction the user is correcting."""
    suggestion = service.suggest_for_transaction(user.id, transaction_id)
    return RuleSuggestionRead(
        match_field=suggestion.match_field,
        match_type=suggestion.match_type,
        pattern=suggestion.pattern,
    )


@router.post("/preview", response_model=RulePreviewResult)
async def preview_rule(
    payload: RulePreviewRequest,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RulePreviewResult:
    """Count the transactions an unsaved rule would match, with up to three examples."""
    match_count, samples = service.preview(user.id, payload)
    return RulePreviewResult(
        match_count=match_count,
        samples=[TransactionRead.model_validate(sample) for sample in samples],
    )


@router.post(
    "/from-transaction",
    response_model=RuleFromTransactionResult,
    status_code=status.HTTP_201_CREATED,
)
async def create_rule_from_transaction(
    payload: RuleFromTransactionRequest,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleFromTransactionResult:
    """Turn a correction into a rule, optionally re-applying it to existing transactions."""
    rule, recategorized_count = service.create_from_transaction(user.id, payload)
    return RuleFromTransactionResult(rule=_to_read(rule), recategorized_count=recategorized_count)


@router.patch("/{rule_id}", response_model=RuleRead)
async def update_rule(
    rule_id: str,
    payload: RuleUpdate,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleRead:
    """Patch mutable fields on a rule."""
    return _to_read(service.update(user.id, rule_id, payload))


@router.delete("/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_rule(
    rule_id: str,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Delete a rule."""
    service.delete(user.id, rule_id)


@router.post("/apply", response_model=RuleApplyResult)
async def apply_rules(
    payload: RuleApplyRequest,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleApplyResult:
    """Re-run the enabled rules over the caller's transactions, optionally one account."""
    count = service.apply(user.id, payload.account_id)
    return RuleApplyResult(recategorized_count=count)
