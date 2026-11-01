"""SQLAlchemy models for detected recurring series and the transactions backing them."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Date,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime


class RecurringSeries(Base):
    """A recurring charge grouped by normalised merchant key within one account.

    ``expected_amount_minor`` is signed like every other money column: a subscription is an
    outflow, so it is negative.
    """

    __tablename__ = "recurring_series"
    __table_args__ = (
        # Re-running the detector must update a series rather than duplicate it, so the
        # grouping key it matches on is unique in the database, not just in the service.
        UniqueConstraint("account_id", "merchant_key", name="uq_recurring_series_account_merchant"),
        # The subscriptions screen lists a user's series filtered by lifecycle status.
        Index("ix_recurring_series_user_status", "user_id", "status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"))
    #: Normalised grouping key derived from `merchant` / `description_clean`.
    merchant_key: Mapped[str] = mapped_column(String(255))
    #: User-facing name; defaults to the prettiest observed merchant, user-editable.
    label: Mapped[str] = mapped_column(String(255))
    category_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("categories.id"), nullable=True
    )
    cadence: Mapped[str] = mapped_column(String(10))
    #: Observed median gap between occurrences; backs the cadence classification.
    median_interval_days: Mapped[int] = mapped_column(Integer)
    expected_amount_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    first_seen_date: Mapped[date] = mapped_column(Date)
    last_seen_date: Mapped[date] = mapped_column(Date)
    #: Stored (`last_seen_date + median_interval_days`) because the detector computes it.
    #: "Missed charge" is deliberately *not* stored — it stops being true the moment the
    #: charge lands, so it is derived at read time.
    next_expected_date: Mapped[date] = mapped_column(Date)
    occurrence_count: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(10))
    #: True = created by the user from its charges; the detector never overwrites what
    #: they declared on it.
    is_manual: Mapped[bool] = mapped_column(Boolean, default=False)
    #: Last observed step in `expected_amount_minor`, signed.
    price_change_minor: Mapped[int | None] = mapped_column(Integer, nullable=True)
    price_changed_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class RecurringOccurrence(Base):
    """Links one transaction to the series it belongs to.

    A link table rather than a column on ``transactions``: occurrences are detector output the
    user can attach and detach, and keeping that churn out of the ledger table means
    re-detection never writes to the single source of truth.
    """

    __tablename__ = "recurring_occurrences"
    __table_args__ = (
        # A transaction belongs to at most one series — enforced by the database, not only by
        # the detector, since attach/detach has several call paths.
        UniqueConstraint("transaction_id", name="uq_recurring_occurrences_transaction"),
        Index("ix_recurring_occurrences_series_id", "series_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    series_id: Mapped[str] = mapped_column(String(36), ForeignKey("recurring_series.id"))
    #: Cascades: an occurrence is a pointer into the ledger, so deleting the ledger row must
    #: take the pointer with it rather than leave a dangling link.
    transaction_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("transactions.id", ondelete="CASCADE")
    )
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))


class RecurringMerchantAlias(Base):
    """A grouping key the user merged into a series: its charges count as that series'.

    A merchant that renames itself mid-subscription (« STREAMCO » becoming « STREAMCO -
    STREAMCO TV ») splits into two series, since detection groups on the label. Merging
    records the label left behind here, so every later pass groups both under the kept series
    instead of recreating the one the user merged away.
    """

    __tablename__ = "recurring_merchant_aliases"
    __table_args__ = (
        # A key resolves to one series, or detection could not tell which to group it under.
        UniqueConstraint("account_id", "merchant_key", name="uq_recurring_alias_account_merchant"),
        Index("ix_recurring_merchant_aliases_series_id", "series_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"))
    #: Cascades: an alias only means something while the series it points at exists.
    series_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("recurring_series.id", ondelete="CASCADE")
    )
    merchant_key: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))


class RecurringMergeDismissal(Base):
    """Two grouping keys the user said are distinct subscriptions, so never proposed again.

    Keyed on `(account, merchant key)` rather than on series ids: a series can be deleted and
    detected again under a new id, and the user's « these are two subscriptions » is about the
    merchants, not the rows. The two sides may sit on different accounts, since one
    subscription can move between them. They are stored in sorted order so one row answers for
    both directions.
    """

    __tablename__ = "recurring_merge_dismissals"
    __table_args__ = (
        UniqueConstraint(
            "first_account_id",
            "first_key",
            "second_account_id",
            "second_key",
            name="uq_recurring_merge_dismissal_pair",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    #: The lower of the two `(account, key)` sides.
    first_account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"))
    first_key: Mapped[str] = mapped_column(String(255))
    #: The higher of the two sides.
    second_account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"))
    second_key: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
