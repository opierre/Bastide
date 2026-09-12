"""SQLAlchemy models for French tax estimation inputs and parameters (Phase 3).

No estimate is stored: it is a pure function of a profile plus the resolved parameters (§16).
"""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class TaxProfile(Base):
    """One row per user per tax year: the household facts and declared income."""

    __tablename__ = "tax_profiles"
    __table_args__ = (UniqueConstraint("user_id", "tax_year", name="uq_tax_profiles_user_year"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    #: The year the income was earned.
    tax_year: Mapped[int] = mapped_column(Integer)
    household: Mapped[str] = mapped_column(String(10))
    dependents_count: Mapped[int] = mapped_column(Integer, default=0)
    #: Parent isolé (case T).
    single_parent: Mapped[bool] = mapped_column(Boolean, default=False)
    salaries_minor: Mapped[int] = mapped_column(Integer)
    pensions_minor: Mapped[int] = mapped_column(Integer, default=0)
    dividends_minor: Mapped[int] = mapped_column(Integer, default=0)
    interest_minor: Mapped[int] = mapped_column(Integer, default=0)
    capital_gains_minor: Mapped[int] = mapped_column(Integer, default=0)
    #: Opts for the progressive barème instead of the 30 % PFU.
    pfu_opt_out: Mapped[bool] = mapped_column(Boolean, default=False)
    deductions_minor: Mapped[int] = mapped_column(Integer, default=0)
    #: Réductions et crédits d'impôt, applied last.
    credits_minor: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class TaxBracket(Base):
    """One band of a barème. ``user_id = None`` is a seeded system row, as for categories."""

    __tablename__ = "tax_brackets"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "tax_year", "kind", "ordinal", name="uq_tax_brackets_user_year_kind_ordinal"
        ),
        # The system-row read resolves a barème by year and kind, ordered by band.
        Index("ix_tax_brackets_year_kind_ordinal", "tax_year", "kind", "ordinal"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    tax_year: Mapped[int] = mapped_column(Integer)
    #: `ir` | `ifi`.
    kind: Mapped[str] = mapped_column(String(10))
    #: 0-based, ascending.
    ordinal: Mapped[int] = mapped_column(Integer)
    #: Inclusive floor of the band; the top band has no ceiling.
    lower_bound_minor: Mapped[int] = mapped_column(Integer)
    rate_bps: Mapped[int] = mapped_column(Integer)


class TaxParameter(Base):
    """One integer tax parameter. ``user_id = None`` is a seeded system row."""

    __tablename__ = "tax_parameters"
    __table_args__ = (
        UniqueConstraint("user_id", "tax_year", "key", name="uq_tax_parameters_user_year_key"),
        Index("ix_tax_parameters_year_key", "tax_year", "key"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    tax_year: Mapped[int] = mapped_column(Integer)
    #: E.g. `pfu_income_tax_bps`, `micro_foncier_ceiling_minor`.
    key: Mapped[str] = mapped_column(String(64))
    int_value: Mapped[int] = mapped_column(Integer)
    #: `bps` | `minor` | `count` — what the integer means.
    unit: Mapped[str] = mapped_column(String(10))
