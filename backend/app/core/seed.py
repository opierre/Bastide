"""Idempotent seed of the rich, localized (fr/en) system category catalog.

``categories.name`` stores the i18n key for system rows; the frontend resolves
it to a localized string via its own ARB entries.  The fr/en names below are the catalog's
source of truth for those translations, not persisted columns.

``color`` holds the category's hue slot from ``docs/design/00-design-system.md`` §2.4, which the
app's theme resolves to a colour. Every top-level bucket has a slot of its own, so the panel
reads at a glance, and every child inherits its bucket's slot. Divers, the catch-all, keeps the
neutral ``cat0``. Abonnements is a top-level bucket, not a child of Loisirs, because the design
spec gives it its own slot distinct from Loisirs. It also stays childless: the categorisation
prompt only offers leaves, and the built-in rule pack files every streaming and telecom merchant
under it.

``icon`` is a Lucide icon name (§10), one fitting glyph per entry; the app draws it from the
curated set in ``frontend/lib/core/widgets/category_icons.dart``.

System rows are read-only to users, so the seed owns their icon and slot: a boot rewrites both
on a row whose values differ from the catalog's, which is how a restyle reaches every install.

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

# The category hue slots (docs/design/00-design-system.md §2.4).
_LOGEMENT = "cat1"
_ALIMENTATION = "cat2"
_TRANSPORT = "cat3"
_ABONNEMENTS = "cat4"
_LOISIRS = "cat5"
_SANTE = "cat6"
_ACHATS = "cat7"
_FINANCES = "cat8"
_ENFANTS = "cat9"
_ANIMAUX = "cat10"
_DIVERS = "cat0"
_REVENUS = "income"


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
        "house",
        _LOGEMENT,
        children=(
            CategorySeed(
                "category.housing.rent", "Loyer", "Rent", "expense", "key-round", _LOGEMENT
            ),
            CategorySeed(
                "category.housing.mortgage",
                "Prêt immobilier",
                "Mortgage",
                "expense",
                "landmark",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.utilities", "Charges", "Utilities", "expense", "zap", _LOGEMENT
            ),
            CategorySeed(
                "category.housing.home_insurance",
                "Assurance habitation",
                "Home insurance",
                "expense",
                "umbrella",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.condo_fees",
                "Charges de copropriété",
                "Condo fees",
                "expense",
                "building-2",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.maintenance",
                "Travaux et entretien",
                "Repairs and maintenance",
                "expense",
                "hammer",
                _LOGEMENT,
            ),
            CategorySeed(
                "category.housing.home_services",
                "Services à domicile",
                "Home services",
                "expense",
                "spray-can",
                _LOGEMENT,
            ),
        ),
    ),
    CategorySeed(
        "category.food",
        "Alimentation",
        "Food",
        "expense",
        "utensils",
        _ALIMENTATION,
        children=(
            CategorySeed(
                "category.food.groceries",
                "Courses",
                "Groceries",
                "expense",
                "shopping-cart",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.restaurants",
                "Restaurants",
                "Restaurants",
                "expense",
                "utensils-crossed",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.coffee", "Café", "Coffee", "expense", "coffee", _ALIMENTATION
            ),
            CategorySeed(
                "category.food.takeaway",
                "Livraison et à emporter",
                "Takeaway and delivery",
                "expense",
                "pizza",
                _ALIMENTATION,
            ),
            CategorySeed(
                "category.food.canteen",
                "Cantine",
                "Canteen",
                "expense",
                "sandwich",
                _ALIMENTATION,
            ),
        ),
    ),
    CategorySeed(
        "category.transport",
        "Transport",
        "Transport",
        "expense",
        "car",
        _TRANSPORT,
        children=(
            CategorySeed(
                "category.transport.fuel",
                "Carburant",
                "Fuel",
                "expense",
                "fuel",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.public_transit",
                "Transports en commun",
                "Public transit",
                "expense",
                "bus",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.parking",
                "Stationnement",
                "Parking",
                "expense",
                "square-parking",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.car_maintenance",
                "Entretien auto",
                "Car maintenance",
                "expense",
                "wrench",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.car_insurance",
                "Assurance auto",
                "Car insurance",
                "expense",
                "shield-check",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.tolls",
                "Péages",
                "Tolls",
                "expense",
                "route",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.taxi",
                "Taxi et VTC",
                "Taxi and ride-hailing",
                "expense",
                "car-taxi-front",
                _TRANSPORT,
            ),
            CategorySeed(
                "category.transport.rental",
                "Location de véhicule",
                "Vehicle rental",
                "expense",
                "car-front",
                _TRANSPORT,
            ),
        ),
    ),
    CategorySeed(
        "category.health",
        "Santé",
        "Health",
        "expense",
        "heart-pulse",
        _SANTE,
        children=(
            CategorySeed(
                "category.health.doctor",
                "Médecin",
                "Doctor",
                "expense",
                "stethoscope",
                _SANTE,
            ),
            CategorySeed(
                "category.health.pharmacy",
                "Pharmacie",
                "Pharmacy",
                "expense",
                "pill",
                _SANTE,
            ),
            CategorySeed(
                "category.health.insurance",
                "Mutuelle",
                "Health insurance",
                "expense",
                "shield-plus",
                _SANTE,
            ),
            CategorySeed(
                "category.health.dentist",
                "Dentiste",
                "Dentist",
                "expense",
                "smile",
                _SANTE,
            ),
            CategorySeed(
                "category.health.optician",
                "Optique",
                "Optician",
                "expense",
                "glasses",
                _SANTE,
            ),
        ),
    ),
    CategorySeed(
        "category.leisure",
        "Loisirs",
        "Leisure",
        "expense",
        "ferris-wheel",
        _LOISIRS,
        children=(
            CategorySeed(
                "category.leisure.outings",
                "Sorties",
                "Outings",
                "expense",
                "ticket",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.travel", "Voyages", "Travel", "expense", "plane", _LOISIRS
            ),
            CategorySeed(
                "category.leisure.accommodation",
                "Hébergement",
                "Accommodation",
                "expense",
                "bed-double",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.sports",
                "Sport",
                "Sports",
                "expense",
                "dumbbell",
                _LOISIRS,
            ),
            CategorySeed(
                "category.leisure.culture",
                "Culture",
                "Culture",
                "expense",
                "book-open",
                _LOISIRS,
            ),
        ),
    ),
    CategorySeed(
        "category.subscriptions",
        "Abonnements",
        "Subscriptions",
        "expense",
        "refresh-cw",
        _ABONNEMENTS,
    ),
    CategorySeed(
        "category.shopping",
        "Achats",
        "Shopping",
        "expense",
        "shopping-bag",
        _ACHATS,
        children=(
            CategorySeed(
                "category.shopping.clothing",
                "Vêtements",
                "Clothing",
                "expense",
                "shirt",
                _ACHATS,
            ),
            CategorySeed(
                "category.shopping.electronics",
                "Électronique",
                "Electronics",
                "expense",
                "monitor-smartphone",
                _ACHATS,
            ),
            CategorySeed(
                "category.shopping.home",
                "Maison",
                "Home",
                "expense",
                "sofa",
                _ACHATS,
            ),
            CategorySeed(
                "category.shopping.personal_care",
                "Beauté et soins",
                "Personal care",
                "expense",
                "scissors",
                _ACHATS,
            ),
            CategorySeed(
                "category.shopping.gifts",
                "Cadeaux",
                "Gifts",
                "expense",
                "gift",
                _ACHATS,
            ),
        ),
    ),
    CategorySeed(
        "category.finance",
        "Finances",
        "Finances",
        "expense",
        "wallet",
        _FINANCES,
        children=(
            CategorySeed(
                "category.finance.bank_fees",
                "Frais bancaires",
                "Bank fees",
                "expense",
                "receipt",
                _FINANCES,
            ),
            CategorySeed(
                "category.finance.taxes",
                "Impôts",
                "Taxes",
                "expense",
                "scroll-text",
                _FINANCES,
            ),
            CategorySeed(
                "category.finance.savings",
                "Épargne",
                "Savings",
                "transfer",
                "piggy-bank",
                _FINANCES,
            ),
            # The one debit a deferred-debit card makes on the current account each month. A
            # transfer, because the purchases it settles are already booked one by one on the
            # card's own account — counting the lump sum too would double the month's spending.
            CategorySeed(
                "category.finance.card_settlement",
                "Règlement carte différée",
                "Deferred card settlement",
                "transfer",
                "credit-card",
                _FINANCES,
            ),
            CategorySeed(
                "category.finance.interest",
                "Intérêts",
                "Interest",
                "income",
                "badge-percent",
                _FINANCES,
            ),
            # A transfer, like savings: money moved to a brokerage or life-insurance contract
            # still belongs to the user, so it is not spending.
            CategorySeed(
                "category.finance.investments",
                "Investissements",
                "Investments",
                "transfer",
                "chart-line",
                _FINANCES,
            ),
            CategorySeed(
                "category.finance.loans",
                "Remboursement de crédit",
                "Loan repayment",
                "expense",
                "hand-coins",
                _FINANCES,
            ),
        ),
    ),
    CategorySeed(
        "category.income",
        "Revenus",
        "Income",
        "income",
        "banknote-arrow-up",
        _REVENUS,
        children=(
            CategorySeed(
                "category.income.salary", "Salaire", "Salary", "income", "briefcase", _REVENUS
            ),
            # A pension and a dividend are ordinary income a user categorises beside a salary.
            CategorySeed(
                "category.income.pension",
                "Retraite",
                "Pension",
                "income",
                "armchair",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.dividends",
                "Dividendes",
                "Dividends",
                "income",
                "coins",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.refunds",
                "Remboursements",
                "Refunds",
                "income",
                "rotate-ccw",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.benefits",
                "Allocations et aides",
                "Benefits",
                "income",
                "hand-helping",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.rental",
                "Revenus locatifs",
                "Rental income",
                "income",
                "building",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.sales",
                "Ventes",
                "Sales",
                "income",
                "tag",
                _REVENUS,
            ),
            CategorySeed(
                "category.income.other",
                "Autres revenus",
                "Other income",
                "income",
                "circle-plus",
                _REVENUS,
            ),
        ),
    ),
    CategorySeed(
        "category.other",
        "Divers",
        "Other",
        "expense",
        "shapes",
        _DIVERS,
        children=(
            CategorySeed(
                "category.other.uncategorized",
                "Non catégorisé",
                "Uncategorized",
                "expense",
                "circle-help",
                _DIVERS,
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
                "banknote",
                _DIVERS,
            ),
            CategorySeed(
                "category.other.donations",
                "Dons",
                "Donations",
                "expense",
                "hand-heart",
                _DIVERS,
            ),
        ),
    ),
    CategorySeed(
        "category.children",
        "Enfants",
        "Children",
        "expense",
        "baby",
        _ENFANTS,
        children=(
            CategorySeed(
                "category.children.childcare",
                "Garde d’enfants",
                "Childcare",
                "expense",
                "heart-handshake",
                _ENFANTS,
            ),
            CategorySeed(
                "category.children.school",
                "Scolarité",
                "Schooling",
                "expense",
                "school",
                _ENFANTS,
            ),
            CategorySeed(
                "category.children.activities",
                "Activités enfants",
                "Kids’ activities",
                "expense",
                "puzzle",
                _ENFANTS,
            ),
        ),
    ),
    CategorySeed(
        "category.pets",
        "Animaux",
        "Pets",
        "expense",
        "paw-print",
        _ANIMAUX,
        children=(
            CategorySeed(
                "category.pets.food",
                "Alimentation animaux",
                "Pet food",
                "expense",
                "bone",
                _ANIMAUX,
            ),
            CategorySeed(
                "category.pets.vet",
                "Vétérinaire",
                "Vet",
                "expense",
                "syringe",
                _ANIMAUX,
            ),
        ),
    ),
)


def ensure_system_categories(db: Session) -> int:
    """Insert the missing system categories, skipping any i18n key that already exists.

    The existing catalog is read in one query and new rows get their ids up front, so a boot
    against an already-seeded database costs a single SELECT rather than one per entry.

    A system row that already exists takes the catalog's current icon and slot when they differ:
    users can't edit system rows, so the catalog is the only source of their styling.

    Leaves the transaction open, so a caller that is already in one — the database reset, which
    empties a profile and restores the catalog atomically — commits the whole thing once.

    Returns:
        How many rows were added.
    """
    existing = {
        row.name: row for row in db.scalars(select(Category).where(Category.is_system.is_(True)))
    }
    created = 0

    def ensure(seed: CategorySeed, parent_id: str | None) -> str:
        nonlocal created
        row = existing.get(seed.key)
        if row is not None:
            # Assigned only on a change, so a boot on an up-to-date catalog writes nothing.
            if row.icon != seed.icon:
                row.icon = seed.icon
            if row.color != seed.color:
                row.color = seed.color
            return row.id
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

    Safe to run on every boot: `ensure_system_categories` skips keys that already exist, which is
    also how a catalog entry added in a later release reaches installs seeded before it, and
    restyles an existing row whose icon or slot the catalog has since changed.
    """
    db = session_factory()
    try:
        created = seed_categories(db)
    finally:
        db.close()
    if created:
        logger.info("Seeded %d system categor%s.", created, "y" if created == 1 else "ies")
    return created
