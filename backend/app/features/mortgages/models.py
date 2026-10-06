"""SQLAlchemy models for declared loans and saved simulator scenarios.

Neither table stores a derived figure: the amortisation schedule and every simulation result are
pure functions of the declared inputs (PROJECT.md §15, §17), computed per request.
"""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Mortgage(Base):
    """A loan the user declares.

    ``kind`` (the credit product the user recognises) and ``repayment_type`` (the maths the
    schedule runs on) are two axes, not one: a works loan can be either constant-payment or in
    fine. Every rate is an integer in basis points.
    """

    __tablename__ = "mortgages"
    __table_args__ = (
        # The panel prints `kind` on every card, so an unknown value is rejected by the
        # database rather than surfacing as an unlabelled loan.
        CheckConstraint(
            "kind IN ('mortgage', 'works', 'consumer', 'auto')", name="ck_mortgages_kind"
        ),
        # The Crédits panel lists a user's loans filtered by lifecycle status.
        Index("ix_mortgages_user_status", "user_id", "status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    label: Mapped[str] = mapped_column(String(255))
    #: Bank name; drives the monogram chip, as `accounts.institution` does.
    lender: Mapped[str] = mapped_column(String(255))
    #: Sets null rather than cascading: archiving or deleting a property must not delete the
    #: loan that financed it.
    property_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("properties.id", ondelete="SET NULL"), nullable=True
    )
    kind: Mapped[str] = mapped_column(String(20))
    repayment_type: Mapped[str] = mapped_column(String(20))
    #: Capital borrowed, positive.
    principal_minor: Mapped[int] = mapped_column(Integer)
    annual_rate_bps: Mapped[int] = mapped_column(Integer)
    #: Borrower's insurance premium per instalment; 0 = none.
    insurance_monthly_minor: Mapped[int] = mapped_column(Integer, default=0)
    term_months: Mapped[int] = mapped_column(Integer)
    #: Anchors every instalment date; the payment day comes from it.
    first_payment_date: Mapped[date] = mapped_column(Date)
    #: Frais de dossier + garantie; feeds total cost and TAEG.
    upfront_fees_minor: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(10))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class MortgageSimulation(Base):
    """A saved simulator scenario — inputs only; a stored result would outlive its inputs."""

    __tablename__ = "mortgage_simulations"
    __table_args__ = (Index("ix_mortgage_simulations_user_created_at", "user_id", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    label: Mapped[str] = mapped_column(String(255))
    property_price_minor: Mapped[int] = mapped_column(Integer)
    #: Apport.
    down_payment_minor: Mapped[int] = mapped_column(Integer)
    #: Borrowed amount as declared (price + fees − apport by default).
    principal_minor: Mapped[int] = mapped_column(Integer)
    annual_rate_bps: Mapped[int] = mapped_column(Integer)
    insurance_monthly_minor: Mapped[int] = mapped_column(Integer)
    term_months: Mapped[int] = mapped_column(Integer)
    upfront_fees_minor: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
