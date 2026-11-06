"""FastAPI dependency giving a route the caller's rule-logo resolver.

Shared by every router whose responses carry a merchant chip: transactions, recurring series,
and the rule previews.
"""

from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.rules.logos import RuleLogoResolver
from app.features.rules.repository import RuleRepository


def get_logo_resolver(
    db: Annotated[Session, Depends(get_db)], user: Annotated[User, Depends(get_current_user)]
) -> RuleLogoResolver:
    """The resolver finding which rule's logo each of the caller's rows shows."""
    return RuleLogoResolver(RuleRepository(db), user.id)
