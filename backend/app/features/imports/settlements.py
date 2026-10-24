"""Matching a deferred-debit card's settlement to the cycle it paid, and keeping the card's
ledger in step with that match.

A service of its own rather than part of the import pipeline: imports create the links, but a
link must also be undone from wherever the settlement is recategorised.
"""

from sqlalchemy.orm import Session

from app.features.accounts.balance import apply_delta
from app.features.accounts.models import Account
from app.features.categories.repository import CategoryRepository
from app.features.imports.card_settlement import (
    CARD_SETTLEMENT_CATEGORY_KEY,
    RESET_WINDOW,
    cycle_length,
    is_card_settlement,
    offset_dedup_hash,
)
from app.features.imports.ledger import settle_earlier_mismatches, shift_later_snapshots
from app.features.imports.models import ImportBatch
from app.features.imports.repository import ImportRepository
from app.features.transactions.models import Transaction


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

    def link_pending(
        self,
        user_id: str,
        batch: ImportBatch,
        cards: list[Account],
        settlement_category_id: str,
    ) -> None:
        """Match each unmatched settlement to the card cycle it paid, and offset it on the card.

        Runs on every import, whichever side it brings in: the settlement and the cycle it pays
        may arrive in either order, months apart, so each import retries what is still open.

        A settlement is matched only when exactly one card has a cycle totalling it — two cards
        fitting the same amount is a guess, and a wrong link moves money between cards. The
        matched card then gets a credit equal to the settlement, closing the cycle: the
        statement's own reset line when it printed one, else a row posted here, tied to this
        import's batch since it is this import that settled it.
        """
        for settlement in self._repository.unlinked_settlement_candidates(
            user_id, settlement_category_id
        ):
            if settlement.category_id is None and not is_card_settlement(
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
            # A settlement imported before its card existed was left uncategorised; it is one now.
            settlement.category_id = settlement_category_id
            settlement.categorization_source = "rule"
            settlement.needs_review = False
            for row in cycle:
                row.card_settlement_id = settlement.id
            if reset is not None:
                reset.card_settlement_id = settlement.id
                reset.category_id = settlement_category_id
                reset.categorization_source = "rule"
                reset.needs_review = False
            else:
                self._post_offset(card, settlement, batch, settlement_category_id)
            self._db.flush()

    def _post_offset(
        self,
        card: Account,
        settlement: Transaction,
        batch: ImportBatch,
        settlement_category_id: str,
    ) -> None:
        """Credit the card with what the settlement paid, keeping its balance cache and history.

        The credit is a transfer like the debit it mirrors, so neither side counts as income or
        spending — the cycle's purchases already did. It carries the bank's own wording for the
        settlement, the one label the user will recognise.
        """
        offset = Transaction(
            account_id=card.id,
            import_batch_id=batch.id,
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
