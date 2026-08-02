"""Business logic for category CRUD: system rows are read-only, users manage their own."""

from app.core.errors import NotFoundError
from app.features.categories.models import Category
from app.features.categories.repository import CategoryRepository
from app.features.categories.schemas import CategoryCreate, CategoryUpdate


class CategoryNotFoundError(NotFoundError):
    """Raised when a category doesn't exist, isn't the caller's, or is a system category."""

    code = "CATEGORY_NOT_FOUND"


class CategoryService:
    """Category listing (system + user) and CRUD scoped to the user's own rows."""

    def __init__(self, repository: CategoryRepository) -> None:
        self._repository = repository

    def list_for_user(self, user_id: str) -> list[Category]:
        """List system categories plus this user's own."""
        return self._repository.list_for_user(user_id)

    def get_own(self, user_id: str, category_id: str) -> Category:
        """Fetch a category the user owns.

        Raises:
            CategoryNotFoundError: no such category, it belongs to another user, or it's a
                system category (system rows have `user_id=None` and are never user-owned).
        """
        category = self._repository.get_owned_by_id_for_user(category_id, user_id)
        if category is None:
            raise CategoryNotFoundError("Category not found.")
        return category

    def create(self, user_id: str, data: CategoryCreate) -> Category:
        """Create a new user category."""
        category = Category(
            user_id=user_id,
            parent_id=data.parent_id,
            name=data.name,
            kind=data.kind,
            icon=data.icon,
            color=data.color,
            is_system=False,
        )
        return self._repository.add(category)

    def update(self, user_id: str, category_id: str, data: CategoryUpdate) -> Category:
        """Patch mutable fields on a user's own category.

        Raises:
            CategoryNotFoundError: no such category, it belongs to another user, or it's system.
        """
        category = self.get_own(user_id, category_id)
        if data.name is not None:
            category.name = data.name
        if data.kind is not None:
            category.kind = data.kind
        if data.parent_id is not None:
            category.parent_id = data.parent_id
        if data.icon is not None:
            category.icon = data.icon
        if data.color is not None:
            category.color = data.color
        return self._repository.update(category)

    def delete(self, user_id: str, category_id: str) -> None:
        """Delete a user's own category.

        Raises:
            CategoryNotFoundError: no such category, it belongs to another user, or it's system.
        """
        category = self.get_own(user_id, category_id)
        self._repository.delete(category)
