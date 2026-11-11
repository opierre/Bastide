"""Idempotent seed of the rich, localized (fr/en) system category catalog.

``categories.name`` stores the i18n key for system rows; the frontend resolves
it to a localized string via its own ARB entries.  The fr/en names below are the catalog's
source of truth for those translations, not persisted columns.

``color`` is pinned to the eight category hues in ``docs/design/00-shared-design-block.md``
(Logement/Alimentation/Transport/Loisirs/Abonnements/Santé/Autres·Épargne/Revenus) rather than
invented per category — the design spec is the source of truth for color, this catalog follows
it. Every child inherits its top-level bucket's hue. Categories with no dedicated pinned hue
(Achats, Finances, Enfants, Animaux) take the shared "Autres/Épargne" catch-all (#64748B), which
is also why Épargne needs no color of its own — it's the same hue as Autres, just a different
bucket. Abonnements is a top-level bucket, not a child of Loisirs, because the design spec pins
it as its own hue distinct from Loisirs. It also stays childless: the categorisation prompt only
offers leaves, and the built-in rule pack files every streaming and telecom merchant under it.

Keys are permanent: rules and rule packs reference categories by key, so an entry is only ever
added, never renamed or moved to another parent. A new entry reaches existing installs through
the idempotent seed at the next boot.
"""

import logging
from dataclasses import dataclass, field
from uuid import uuid4

from sqlalchemy import select
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
            CategorySeed(
                "category.housing.condo_fees",
                "Charges de copropriété",
                "Condo fees",
                "expense",
                "apartment",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.maintenance",
                "Travaux et entretien",
                "Repairs and maintenance",
                "expense",
                "handyman",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.home_services",
                "Services à domicile",
                "Home services",
                "expense",
                "cleaning_services",
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
            CategorySeed(
                "category.food.takeaway",
                "Livraison et à emporter",
                "Takeaway and delivery",
                "expense",
                "takeout_dining",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.canteen",
                "Cantine",
                "Canteen",
                "expense",
                "lunch_dining",
                _ALIMENTATION,
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
            CategorySeed(
                "category.transport.car_insurance",
                "Assurance auto",
                "Car insurance",
                "expense",
                "shield_car",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.tolls",
                "Péages",
                "Tolls",
                "expense",
                "toll",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.taxi",
                "Taxi et VTC",
                "Taxi and ride-hailing",
                "expense",
                "local_taxi",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.rental",
                "Location de véhicule",
                "Vehicle rental",
                "expense",
                "car_rental",
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
            CategorySeed(
                "category.health.dentist",
                "Dentiste",
                "Dentist",
                "expense",
                "dentistry",
                _SANTE,
            ),
            CategorySeed(
                "category.health.optician",
                "Optique",
                "Optician",
                "expense",
                "visibility",
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
            CategorySeed(
                "category.leisure.accommodation",
                "Hébergement",
                "Accommodation",
                "expense",
                "hotel",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.sports",
                "Sport",
                "Sports",
                "expense",
                "fitness_center",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.culture",
                "Culture",
                "Culture",
                "expense",
                "menu_book",
                _LOISIRS,
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
            CategorySeed(
                "category.shopping.personal_care",
                "Beauté et soins",
                "Personal care",
                "expense",
                "spa",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.shopping.gifts",
                "Cadeaux",
                "Gifts",
                "expense",
                "redeem",
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
            # The one debit a deferred-debit card makes on the current account each month. A
            # transfer, because the purchases it settles are already booked one by one on the
            # card's own account — counting the lump sum too would double the month's spending.
            CategorySeed(
                "category.finance.card_settlement",
                "Règlement carte différée",
                "Deferred card settlement",
                "transfer",
                "credit_card",
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
            # A transfer, like savings: money moved to a brokerage or life-insurance contract
            # still belongs to the user, so it is not spending.
            CategorySeed(
                "category.finance.investments",
                "Investissements",
                "Investments",
                "transfer",
                "show_chart",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.finance.loans",
                "Remboursement de crédit",
                "Loan repayment",
                "expense",
                "credit_score",
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
            # A pension and a dividend are ordinary income a user categorises beside a salary.
            CategorySeed(
                "category.income.pension",
                "Retraite",
                "Pension",
                "income",
                "elderly",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.dividends",
                "Dividendes",
                "Dividends",
                "income",
                "savings",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.refunds",
                "Remboursements",
                "Refunds",
                "income",
                "replay",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.benefits",
                "Allocations et aides",
                "Benefits",
                "income",
                "family_restroom",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.rental",
                "Revenus locatifs",
                "Rental income",
                "income",
                "real_estate_agent",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.sales",
                "Ventes",
                "Sales",
                "income",
                "sell",
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
            CategorySeed(
                "category.other.donations",
                "Dons",
                "Donations",
                "expense",
                "volunteer_activism",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
    CategorySeed(
        "category.children",
        "Enfants",
        "Children",
        "expense",
        "child_care",
        _AUTRES_EPARGNE,
        children=(
            CategorySeed(
                "category.children.childcare",
                "Garde d'enfants",
                "Childcare",
                "expense",
                "child_friendly",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.children.school",
                "Scolarité",
                "Schooling",
                "expense",
                "school",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.children.activities",
                "Activités enfants",
                "Kids' activities",
                "expense",
                "toys",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
    CategorySeed(
        "category.pets",
        "Animaux",
        "Pets",
        "expense",
        "pets",
        _AUTRES_EPARGNE,
        children=(
            CategorySeed(
                "category.pets.food",
                "Alimentation animaux",
                "Pet food",
                "expense",
                "pet_supplies",
                _AUTRES_EPARGNE,
            ),
            CategorySeed(
                "category.pets.vet",
                "Vétérinaire",
                "Vet",
                "expense",
                "vaccines",
                _AUTRES_EPARGNE,
            ),
        ),
    ),
)


def ensure_system_categories(db: Session) -> int:
    """Insert the missing system categories, skipping any i18n key that already exists.

    The existing catalog is read in one query and new rows get their ids up front, so a boot
    against an already-seeded database costs a single SELECT rather than one per entry.

    Leaves the transaction open, so a caller that is already in one — the database reset, which
    empties a profile and restores the catalog atomically — commits the whole thing once.

    Returns:
        How many rows were added.
    """
    ids_by_key = {
        name: category_id
        for name, category_id in db.execute(
            select(Category.name, Category.id).where(Category.is_system.is_(True))
        )
    }
    created = 0

    def ensure(seed: CategorySeed, parent_id: str | None) -> str:
        nonlocal created
        category_id = ids_by_key.get(seed.key)
        if category_id is None:
            category_id = str(uuid4())
            db.add(
                Category(
                    id=category_id,
                    user_id=None,
                    parent_id=parent_id,
                    name=seed.key,
                    kind=seed.kind,
                    icon=seed.icon,
                    color=seed.color,
                    is_system=True,
                )
            )
            created += 1
        return category_id

    for group in SYSTEM_CATEGORIES:
        parent_id = ensure(group, parent_id=None)
        for child in group.children:
            ensure(child, parent_id=parent_id)
    db.flush()
    return created


def seed_categories(db: Session) -> int:
    """Insert the system category catalog and commit; return how many rows were added."""
    created = ensure_system_categories(db)
    db.commit()
    return created


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
        created = seed_categories(db)
    finally:
        db.close()
    if created:
        logger.info("Seeded %d system categor%s.", created, "y" if created == 1 else "ies")
    return created
