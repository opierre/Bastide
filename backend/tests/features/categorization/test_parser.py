"""Tests for the defensive suggestion parser.

The single property under test everywhere below: **nothing raises**. Every malformed reply a
small model can produce must come back as a deferral, because a run that crashes on a bad reply
is worse than a run that hands the row to the user (`PROJECT.md` §7).
"""

import json

import pytest

from app.features.categorization.parser import parse_reply

VALID_IDS = ["cat-groceries", "cat-salary"]


def _reply(*entries: dict[str, object]) -> str:
    return json.dumps({"suggestions": list(entries)})


def test_well_formed_reply_parses() -> None:
    content = _reply(
        {"index": 0, "category_id": "cat-groceries", "confidence": 0.93},
        {"index": 1, "category_id": "cat-salary", "confidence": 0.5},
    )

    result = parse_reply(content, VALID_IDS)

    assert result.discarded == 0
    assert [(s.index, s.category_id, s.confidence) for s in result.suggestions] == [
        (0, "cat-groceries", 0.93),
        (1, "cat-salary", 0.5),
    ]


def test_bare_top_level_array_parses() -> None:
    content = json.dumps([{"index": 0, "category_id": "cat-salary", "confidence": 1.0}])

    result = parse_reply(content, VALID_IDS)

    assert [s.index for s in result.suggestions] == [0]


@pytest.mark.parametrize(
    "content",
    [
        pytest.param(
            '```json\n{"suggestions": [{"index": 0, "category_id": "cat-salary", '
            '"confidence": 0.9}]}\n```',
            id="json-fence",
        ),
        pytest.param(
            '```\n{"suggestions": [{"index": 0, "category_id": "cat-salary", '
            '"confidence": 0.9}]}\n```',
            id="bare-fence",
        ),
        pytest.param(
            'Sure! Here are the categories:\n{"suggestions": [{"index": 0, '
            '"category_id": "cat-salary", "confidence": 0.9}]}\nHope that helps.',
            id="surrounding-prose",
        ),
    ],
)
def test_wrapped_json_still_parses(content: str) -> None:
    result = parse_reply(content, VALID_IDS)

    assert [s.category_id for s in result.suggestions] == ["cat-salary"]


@pytest.mark.parametrize(
    "content",
    [
        pytest.param("", id="empty"),
        pytest.param("I'm sorry, I can't help with that.", id="prose-only"),
        pytest.param("<<<garbage>>>", id="garbage"),
        pytest.param('{"suggestions": [{"index": 0, "category_id": "cat-sal', id="truncated"),
        pytest.param('{"suggestions": {"index": 0}}', id="suggestions-not-a-list"),
        pytest.param('{"results": []}', id="wrong-key"),
        pytest.param("42", id="json-scalar"),
        pytest.param('"a string"', id="json-string"),
    ],
)
def test_unusable_replies_defer_without_raising(content: str) -> None:
    result = parse_reply(content, VALID_IDS)

    assert result.suggestions == []


@pytest.mark.parametrize(
    "entry",
    [
        pytest.param("not an object", id="entry-not-an-object"),
        pytest.param({"category_id": "cat-salary", "confidence": 0.9}, id="missing-index"),
        pytest.param(
            {"index": "0", "category_id": "cat-salary", "confidence": 0.9}, id="index-not-an-int"
        ),
        pytest.param(
            {"index": True, "category_id": "cat-salary", "confidence": 0.9}, id="index-is-a-bool"
        ),
        pytest.param(
            {"index": -1, "category_id": "cat-salary", "confidence": 0.9}, id="negative-index"
        ),
        pytest.param({"index": 0, "confidence": 0.9}, id="missing-category-id"),
        pytest.param(
            {"index": 0, "category_id": "cat-hallucinated", "confidence": 0.9},
            id="hallucinated-category-id",
        ),
        pytest.param(
            {"index": 0, "category_id": 17, "confidence": 0.9}, id="category-id-not-a-string"
        ),
        pytest.param({"index": 0, "category_id": "cat-salary"}, id="missing-confidence"),
        pytest.param(
            {"index": 0, "category_id": "cat-salary", "confidence": "high"},
            id="confidence-not-numeric",
        ),
        pytest.param(
            {"index": 0, "category_id": "cat-salary", "confidence": None},
            id="confidence-is-null",
        ),
        pytest.param(
            {"index": 0, "category_id": "cat-salary", "confidence": True},
            id="confidence-is-a-bool",
        ),
        pytest.param(
            {"index": 0, "category_id": "cat-salary", "confidence": 1.7},
            id="confidence-above-one",
        ),
        pytest.param(
            {"index": 0, "category_id": "cat-salary", "confidence": -0.2},
            id="confidence-below-zero",
        ),
    ],
)
def test_malformed_entries_are_discarded_not_raised(entry: object) -> None:
    result = parse_reply(json.dumps({"suggestions": [entry]}), VALID_IDS)

    assert result.suggestions == []
    assert result.discarded == 1


def test_duplicate_index_keeps_the_first_and_discards_the_rest() -> None:
    content = _reply(
        {"index": 0, "category_id": "cat-groceries", "confidence": 0.9},
        {"index": 0, "category_id": "cat-salary", "confidence": 0.8},
    )

    result = parse_reply(content, VALID_IDS)

    assert [(s.index, s.category_id) for s in result.suggestions] == [(0, "cat-groceries")]
    assert result.discarded == 1


def test_good_entries_survive_alongside_bad_ones() -> None:
    content = _reply(
        {"index": 0, "category_id": "cat-groceries", "confidence": 0.9},
        {"index": 1, "category_id": "cat-hallucinated", "confidence": 0.9},
        {"index": 2, "category_id": "cat-salary", "confidence": 0.4},
    )

    result = parse_reply(content, VALID_IDS)

    assert [s.index for s in result.suggestions] == [0, 2]
    assert result.discarded == 1


def test_confidence_bounds_are_inclusive() -> None:
    content = _reply(
        {"index": 0, "category_id": "cat-groceries", "confidence": 0},
        {"index": 1, "category_id": "cat-salary", "confidence": 1},
    )

    result = parse_reply(content, VALID_IDS)

    assert [s.confidence for s in result.suggestions] == [0.0, 1.0]
