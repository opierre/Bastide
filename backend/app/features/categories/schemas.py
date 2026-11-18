"""Request/response schemas for the categories feature."""

from typing import Literal

from pydantic import BaseModel, Field

from app.features.categories.hues import CategoryHue

CategoryKind = Literal["income", "expense", "transfer"]


class CategoryCreate(BaseModel):
    """Payload to create a user category. System categories can't be created via the API."""

    name: str = Field(min_length=1, max_length=255)
    kind: CategoryKind
    parent_id: str | None = None
    icon: str = Field(min_length=1, max_length=50)
    #: The hue slot, resolved to a colour by the app's theme.
    color: CategoryHue


class CategoryUpdate(BaseModel):
    """Patch payload for a user's own category."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    kind: CategoryKind | None = None
    parent_id: str | None = None
    icon: str | None = Field(default=None, min_length=1, max_length=50)
    color: CategoryHue | None = None


class CategoryRead(BaseModel):
    """A category as returned by the API.

    ``name`` is an i18n key for system categories (``is_system=True``) and free text for user
    categories; the frontend resolves system keys via its own ARB entries.
    """

    id: str
    user_id: str | None
    parent_id: str | None
    name: str
    kind: str
    icon: str
    color: str
    is_system: bool
