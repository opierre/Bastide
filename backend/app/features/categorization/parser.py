"""Parses a model reply into suggestions, defensively.

The governing rule: **a malformed reply is a deferral, never an exception.**
A small model will, sooner or later, emit prose around its JSON, fence it, truncate mid-array,
repeat an index, invent a category id, or return a confidence of 1.7. None of those may abort
a run — every one of them just means "we don't know", which is precisely what the review queue
is for. So this module raises nothing: it returns the suggestions it could trust and a count of
what it discarded, and logs the rest at debug for whoever is tuning the prompt.
"""

import json
import logging
import re
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

from app.features.categorization.schemas import Suggestion

logger = logging.getLogger(__name__)

# ```json … ``` or ``` … ```: fences are the single most common wrapper a chat-tuned model adds
# even when told to answer with JSON only.
_FENCE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


@dataclass(frozen=True)
class ParseResult:
    """What survived parsing, plus how much did not.

    ``discarded`` exists so a silently degrading prompt is visible as a number rather than
    only as a run that quietly defers everything.
    """

    suggestions: list[Suggestion]
    discarded: int


def parse_reply(content: str, valid_category_ids: Sequence[str]) -> ParseResult:
    """Extract the trustworthy suggestions from one raw model reply.

    Args:
        content: the assistant message exactly as the runtime returned it.
        valid_category_ids: the ids the prompt offered; anything else is a hallucination.

    Returns:
        The suggestions that were well-formed, in-range, and named an offered category, with
        at most one per index. Never raises.
    """
    payload = _load_json(content)
    if payload is None:
        logger.debug("Stage-2 reply was not JSON; deferring the whole batch.")
        return ParseResult(suggestions=[], discarded=0)

    entries = _entries(payload)
    if entries is None:
        logger.debug("Stage-2 reply was JSON but not the expected shape; deferring the batch.")
        return ParseResult(suggestions=[], discarded=0)

    allowed = set(valid_category_ids)
    suggestions: list[Suggestion] = []
    seen: set[int] = set()
    discarded = 0

    for entry in entries:
        suggestion = _to_suggestion(entry, allowed)
        if suggestion is None:
            discarded += 1
        elif suggestion.index in seen:
            # A repeated index means the model lost track of the batch; neither copy is
            # trustworthy enough to prefer, so keep the first and drop the rest.
            logger.debug(
                "Stage-2 reply repeated index %d; ignoring the duplicate.", suggestion.index
            )
            discarded += 1
        else:
            seen.add(suggestion.index)
            suggestions.append(suggestion)

    return ParseResult(suggestions=suggestions, discarded=discarded)


def _load_json(content: str) -> Any:
    """Decode ``content`` as JSON, tolerating fences and surrounding prose. ``None`` if hopeless."""
    for candidate in _candidates(content):
        try:
            return json.loads(candidate)
        except ValueError:
            continue
    return None


def _candidates(content: str) -> list[str]:
    """Return the substrings worth attempting, cheapest and most likely first."""
    stripped = content.strip()
    candidates = [stripped]

    fenced = _FENCE.search(content)
    if fenced is not None:
        candidates.append(fenced.group(1))

    # Last resort for a reply padded with prose: the span from the first opening brace or
    # bracket to the matching last one. Crude, but it costs one slice and rescues the common
    # "Sure! Here you go: {...}" case.
    for opener, closer in (("{", "}"), ("[", "]")):
        start, end = stripped.find(opener), stripped.rfind(closer)
        if 0 <= start < end:
            candidates.append(stripped[start : end + 1])

    return candidates


def _entries(payload: Any) -> list[Any] | None:
    """Return the suggestion entries from a decoded reply, or ``None`` if the shape is wrong.

    Both the schema-shaped ``{"suggestions": [...]}`` and a bare top-level array are accepted:
    a model that drops the wrapper has still answered the question.
    """
    if isinstance(payload, dict):
        entries = payload.get("suggestions")
        return entries if isinstance(entries, list) else None
    if isinstance(payload, list):
        return payload
    return None


def _to_suggestion(entry: Any, allowed: set[str]) -> Suggestion | None:
    """Validate one reply entry. ``None`` for anything we would not act on."""
    if not isinstance(entry, dict):
        logger.debug("Stage-2 entry was not an object; discarding it.")
        return None

    index = entry.get("index")
    # `bool` is an `int` in Python, and `True` as an index would silently mean row 1.
    if not isinstance(index, int) or isinstance(index, bool) or index < 0:
        logger.debug("Stage-2 entry carried no usable index; discarding it.")
        return None

    category_id = entry.get("category_id")
    if not isinstance(category_id, str) or category_id not in allowed:
        logger.debug("Stage-2 entry named a category that was not offered; discarding it.")
        return None

    confidence = entry.get("confidence")
    if isinstance(confidence, bool) or not isinstance(confidence, int | float):
        logger.debug("Stage-2 entry carried a non-numeric confidence; discarding it.")
        return None
    if not 0.0 <= confidence <= 1.0:
        logger.debug("Stage-2 entry carried an out-of-range confidence; discarding it.")
        return None

    return Suggestion(index=index, category_id=category_id, confidence=float(confidence))
