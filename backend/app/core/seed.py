"""Idempotent seed of the rich, localized (fr/en) system category catalog.

``categories.name`` stores the i18n key for system rows (PROJECT.md §4); the frontend resolves
it to a localized string via its own ARB entries. The fr/en names below are the catalog's
source of truth for those translations, not persisted columns.
"""

from dataclasses import dataclass, field

from sqlalchemy.orm import Session

from app.features.categories.models import Category


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
        "#F59E0B",
        children=(
            CategorySeed("category.housing.rent", "Loyer", "Rent", "expense", "key", "#F59E0B"),
            CategorySeed(
                "category.housing.mortgage",
                "Prêt immobilier",
                "Mortgage",
                "expense",
                "home_work",
                "#F59E0B",
            ),
            CategorySeed(
                "category.housing.utilities", "Charges", "Utilities", "expense", "bolt", "#F59E0B"
            ),
            CategorySeed(
                "category.housing.home_insurance",
                "Assurance habitation",
                "Home insurance",
                "expense",
                "shield_home",
                "#F59E0B",
            ),
        ),
    ),
    CategorySeed(
        "category.food",
        "Alimentation",
        "Food",
        "expense",
        "restaurant",
        "#10B981",
        children=(
            CategorySeed(
                "category.food.groceries",
                "Courses",
                "Groceries",
                "expense",
                "shopping_cart",
                "#10B981",
            ),
            CategorySeed(
                "category.food.restaurants",
                "Restaurants",
                "Restaurants",
                "expense",
                "restaurant",
                "#10B981",
            ),
            CategorySeed(
                "category.food.coffee", "Café", "Coffee", "expense", "local_cafe", "#10B981"
            ),
        ),
    ),
    CategorySeed(
        "category.transport",
        "Transport",
        "Transport",
        "expense",
        "directions_car",
        "#3B82F6",
        children=(
            CategorySeed(
                "category.transport.fuel",
                "Carburant",
                "Fuel",
                "expense",
                "local_gas_station",
                "#3B82F6",
            ),
            CategorySeed(
                "category.transport.public_transit",
                "Transports en commun",
                "Public transit",
                "expense",
                "directions_bus",
                "#3B82F6",
            ),
            CategorySeed(
                "category.transport.parking",
                "Stationnement",
                "Parking",
                "expense",
                "local_parking",
                "#3B82F6",
            ),
            CategorySeed(
                "category.transport.car_maintenance",
                "Entretien auto",
                "Car maintenance",
                "expense",
                "car_repair",
                "#3B82F6",
            ),
        ),
    ),
    CategorySeed(
        "category.health",
        "Santé",
        "Health",
        "expense",
        "health_and_safety",
        "#EF4444",
        children=(
            CategorySeed(
                "category.health.doctor",
                "Médecin",
                "Doctor",
                "expense",
                "medical_services",
                "#EF4444",
            ),
            CategorySeed(
                "category.health.pharmacy",
                "Pharmacie",
                "Pharmacy",
                "expense",
                "local_pharmacy",
                "#EF4444",
            ),
            CategorySeed(
                "category.health.insurance",
                "Mutuelle",
                "Health insurance",
                "expense",
                "shield_health",
                "#EF4444",
            ),
        ),
    ),
    CategorySeed(
        "category.leisure",
        "Loisirs",
        "Leisure",
        "expense",
        "celebration",
        "#8B5CF6",
        children=(
            CategorySeed(
                "category.leisure.subscriptions",
                "Abonnements",
                "Subscriptions",
                "expense",
                "subscriptions",
                "#8B5CF6",
            ),
            CategorySeed(
                "category.leisure.outings",
                "Sorties",
                "Outings",
                "expense",
                "local_activity",
                "#8B5CF6",
            ),
            CategorySeed(
                "category.leisure.travel", "Voyages", "Travel", "expense", "flight", "#8B5CF6"
            ),
        ),
    ),
    CategorySeed(
        "category.shopping",
        "Achats",
        "Shopping",
        "expense",
        "shopping_bag",
        "#EC4899",
        children=(
            CategorySeed(
                "category.shopping.clothing",
                "Vêtements",
                "Clothing",
                "expense",
                "checkroom",
                "#EC4899",
            ),
            CategorySeed(
                "category.shopping.electronics",
                "Électronique",
                "Electronics",
                "expense",
                "devices",
                "#EC4899",
            ),
            CategorySeed("category.shopping.home", "Maison", "Home", "expense", "chair", "#EC4899"),
        ),
    ),
    CategorySeed(
        "category.finance",
        "Finances",
        "Finances",
        "expense",
        "account_balance",
        "#6B7280",
        children=(
            CategorySeed(
                "category.finance.bank_fees",
                "Frais bancaires",
                "Bank fees",
                "expense",
                "receipt_long",
                "#6B7280",
            ),
            CategorySeed(
                "category.finance.taxes", "Impôts", "Taxes", "expense", "payments", "#6B7280"
            ),
            CategorySeed(
                "category.finance.savings",
                "Épargne",
                "Savings",
                "transfer",
                "savings",
                "#6B7280",
            ),
            CategorySeed(
                "category.finance.interest",
                "Intérêts",
                "Interest",
                "income",
                "trending_up",
                "#6B7280",
            ),
        ),
    ),
    CategorySeed(
        "category.income",
        "Revenus",
        "Income",
        "income",
        "attach_money",
        "#22C55E",
        children=(
            CategorySeed(
                "category.income.salary", "Salaire", "Salary", "income", "work", "#22C55E"
            ),
            CategorySeed(
                "category.income.refunds",
                "Remboursements",
                "Refunds",
                "income",
                "replay",
                "#22C55E",
            ),
            CategorySeed(
                "category.income.other",
                "Autres revenus",
                "Other income",
                "income",
                "add_circle",
                "#22C55E",
            ),
        ),
    ),
    CategorySeed(
        "category.other",
        "Divers",
        "Other",
        "expense",
        "category",
        "#94A3B8",
        children=(
            CategorySeed(
                "category.other.uncategorized",
                "Non catégorisé",
                "Uncategorized",
                "expense",
                "help",
                "#94A3B8",
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


def seed_categories(db: Session) -> None:
    """Insert the system category catalog, skipping any i18n key that already exists."""
    for group in SYSTEM_CATEGORIES:
        parent = _get_or_create(db, group, parent_id=None)
        for child in group.children:
            _get_or_create(db, child, parent_id=parent.id)
    db.commit()
