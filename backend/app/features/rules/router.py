"""Categorization rule endpoints: user-scoped CRUD, the re-apply action, and rule packs."""

from typing import Annotated

from fastapi import APIRouter, Depends, File, Header, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categories.repository import CategoryRepository
from app.features.rules.deps import get_logo_resolver
from app.features.rules.logos import MAX_UPLOAD_BYTES, RuleLogoResolver
from app.features.rules.models import CategorizationRule
from app.features.rules.packs.schema import (
    BuiltinPackRead,
    RulePackExportResult,
    RulePackImportRequest,
    RulePackImportResult,
    RulePackPreviewResult,
    RulePackSource,
)
from app.features.rules.packs.service import RulePackService
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
    return RuleService(
        RuleRepository(db),
        TransactionRepository(db),
        CategoryRepository(db),
        db,
    )


def _pack_service(db: Annotated[Session, Depends(get_db)]) -> RulePackService:
    return RulePackService(
        RuleRepository(db),
        CategoryRepository(db),
        TransactionRepository(db),
        _service(db),
        db,
    )


def _to_read(rule: CategorizationRule) -> RuleRead:
    return RuleRead(
        id=rule.id,
        priority=rule.priority,
        match_field=rule.match_field,
        match_type=rule.match_type,
        pattern=rule.pattern,
        category_id=rule.category_id,
        enabled=rule.enabled,
        applies_from=rule.applies_from,
        logo_updated_at=rule.logo.updated_at if rule.logo is not None else None,
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
    logos: Annotated[RuleLogoResolver, Depends(get_logo_resolver)],
    user: Annotated[User, Depends(get_current_user)],
) -> RulePreviewResult:
    """Count the transactions an unsaved rule would match, with up to three examples."""
    match_count, samples = service.preview(user.id, payload)
    return RulePreviewResult(
        match_count=match_count,
        samples=logos.fill_rows(TransactionRead.model_validate(sample) for sample in samples),
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


# --- rule packs ---------------------------------------------------------------------------
# Declared before `/{rule_id}` so the literal `packs` segment can never be read as a rule id.


@router.get("/packs/builtin", response_model=list[BuiltinPackRead])
async def list_builtin_packs(
    service: Annotated[RulePackService, Depends(_pack_service)],
    _user: Annotated[User, Depends(get_current_user)],
) -> list[BuiltinPackRead]:
    """List the packs bundled with the app, so the frontend can offer one without a file."""
    return service.list_builtin()


@router.post("/packs/preview", response_model=RulePackPreviewResult)
async def preview_pack(
    payload: RulePackSource,
    service: Annotated[RulePackService, Depends(_pack_service)],
    logos: Annotated[RuleLogoResolver, Depends(get_logo_resolver)],
    user: Annotated[User, Depends(get_current_user)],
) -> RulePackPreviewResult:
    """Report what importing a pack would do, and how much of the backlog it would categorise."""
    preview = service.preview(user.id, service.load_source(payload))
    return RulePackPreviewResult(
        name=preview.name,
        total=preview.total,
        new_count=preview.new_count,
        duplicate_count=preview.duplicate_count,
        unresolved=preview.unresolved,
        would_match_count=preview.would_match_count,
        samples=logos.fill_rows(
            TransactionRead.model_validate(sample) for sample in preview.samples
        ),
    )


@router.post("/packs/import", response_model=RulePackImportResult)
async def import_pack(
    payload: RulePackImportRequest,
    service: Annotated[RulePackService, Depends(_pack_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RulePackImportResult:
    """Import a pack's resolvable, non-duplicate rules, optionally re-applying them after."""
    result = service.import_pack(user.id, service.load_source(payload), payload.apply_now)
    return RulePackImportResult(
        created_count=result.created_count,
        skipped_count=result.skipped_count,
        unresolved=result.unresolved,
        recategorized_count=result.recategorized_count,
    )


@router.get("/packs/export", response_model=RulePackExportResult)
async def export_pack(
    service: Annotated[RulePackService, Depends(_pack_service)],
    user: Annotated[User, Depends(get_current_user)],
    enabled_only: bool = False,
    name: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=100,
            description="Title for the exported pack; the UI's review step supplies it.",
        ),
    ] = None,
) -> RulePackExportResult:
    """Return the caller's rules as a pack for review, plus the ones it could not carry.

    A body, not a download: a pattern can hold personal detail, so the user sees the file's
    contents before it becomes a file.
    """
    result = service.export(user.id, user.locale, enabled_only, name)
    return RulePackExportResult(pack=result.pack, omitted=result.omitted)


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


@router.get(
    "/{rule_id}/logo",
    response_class=Response,
    responses={200: {"content": {"image/png": {}}}, 304: {"description": "Not modified"}},
)
async def get_rule_logo(
    rule_id: str,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    if_none_match: Annotated[str | None, Header()] = None,
) -> Response:
    """Return a rule's logo, or 304 when the caller's cached copy is still current."""
    logo = service.get_logo(user.id, rule_id)
    etag = f'"{int(logo.updated_at.timestamp() * 1_000_000)}"'
    # The app revalidates every time, so a replaced logo shows at once.
    headers = {"ETag": etag, "Cache-Control": "no-cache"}
    if if_none_match == etag:
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers=headers)
    return Response(content=logo.image, media_type=logo.content_type, headers=headers)


@router.put("/{rule_id}/logo", response_model=RuleRead)
async def upload_rule_logo(
    rule_id: str,
    file: Annotated[UploadFile, File()],
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleRead:
    """Make an uploaded PNG, JPEG or WebP picture the rule's logo, replacing any earlier one.

    The transactions and series the rule matches show it in place of their monogram.
    """
    # One byte over the cap is enough to know the file is too large, without reading it all.
    data = await file.read(MAX_UPLOAD_BYTES + 1)
    return _to_read(service.upload_logo(user.id, rule_id, data))


@router.delete("/{rule_id}/logo", response_model=RuleRead)
async def remove_rule_logo(
    rule_id: str,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleRead:
    """Drop the rule's logo; its rows show their monogram again."""
    return _to_read(service.remove_logo(user.id, rule_id))


@router.post("/apply", response_model=RuleApplyResult)
async def apply_rules(
    payload: RuleApplyRequest,
    service: Annotated[RuleService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RuleApplyResult:
    """Re-run the enabled rules over the caller's transactions, optionally one account."""
    count = service.apply(user.id, payload.account_id)
    return RuleApplyResult(recategorized_count=count)
