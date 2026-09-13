"""Property endpoints: declared-asset CRUD with the held share derived per request."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.properties.repository import PropertyRepository
from app.features.properties.schemas import (
    PropertyCreate,
    PropertyDetail,
    PropertyRead,
    PropertyUpdate,
)
from app.features.properties.service import PropertyService

router = APIRouter(prefix="/api/v1/properties", tags=["properties"])


def _service(db: Annotated[Session, Depends(get_db)]) -> PropertyService:
    return PropertyService(PropertyRepository(db))


def get_today() -> date:
    """The date a valuation is checked against; a dependency so tests can pin it."""
    return date.today()


@router.get("", response_model=list[PropertyRead])
async def list_properties(
    service: Annotated[PropertyService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    archived: Annotated[
        bool, Query(description="Return the archived properties instead of the live ones.")
    ] = False,
) -> list[PropertyRead]:
    """List the caller's properties with their share figures; archived ones only when asked."""
    return service.list_for_user(user, archived)


@router.post("", response_model=PropertyDetail, status_code=status.HTTP_201_CREATED)
async def create_property(
    payload: PropertyCreate,
    service: Annotated[PropertyService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> PropertyDetail:
    """Declare a property. The share figures are derived on the way out, never stored."""
    return service.create(user, payload, today)


@router.get("/{property_id}", response_model=PropertyDetail)
async def get_property(
    property_id: str,
    service: Annotated[PropertyService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> PropertyDetail:
    """One property with the loans linked to it, so the user sees what the IFI base nets off."""
    return service.get(user, property_id)


@router.patch("/{property_id}", response_model=PropertyDetail)
async def update_property(
    property_id: str,
    payload: PropertyUpdate,
    service: Annotated[PropertyService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> PropertyDetail:
    """Patch a property, including a re-valuation and unarchiving through `archived`."""
    return service.update(user, property_id, payload, today)


@router.delete("/{property_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_property(
    property_id: str,
    service: Annotated[PropertyService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Archive a property (never hard-deletes); the loans pointing at it keep their link."""
    service.archive(user.id, property_id)
