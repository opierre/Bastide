"""Matching a deferred-debit card's settlement to the cycle it paid, and keeping the card's
ledger in step with that match.

A service of its own rather than part of the import pipeline: imports create the links, but a
link must also be undone from wherever the settlement is recategorised.
"""

from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from app.features.accounts.balance import apply_delta
from app.features.accounts.models import Account
from app.features.accounts.repository import AccountRepository
from app.features.categories.repository import CategoryRepository
from app.features.imports.card_settlement import (
    CARD_SETTLEMENT_CATEGORY_KEY,
    DETECTED_SOURCE,
    RESET_WINDOW,
    SETTLEMENT_OVERDUE,
    cycle_length,
    is_card_settlement,
    offset_dedup_hash,
)
from app.features.imports.ledger import settle_earlier_mismatches, shift_later_snapshots
from app.features.imports.repository import ImportRepository
from app.features.imports.schemas import CardSettlementStatus, UnmatchedCardPurchases
from app.features.transactions.models import Transaction


@dataclass(frozen=True)
class _Movement:
    """A change to an account's ledger that is not a row of it — a removed row, negated."""

    booked_date: date
    amount_minor: int


class CardSettlementService:
    """Links settlements to card cycles and posts the card-side credit that closes a cycle."""

    def __init__(self, repository: ImportRepository, db: Session) -> None:
        self._repository = repository
        self._db = db

    def settlement_category_id(self, user_id: str) -> str | None:
        """The id of the system category card settlements are filed under."""
        categories = CategoryRepository(self._db).list_system_by_names_for_user(
            [CARD_SETTLEMENT_CATEGORY_KEY], user_id
        )
        return categories[0].id if categories else None

    def tracked_cards(self, user_id: str) -> list[Account]:
        """The user's deferred-debit card accounts.

        Settlement handling is off without one: only when the purchases a settlement pays are
        booked on a card account is filing it as a transfer honest rather than a way of losing
        a month's spending.
        """
        return [
            account
            for account in AccountRepository(self._db).list_by_user(user_id)
            if account.type == "deferred_card"
        ]

    def status(self, user_id: str) -> CardSettlementStatus:
        """What stands between the user's deferred cards and a ledger that counts them once.

        Two things, both empty for a user tracking no card: settlements recognised by their
        label that still wait for confirmation, and card purchases no settlement has claimed
        although the user's other accounts are imported well past the debit that paid them —
        which means the debit is there, unrecognised, and the purchases count twice.

        Only purchases are counted: a refund or a statement's reset line waiting for its
        settlement double-counts nothing.
        """
        cards = self.tracked_cards(user_id)
        settlement_category_id = self.settlement_category_id(user_id)
        if not cards or settlement_category_id is None:
            return CardSettlementStatus(proposed_count=0, unmatched=[])

        unmatched: list[UnmatchedCardPurchases] = []
        latest = self._repository.latest_booked_off_card(user_id)
        if latest is not None:
            for card in cards:
                purchases = [
                    row
                    for row in self._repository.unsettled_card_rows(
                        card.id, latest - SETTLEMENT_OVERDUE
                    )
                    if row.amount_minor < 0
                ]
                if purchases:
                    unmatched.append(
                        UnmatchedCardPurchases(
                            account_id=card.id,
                            amount_minor=sum(row.amount_minor for row in purchases),
                            count=len(purchases),
                            since=purchases[0].booked_date,
                        )
                    )

        return CardSettlementStatus(
            proposed_count=self._repository.count_proposed_settlements(
                user_id, settlement_category_id
            ),
            unmatched=unmatched,
        )

    def link_pending(
        self,
        user_id: str,
        cards: list[Account],
        settlement_category_id: str,
    ) -> None:
        """Match each unmatched settlement to the card cycle it paid, and offset it on the card.

        Runs on every import, whichever side it brings in, and after every categorisation run:
        the settlement and the cycle it pays may arrive in either order, months apart, and the
        model may only now have recognised a settlement, so each pass retries what is open.

        A settlement is matched only when exactly one card has a cycle totalling it — two cards
        fitting the same amount is a guess, and a wrong link moves money between cards. The
        matched card then gets a credit equal to the settlement, closing the cycle: the
        statement's own reset line when it printed one, else a row posted here.
        """
        for settlement in self._repository.unlinked_settlement_candidates(
            user_id, settlement_category_id
        ):
            # A row filed elsewhere — uncategorised, or by the model before the card existed —
            # is only a candidate if its label reads as a settlement.
            if settlement.category_id != settlement_category_id and not is_card_settlement(
                settlement.description_clean, settlement.amount_minor
            ):
                continue

            matches: list[tuple[Account, list[Transaction], Transaction | None]] = []
            for card in cards:
                if card.currency != settlement.currency:
                    continue
                reset = self._repository.find_card_reset(
                    card.id,
                    -settlement.amount_minor,
                    settlement.booked_date - RESET_WINDOW,
                    settlement.booked_date + RESET_WINDOW,
                )
                rows = [
                    row
                    for row in self._repository.unsettled_card_rows(card.id, settlement.booked_date)
                    if row is not reset
                ]
                length = cycle_length(rows, settlement.amount_minor)
                if length is not None:
                    matches.append((card, rows[:length], reset))
            if len(matches) != 1:
                continue

            card, cycle, reset = matches[0]
            if (
                settlement.categorization_source != "user"
                and settlement.category_id != settlement_category_id
            ):
                # Proposed, like any detected settlement — including one imported before its card
                # existed and left uncategorised or filed elsewhere by the model then. One the user
                # confirmed stays theirs, and one already proposed as a settlement stays as it is.
                settlement.category_id = settlement_category_id
                settlement.categorization_source = DETECTED_SOURCE
                settlement.needs_review = True
            for row in cycle:
                row.card_settlement_id = settlement.id
            if reset is not None:
                reset.card_settlement_id = settlement.id
                reset.category_id = settlement_category_id
                reset.categorization_source = "rule"
                reset.needs_review = False
            else:
                self._post_offset(card, settlement, settlement_category_id)
            self._db.flush()

    def _post_offset(
        self, card: Account, settlement: Transaction, settlement_category_id: str
    ) -> None:
        """Credit the card with what the settlement paid, keeping its balance cache and history.

        The credit is a transfer like the debit it mirrors, so neither side counts as income or
        spending — the cycle's purchases already did. It carries the bank's own wording for the
        settlement, the one label the user will recognise, and the settlement's import batch:
        it exists because of that statement, and a categorisation run has no batch of its own.
        """
        offset = Transaction(
            account_id=card.id,
            import_batch_id=settlement.import_batch_id,
            booked_date=settlement.booked_date,
            value_date=None,
            amount_minor=-settlement.amount_minor,
            currency=card.currency,
            description_raw=settlement.description_raw,
            description_clean=settlement.description_clean,
            memo=None,
            merchant=None,
            category_id=settlement_category_id,
            categorization_source="rule",
            needs_review=False,
            fitid=None,
            dedup_hash=offset_dedup_hash(settlement.id),
            card_settlement_id=settlement.id,
        )
        self._db.add(offset)
        self._db.flush()
        apply_delta(card, offset.amount_minor)
        shift_later_snapshots(self._db, card, [offset])
        settle_earlier_mismatches(self._db, card, [offset])

    def adopt_late_resets(
        self, card: Account, new_rows: list[Transaction], settlement_category_id: str
    ) -> None:
        """Let a card statement's reset line take over from a credit posted in its absence.

        A settlement matched before the card statement printing its reset line was imported got
        a posted credit; the reset line then arrives as a new row of the same amount. Kept
        both, the card would be credited twice. The bank's line is the record, so it inherits
        the link and the posted credit is removed.
        """
        for row in new_rows:
            if row.amount_minor <= 0:
                continue
            posted = next(
                (
                    credit
                    for credit in self._repository.linked_credits(
                        card.id,
                        row.amount_minor,
                        row.booked_date - RESET_WINDOW,
                        row.booked_date + RESET_WINDOW,
                    )
                    if credit.card_settlement_id is not None
                    and credit.dedup_hash == offset_dedup_hash(credit.card_settlement_id)
                ),
                None,
            )
            if posted is None:
                continue
            row.card_settlement_id = posted.card_settlement_id
            row.category_id = settlement_category_id
            row.categorization_source = "rule"
            row.needs_review = False
            self._remove_offset(card, posted)

    def follows_its_settlement(self, transaction: Transaction) -> bool:
        """Whether a row's category belongs to its link rather than to the rules.

        True for the card-side credit closing a cycle — posted here, or the statement's own
        reset line. It carries the settlement's wording, so a rule written for the settlement
        matches it too, but it is a transfer for as long as the link stands and goes when the
        link does. A cycle's purchases and refunds are ordinary rows and stay rule-able.
        """
        settlement_id = transaction.card_settlement_id
        if settlement_id is None or transaction.amount_minor <= 0:
            return False
        if transaction.dedup_hash == offset_dedup_hash(settlement_id):
            return True
        settlement = self._db.get(Transaction, settlement_id)
        return settlement is not None and -settlement.amount_minor == transaction.amount_minor

    def recategorized(
        self, user_id: str, transaction: Transaction, previous_category_id: str | None
    ) -> None:
        """Undo a settlement's link once the user files it as something else.

        "Corriger" on a proposed settlement means it was not one: the cycle it was matched to
        is unpaid again, and the credit closing that cycle must go with it.
        """
        settlement_category_id = self.settlement_category_id(user_id)
        if (
            settlement_category_id is None
            or previous_category_id != settlement_category_id
            or transaction.category_id == settlement_category_id
        ):
            return
        self.unlink(transaction, settlement_category_id)

    def unlink(self, settlement: Transaction, settlement_category_id: str) -> None:
        """Release every row a settlement claimed, removing the credit posted for it.

        The cycle's card rows — refunds included — are simply unclaimed, free for another
        settlement to match. A reset line the card statement printed is a real row, so it
        stays, but goes back to the review queue: the settlement category was only ever ours,
        and without the settlement it closed, nobody has said what the line is.
        """
        for row in self._repository.rows_settled_by(settlement.id):
            if row.dedup_hash == offset_dedup_hash(settlement.id):
                card = self._db.get(Account, row.account_id)
                if card is not None:
                    self._remove_offset(card, row)
                continue
            row.card_settlement_id = None
            if row.category_id == settlement_category_id and row.categorization_source != "user":
                row.category_id = None
                row.categorization_source = "uncategorized"
                row.needs_review = True
        self._db.flush()

    def _remove_offset(self, card: Account, offset: Transaction) -> None:
        """Delete a posted credit and take it back out of the card's balance and history."""
        removal = _Movement(booked_date=offset.booked_date, amount_minor=-offset.amount_minor)
        self._repository.delete_transaction(offset)
        apply_delta(card, removal.amount_minor)
        shift_later_snapshots(self._db, card, [removal])
        settle_earlier_mismatches(self._db, card, [removal])
