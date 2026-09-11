"""Builds the stage-2 categorisation prompt: category list, few-shot set, and the batch rows.

Token discipline and privacy pull the same way here, so the prompt carries the *minimum* a
model needs to pick a category: the cleaned label, the merchant, the amount's sign and its
absolute value. `description_raw`, `memo`, account ids and user ids are deliberately never
rendered — they cost tokens, they help the model none, and they are the fields we least want
leaving the row's own process boundary (`PROJECT.md` §3, local-first).

Rows are correlated with the reply by their **index in the batch**, never by transaction id:
sending UUIDs buys nothing the model can use and invites it to invent one.
"""

import json
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from typing import Any

from app.core.seed import SYSTEM_CATEGORIES, CategorySeed
from app.features.categories.models import Category
from app.features.inference.client import Message
from app.features.transactions.models import Transaction

# Name of the structured-output schema handed to the runtime. Runtimes that honour
# `response_format` constrain generation to it; the parser assumes nothing either way.
REPLY_SCHEMA_NAME = "categorization_suggestions"


@dataclass(frozen=True)
class PromptCategory:
    """One selectable category, as the prompt offers it: id, localized name, kind.

    ``name`` is already localized — system categories store an i18n key in the database
    (`PROJECT.md` §4), so resolving it needs a locale the pure decision layer does not
    carry. `leaf_categories` does that resolution for the caller.
    """

    id: str
    name: str
    kind: str


@dataclass(frozen=True)
class FewShotExample:
    """One worked example: a row as the model will see it, and the answer we want back."""

    description_clean: str
    merchant: str | None
    amount_minor: int
    category_name: str
    kind: str


# French *and* English examples, because a French user's statement routinely mixes both and a
# small multilingual model anchors hard on the language it was shown. Categories here are named,
# not id'd: the ids differ per user, and a fabricated id in the few-shot set is exactly the
# hallucination the index-based reply shape exists to avoid.
FEW_SHOT_EXAMPLES: tuple[FewShotExample, ...] = (
    FewShotExample("CARREFOUR MARKET PARIS 11", "Carrefour", -4235, "Courses", "expense"),
    FewShotExample("VIREMENT SALAIRE JUILLET", None, 285000, "Salaire", "income"),
    FewShotExample("SNCF CONNECT BILLET TGV", "SNCF", -6900, "Transports en commun", "expense"),
    FewShotExample("NETFLIX.COM MONTHLY", "Netflix", -1399, "Subscriptions", "expense"),
    FewShotExample("SHELL SERVICE STATION", "Shell", -7250, "Fuel", "expense"),
)

_SYSTEM_INSTRUCTIONS = (
    "You categorise bank transactions. Statements are French or English; the categories are "
    "given in the user's language. For every numbered row, pick exactly one category id from "
    "the list and rate your confidence between 0 and 1. Never invent a category id. Never omit "
    "a row. If a row is genuinely ambiguous, still answer, but with a low confidence — a low "
    "score is more useful than a wrong guess dressed up as a certain one. Reply with JSON only: "
    'an object {"suggestions": [...]}, one entry per row, correlated by the row number.'
)

# Localized system-category names by i18n key, from the seed catalog — the documented source of
# truth for those translations (`app/core/seed.py`), which persists only the key.
_SYSTEM_NAMES: dict[str, dict[str, str]] = {}


def _index_seed(seeds: Iterable[CategorySeed]) -> None:
    for seed in seeds:
        _SYSTEM_NAMES[seed.key] = {"fr": seed.name_fr, "en": seed.name_en}
        _index_seed(seed.children)


_index_seed(SYSTEM_CATEGORIES)


def leaf_categories(categories: Sequence[Category], locale: str) -> list[PromptCategory]:
    """Return the leaf categories of ``categories``, localized and reduced to prompt fields.

    Only leaves are offered. A parent whose children are also on the list is never the right
    answer — offering both doubles the plausible choices for no gain in precision, and a small
    model handed "Food" next to "Groceries" splits its probability mass between them.

    Args:
        categories: the user's visible categories, system and user-defined alike.
        locale: ``fr`` or ``en``; anything else falls back to the stored name.
    """
    parent_ids = {category.parent_id for category in categories if category.parent_id is not None}
    return [
        PromptCategory(id=category.id, name=_localized_name(category, locale), kind=category.kind)
        for category in categories
        if category.id not in parent_ids
    ]


def build_messages(
    rows: Sequence[Transaction], categories: Sequence[PromptCategory]
) -> list[Message]:
    """Build the chat messages for one batch.

    The category list and the few-shot set are fixed cost per request; the rows are the
    variable part. That is the whole economic argument for batching (see ``BATCH_SIZE`` in
    ``service.py``): the fixed part is paid once for the whole batch.
    """
    return [
        {"role": "system", "content": _SYSTEM_INSTRUCTIONS},
        {"role": "user", "content": _render_user_content(rows, categories)},
    ]


def build_response_format() -> dict[str, Any]:
    """Return the `response_format` asking the runtime to constrain output to the reply shape.

    Requested, never relied on: support varies by runtime and build, so the parser treats
    anything unusable as a deferral regardless (`PROJECT.md` §7).
    """
    return {
        "type": "json_schema",
        "json_schema": {
            "name": REPLY_SCHEMA_NAME,
            "strict": True,
            "schema": REPLY_JSON_SCHEMA,
        },
    }


REPLY_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "suggestions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "index": {"type": "integer"},
                    "category_id": {"type": "string"},
                    "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                },
                "required": ["index", "category_id", "confidence"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["suggestions"],
    "additionalProperties": False,
}


def _localized_name(category: Category, locale: str) -> str:
    """Resolve a category's display name for ``locale``.

    User categories store free text and are returned as-is; system categories store an i18n
    key, resolved against the seed catalog.
    """
    names = _SYSTEM_NAMES.get(category.name)
    if names is None:
        return category.name
    return names.get(locale, category.name)


def _render_user_content(rows: Sequence[Transaction], categories: Sequence[PromptCategory]) -> str:
    """Render the category list, the examples, and the numbered rows as one user message."""
    sections = [
        "Categories (id | name | kind):",
        "\n".join(f"{c.id} | {c.name} | {c.kind}" for c in categories),
        "",
        "Examples:",
        "\n".join(_render_example(example) for example in FEW_SHOT_EXAMPLES),
        "",
        "Rows to categorise:",
        "\n".join(_render_row(index, row) for index, row in enumerate(rows)),
        "",
        f"Answer with JSON matching this schema:\n{json.dumps(REPLY_JSON_SCHEMA)}",
    ]
    return "\n".join(sections)


def _render_example(example: FewShotExample) -> str:
    return (
        f"- {_render_fields(example.description_clean, example.merchant, example.amount_minor)}"
        f" -> {example.category_name} ({example.kind})"
    )


def _render_row(index: int, row: Transaction) -> str:
    """Render one transaction as the four fields the model is allowed to see."""
    return f"{index}. {_render_fields(row.description_clean, row.merchant, row.amount_minor)}"


def _render_fields(description_clean: str, merchant: str | None, amount_minor: int) -> str:
    """Render a row's visible fields: label, merchant, direction, magnitude.

    The signed minor-unit amount is split into a direction word and its absolute value: the
    sign is the part that carries categorisation signal (`PROJECT.md` §8), and a bare "-4235"
    invites a small model to reason about the minus rather than about the merchant.
    """
    direction = "in" if amount_minor >= 0 else "out"
    parts = [f'label="{description_clean}"']
    if merchant:
        parts.append(f'merchant="{merchant}"')
    parts.append(f"direction={direction}")
    parts.append(f"amount={abs(amount_minor)}")
    return " ".join(parts)
