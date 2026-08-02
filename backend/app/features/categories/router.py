"""Category endpoints: system categories read-only, user CRUD on their own."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categories.models import Category
from app.features.categories.repository import CategoryRepository
from app.features.categories.schemas import CategoryCreate, CategoryRead, CategoryUpdate
from app.features.categories.service import CategoryService

router = APIRouter(prefix="/api/v1/categories", tags=["categories"])


def _service(db: Annotated[Session, Depends(get_db)]) -> CategoryService:
    return CategoryService(CategoryRepository(db))


def _to_read(category: Category) -> CategoryRead:
    return CategoryRead(
        id=category.id,
        user_id=category.user_id,
        parent_id=category.parent_id,
        name=category.name,
        kind=category.kind,
        icon=category.icon,
        color=category.color,
        is_system=category.is_system,
    )


@router.get("", response_model=list[CategoryRead])
async def list_categories(
    service: Annotated[CategoryService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[CategoryRead]:
    """List system categories plus the caller's own."""
    return [_to_read(category) for category in service.list_for_user(user.id)]


@router.post("", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreate,
    service: Annotated[CategoryService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CategoryRead:
    """Create a new user category."""
    return _to_read(service.create(user.id, payload))


@router.patch("/{category_id}", response_model=CategoryRead)
async def update_category(
    category_id: str,
    payload: CategoryUpdate,
    service: Annotated[CategoryService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CategoryRead:
    """Patch a user's own category. System categories 404 (not user-owned)."""
    return _to_read(service.update(user.id, category_id, payload))


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: str,
    service: Annotated[CategoryService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Delete a user's own category. System categories 404 (not user-owned)."""
    service.delete(user.id, category_id)
