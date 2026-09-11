"""Idempotent seed of the rich, localized (fr/en) system category catalog.

``categories.name`` stores the i18n key for system rows (PROJECT.md §4); the frontend resolves
it to a localized string via its own ARB entries.  The fr/en names below are the catalog's
source of truth for those translations, not persisted columns.

``color`` is pinned to the eight category hues in ``docs/design/00-shared-design-block.md``
(Logement/Alimentation/Transport/Loisirs/Abonnements/Santé/Autres·Épargne/Revenus) rather than
invented per category — the design spec is the source of truth for color, this catalog follows
it. Every child inherits its top-level bucket's hue. Categories with no dedicated pinned hue
(Achats, Finances) take the shared "Autres/Épargne" catch-all (#64748B), which is also why
Épargne needs no color of its own — it's the same hue as Autres, just a different bucket.
Abonnements is a top-level bucket, not a child of Loisirs, because the design spec pins it as
its own hue distinct from Loisirs.
"""

import logging
from dataclasses import dataclass, field

from sqlalchemy.orm import Session

from app.core.db import SessionFactory
from app.features.categories.models import Category

logger = logging.getLogger(__name__)

# The eight pinned design-system category hues (docs/design/00-shared-design-block.md).
_LOGEMENT = "#4FD1E8"
_ALIMENTATION = "#5AA9FF"
_TRANSPORT = "#2DD4BF"
_LOISIRS = "#F472B6"
_ABONNEMENTS = "#FFB84D"
_SANTE = "#A3E635"
_AUTRES_EPARGNE = "#64748B"
_REVENUS = "#4ADE80"


@dataclass(frozen=True)
class CategorySeed:
    """One system category node: its i18n key, fr/en names, and styling."""

    key: str
    name_fr: str
    name_en: str
    kind: str
    icon: str
    color: str
    children: tuple[CategorySeed, ...] = field(default_factory=tuple)


SYSTEM_CATEGORIES: tuple[CategorySeed, ...] = (
    CategorySeed(
        "category.housing",
        "Logement",
        "Housing",
        "expense",
        "home",
        _LOGEMENT,
        children=(
            CategorySeed("category.housing.rent", "Loyer", "Rent", "expense", "key", _LOGEMENT),
            CategorySeed(
                "category.housing.mortgage",
                "Prêt immobilier",
                "Mortgage",
                "expense",
                "home_work",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.utilities", "Charges", "Utilities", "expense", "bolt", _LOGEMENT
            ),
            CategorySeed(
                "category.housing.home_insurance",
                "Assurance habitation",
                "Home insurance",
                "expense",
                "shield_home",
                _LOGEMENT,
            ),
        ),
    ),
    CategorySeed(
        "category.food",
        "Alimentation",
        "Food",
        "expense",
        "restaurant",
        _ALIMENTATION,
        children=(
            CategorySeed(
                "category.food.groceries",
                "Courses",
                "Groceries",
                "expense",
                "shopping_cart",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.restaurants",
                "Restaurants",
                "Restaurants",
                "expense",
                "restaurant",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.coffee", "Café", "Coffee", "expense", "local_cafe", _ALIMENTATION
            ),
        ),
    ),
    CategorySeed(
        "category.transport",
        "Transport",
        "Transport",
        "expense",
        "directions_car",
        _TRANSPORT,
        children=(
            CategorySeed(
                "category.transport.fuel",
                "Carburant",
                "Fuel",
                "expense",
                "local_gas_station",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.public_transit",
                "Transports en commun",
                "Public transit",
                "expense",
                "directions_bus",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.parking",
                "Stationnement",
                "Parking",
                "expense",
                "local_parking",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.car_maintenance",
                "Entretien auto",
                "Car maintenance",
                "expense",
                "car_repair",
                _TRANSPORT,
            ),
        ),
    ),
    CategorySeed(
        "category.health",
        "Santé",
        "Health",
        "expense",
        "health_and_safety",
        _SANTE,
        children=(
            CategorySeed(
                "category.health.doctor",
                "Médecin",
                "Doctor",
                "expense",
                "medical_services",
                _SANTE,
            ),
            CategorySeed(
                "category.health.pharmacy",
                "Pharmacie",
                "Pharmacy",
                "expense",
                "local_pharmacy",
                _SANTE,
            ),
            CategorySeed(
                "category.health.insurance",
                "Mutuelle",
                "Health insurance",
                "expense",
                "shield_health",
                _SANTE,
            ),
        ),
    ),
    CategorySeed(
        "category.leisure",
        "Loisirs",
        "Leisure",
        "expense",
        "celebration",
        _LOISIRS,
        children=(
            CategorySeed(
                "category.leisure.outings",
                "Sorties",
                "Outings",
                "expense",
                "local_activity",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.travel", "Voyages", "Travel", "expense", "flight", _LOISIRS
            ),
        ),
    ),
    CategorySeed(
        "category.subscriptions",
        "Abonnements",
        "Subscriptions",
        "expense",
        "subscriptions",
        _ABONNEMENTS,
    ),
    CategorySeed(
        "category.shopping",
        "Achats",
        "Shopping",
        "expense",
        "shopping_bag",
        _AUTRES_EPARGNE,
        children=(
            CategorySeed(
                "category.shopping.clothing",
                "Vêtements",
                "Clothing",
                "expense",
                "checkroom",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.shopping.electronics",
                "Électronique",
                "Electronics",
                "expense",
                "devices",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.shopping.home",
                "Maison",
                "Home",
                "expense",
                "chair",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
    CategorySeed(
        "category.finance",
        "Finances",
        "Finances",
        "expense",
        "account_balance",
        _AUTRES_EPARGNE,
        children=(
            CategorySeed(
                "category.finance.bank_fees",
                "Frais bancaires",
                "Bank fees",
                "expense",
                "receipt_long",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.finance.taxes",
                "Impôts",
                "Taxes",
                "expense",
                "payments",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.finance.savings",
                "Épargne",
                "Savings",
                "transfer",
                "savings",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.finance.interest",
                "Intérêts",
                "Interest",
                "income",
                "trending_up",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
    CategorySeed(
        "category.income",
        "Revenus",
        "Income",
        "income",
        "attach_money",
        _REVENUS,
        children=(
            CategorySeed("category.income.salary", "Salaire", "Salary", "income", "work", _REVENUS),
            CategorySeed(
                "category.income.refunds",
                "Remboursements",
                "Refunds",
                "income",
                "replay",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.other",
                "Autres revenus",
                "Other income",
                "income",
                "add_circle",
                _REVENUS,
            ),
        ),
    ),
    CategorySeed(
        "category.other",
        "Divers",
        "Other",
        "expense",
        "category",
        _AUTRES_EPARGNE,
        children=(
            CategorySeed(
                "category.other.uncategorized",
                "Non catégorisé",
                "Uncategorized",
                "expense",
                "help",
                _AUTRES_EPARGNE,
            ),
            # Cash leaves the account for an unknowable purpose, so a withdrawal is a category
            # in its own right rather than a guess at what the cash was later spent on. This is
            # the one operation type a rule can name outright ("RETRAIT DAB" is unambiguous on a
            # French statement); transfers deliberately get no equivalent, because a `VIR EMIS`
            # is as likely to be a reimbursement for theatre tickets as a movement between the
            # user's own accounts, and only the user knows which.
            CategorySeed(
                "category.other.cash",
                "Retraits espèces",
                "Cash withdrawals",
                "expense",
                "atm",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
)


def _get_or_create(db: Session, seed: CategorySeed, parent_id: str | None) -> Category:
    """Return the existing system category for ``seed.key``, or insert and return a new one."""
    existing = db.query(Category).filter_by(name=seed.key, is_system=True).one_or_none()
    if existing is not None:
        return existing

    category = Category(
        user_id=None,
        parent_id=parent_id,
        name=seed.key,
        kind=seed.kind,
        icon=seed.icon,
        color=seed.color,
        is_system=True,
    )
    db.add(category)
    db.flush()
    return category


def ensure_system_categories(db: Session) -> None:
    """Insert the missing system categories, skipping any i18n key that already exists.

    Leaves the transaction open, so a caller that is already in one — the database reset, which
    empties a profile and restores the catalog atomically — commits the whole thing once.
    """
    for group in SYSTEM_CATEGORIES:
        parent = _get_or_create(db, group, parent_id=None)
        for child in group.children:
            _get_or_create(db, child, parent_id=parent.id)


def seed_categories(db: Session) -> None:
    """Insert the system category catalog, skipping any i18n key that already exists."""
    ensure_system_categories(db)
    db.commit()


def seed_system_categories(session_factory: SessionFactory) -> int:
    """Ensure the system catalog exists at startup; return how many rows this call created.

    The catalog is global (`user_id = None`), not per-user, so there is no registration hook it
    naturally belongs to and no migration that could carry it without duplicating the catalog in
    SQL. Startup is the one place guaranteed to run before anything can reference a category —
    and every reference matters: the rule engine assigns these ids, `from-transaction` targets
    them, and rule packs resolve their `category_key` against them.

    Safe to run on every boot: `_get_or_create` skips keys that already exist, which is also how
    a catalog entry added in a later release reaches installs seeded before it.
    """
    db = session_factory()
    try:
        before = db.query(Category).filter_by(is_system=True).count()
        seed_categories(db)
        created = db.query(Category).filter_by(is_system=True).count() - before
    finally:
        db.close()
    if created:
        logger.info("Seeded %d system categor%s.", created, "y" if created == 1 else "ies")
    return created
