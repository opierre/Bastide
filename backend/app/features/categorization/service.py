"""The stage-2 decision layer: one batch in, one outcome per row out.

Deliberately pure — no session, no `categorization_run` row, no background task. It takes rows
and returns decisions; persisting them, committing progress per batch, and honouring
cancellation belong to the run executor above it. Keeping the judgement
separable from the orchestration is what lets every case below be tested without a database.
"""

import logging
from collections.abc import Sequence

from app.features.categorization.parser import parse_reply
from app.features.categorization.prompt import (
    PromptCategory,
    build_messages,
    build_response_format,
)
from app.features.categorization.schemas import SuggestionOutcome
from app.features.inference.client import InferenceClient, InferenceError
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction

logger = logging.getLogger(__name__)

# Rows per model request. The trade-off runs in both directions: a bigger batch amortises the
# category list and the few-shot set — the fixed, dominant part of the prompt — over more rows,
# but a small model's accuracy degrades as the batch grows, and its ability to keep the row
# indices straight degrades faster still, so past some point the extra rows come back as
# deferrals and the saving is spent on work that has to be redone by a human. 20 is the
# starting point; it is a constant so it can be moved once real accuracy numbers exist.
BATCH_SIZE = 20


async def categorize_batch(
    rows: Sequence[Transaction],
    categories: Sequence[PromptCategory],
    settings: UserSettings,
    *,
    client: InferenceClient,
) -> list[SuggestionOutcome]:
    """Ask the model to categorise one batch and apply the user's confidence threshold.

    Args:
        rows: the unmatched transactions of one batch, at most ``BATCH_SIZE`` of them.
        categories: the localized leaf categories to offer (see ``prompt.leaf_categories``).
        settings: the user's settings; supplies the model tag and the confidence threshold.
        client: the inference client, injected so no test ever reaches a runtime.

    Returns:
        One outcome per input row, in input order. A row the model answered confidently is
        ``assigned``; one it answered weakly, or not usably, is ``deferred``; every row of a
        batch the runtime errored on is ``failed``. Never raises on the model's account.
    """
    if not rows:
        return []

    model = settings.model_tag
    if not model:
        # No model configured is a configuration state, not a model failure: nothing was asked
        # of the runtime, so the rows are simply unanswered and belong to the review queue.
        logger.debug("Stage-2 skipped: no model tag configured.")
        return [_deferred(index) for index in range(len(rows))]

    try:
        content = await client.complete(
            build_messages(rows, categories),
            model=model,
            response_format=build_response_format(),
        )
    except InferenceError as exc:
        # The runtime, not the reply, is what failed here. That distinction is the whole
        # reason `failed` exists next to `deferred`: a deferral is a row we could not judge,
        # a failure is a row we never got to ask about, and only the latter is worth retrying.
        logger.debug("Stage-2 batch failed against the runtime: %s", exc)
        return [_failed(index) for index in range(len(rows))]

    result = parse_reply(content, [category.id for category in categories])
    if result.discarded:
        logger.debug("Stage-2 discarded %d unusable suggestion(s).", result.discarded)

    threshold = settings.confidence_threshold
    by_index = {suggestion.index: suggestion for suggestion in result.suggestions}

    outcomes: list[SuggestionOutcome] = []
    for index in range(len(rows)):
        suggestion = by_index.get(index)
        if suggestion is None:
            # Includes every defensive-parsing case: unparseable, out of range, hallucinated
            # id, duplicate index, or an index the model simply never answered.
            outcomes.append(_deferred(index))
        elif suggestion.confidence >= threshold:
            outcomes.append(
                SuggestionOutcome(
                    index=index,
                    status="assigned",
                    category_id=suggestion.category_id,
                    confidence=suggestion.confidence,
                    needs_review=False,
                )
            )
        else:
            # Below threshold carries the confidence but no category: a weak guess is not a
            # weak assignment, and letting one through would put `source=model` on a row the
            # user never saw. The score is kept only to help order the review queue.
            outcomes.append(_deferred(index, confidence=suggestion.confidence))

    return outcomes


def _deferred(index: int, confidence: float | None = None) -> SuggestionOutcome:
    return SuggestionOutcome(
        index=index,
        status="deferred",
        category_id=None,
        confidence=confidence,
        needs_review=True,
    )


def _failed(index: int) -> SuggestionOutcome:
    return SuggestionOutcome(
        index=index, status="failed", category_id=None, confidence=None, needs_review=True
    )
