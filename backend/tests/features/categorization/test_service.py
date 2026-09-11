"""Tests for the confidence-threshold decision service, with the inference client mocked.

No test here reaches a runtime: the client is a stub that replays a canned reply or raises.
"""

import asyncio
import json
from collections.abc import Coroutine, Sequence
from datetime import date
from typing import Any

import pytest

from app.features.categorization.prompt import PromptCategory
from app.features.categorization.schemas import SuggestionOutcome
from app.features.categorization.service import BATCH_SIZE, categorize_batch
from app.features.inference.client import (
    InferenceProtocolError,
    InferenceTimeout,
    InferenceUnavailable,
    Message,
)
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction

GROCERIES = PromptCategory(id="cat-groceries", name="Courses", kind="expense")
SALARY = PromptCategory(id="cat-salary", name="Salaire", kind="income")
CATEGORIES = [GROCERIES, SALARY]


def run[T](coro: Coroutine[Any, Any, T]) -> T:
    """Drive one coroutine to completion (avoids depending on an async pytest plugin)."""
    return asyncio.run(coro)


class StubClient:
    """An `InferenceClient` that replays one canned reply, or raises one canned error."""

    def __init__(self, content: str = "", error: Exception | None = None) -> None:
        self._content = content
        self._error = error
        self.calls: list[dict[str, Any]] = []

    async def list_models(self) -> list[str]:
        return ["stub-model"]

    async def complete(
        self,
        messages: Sequence[Message],
        *,
        model: str,
        response_format: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> str:
        self.calls.append({"messages": list(messages), "model": model})
        if self._error is not None:
            raise self._error
        return self._content


def _settings(threshold: float = 0.80, model_tag: str | None = "gemma-4-e4b") -> UserSettings:
    return UserSettings(
        user_id="user-1",
        ai_enabled=True,
        inference_base_url="http://127.0.0.1:11434/v1",
        model_tag=model_tag,
        confidence_threshold=threshold,
    )


def _transaction(
    description_clean: str = "CARREFOUR MARKET", amount_minor: int = -4235
) -> Transaction:
    return Transaction(
        account_id="account-1",
        import_batch_id="batch-1",
        booked_date=date(2026, 7, 11),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description_clean,
        description_clean=description_clean,
        merchant=None,
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash="hash-1",
    )


def _reply(*entries: dict[str, object]) -> str:
    return json.dumps({"suggestions": list(entries)})


def _categorize(
    rows: list[Transaction], client: StubClient, settings: UserSettings
) -> list[SuggestionOutcome]:
    return run(categorize_batch(rows, CATEGORIES, settings, client=client))


def test_confident_reply_assigns_with_confidence_and_no_review() -> None:
    client = StubClient(_reply({"index": 0, "category_id": "cat-groceries", "confidence": 0.93}))

    outcomes = _categorize([_transaction()], client, _settings())

    assert outcomes[0].status == "assigned"
    assert outcomes[0].category_id == "cat-groceries"
    assert outcomes[0].confidence == 0.93
    assert outcomes[0].needs_review is False


def test_confidence_exactly_at_threshold_assigns() -> None:
    client = StubClient(_reply({"index": 0, "category_id": "cat-groceries", "confidence": 0.80}))

    outcomes = _categorize([_transaction()], client, _settings(threshold=0.80))

    assert outcomes[0].status == "assigned"


def test_confidence_just_below_threshold_defers_with_no_category() -> None:
    client = StubClient(_reply({"index": 0, "category_id": "cat-groceries", "confidence": 0.79}))

    outcomes = _categorize([_transaction()], client, _settings(threshold=0.80))

    assert outcomes[0].status == "deferred"
    assert outcomes[0].category_id is None
    assert outcomes[0].confidence == 0.79
    assert outcomes[0].needs_review is True


def test_threshold_is_read_from_settings_not_hardcoded() -> None:
    reply = _reply({"index": 0, "category_id": "cat-groceries", "confidence": 0.55})

    lenient = _categorize([_transaction()], StubClient(reply), _settings(threshold=0.50))
    strict = _categorize([_transaction()], StubClient(reply), _settings(threshold=0.95))

    assert lenient[0].status == "assigned"
    assert strict[0].status == "deferred"


def test_model_tag_is_read_from_settings() -> None:
    client = StubClient(_reply({"index": 0, "category_id": "cat-salary", "confidence": 0.9}))

    _categorize([_transaction()], client, _settings(model_tag="some-other-model"))

    assert client.calls[0]["model"] == "some-other-model"


def test_no_configured_model_defers_without_calling_the_runtime() -> None:
    client = StubClient(_reply({"index": 0, "category_id": "cat-salary", "confidence": 0.9}))

    outcomes = _categorize([_transaction()], client, _settings(model_tag=None))

    assert client.calls == []
    assert [o.status for o in outcomes] == ["deferred"]


@pytest.mark.parametrize(
    "error",
    [
        pytest.param(InferenceUnavailable("nothing listening"), id="unavailable"),
        pytest.param(InferenceTimeout("too slow"), id="timeout"),
        pytest.param(InferenceProtocolError("bad status"), id="protocol"),
    ],
)
def test_runtime_error_fails_every_row_without_raising(error: Exception) -> None:
    client = StubClient(error=error)

    outcomes = _categorize([_transaction(), _transaction()], client, _settings())

    assert [o.status for o in outcomes] == ["failed", "failed"]
    assert all(o.category_id is None and o.needs_review for o in outcomes)


@pytest.mark.parametrize(
    "content",
    [
        pytest.param("I'm sorry, I can't help with that.", id="garbage"),
        pytest.param('{"suggestions": [{"index": 0, "category_id": "cat-sal', id="truncated"),
        pytest.param(
            _reply({"index": 0, "category_id": "cat-invented", "confidence": 0.99}),
            id="hallucinated-id",
        ),
        pytest.param(
            _reply({"index": 0, "category_id": "cat-groceries", "confidence": 4.2}),
            id="out-of-range",
        ),
    ],
)
def test_unusable_replies_defer_rather_than_raise(content: str) -> None:
    outcomes = _categorize([_transaction()], StubClient(content), _settings())

    assert [o.status for o in outcomes] == ["deferred"]
    assert outcomes[0].category_id is None


def test_fenced_reply_is_still_acted_on() -> None:
    content = (
        '```json\n{"suggestions": [{"index": 0, "category_id": "cat-groceries", '
        '"confidence": 0.9}]}\n```'
    )

    outcomes = _categorize([_transaction()], StubClient(content), _settings())

    assert outcomes[0].status == "assigned"


def test_mixed_batch_yields_the_right_outcome_per_row() -> None:
    rows = [_transaction() for _ in range(4)]
    client = StubClient(
        _reply(
            {"index": 0, "category_id": "cat-groceries", "confidence": 0.95},
            {"index": 1, "category_id": "cat-salary", "confidence": 0.42},
            {"index": 2, "category_id": "cat-invented", "confidence": 0.99},
            # Row 3 is simply never answered.
        )
    )

    outcomes = _categorize(rows, client, _settings(threshold=0.80))

    assert [o.status for o in outcomes] == ["assigned", "deferred", "deferred", "deferred"]
    assert [o.index for o in outcomes] == [0, 1, 2, 3]
    assert outcomes[0].category_id == "cat-groceries"
    assert outcomes[1].confidence == 0.42
    assert outcomes[2].confidence is None


def test_outcomes_are_returned_one_per_row_in_input_order() -> None:
    rows = [_transaction() for _ in range(3)]
    client = StubClient(
        _reply(
            {"index": 2, "category_id": "cat-salary", "confidence": 0.9},
            {"index": 0, "category_id": "cat-groceries", "confidence": 0.9},
        )
    )

    outcomes = _categorize(rows, client, _settings())

    assert [o.index for o in outcomes] == [0, 1, 2]
    assert [o.status for o in outcomes] == ["assigned", "deferred", "assigned"]


def test_empty_batch_returns_nothing_and_calls_nothing() -> None:
    client = StubClient()

    outcomes = _categorize([], client, _settings())

    assert outcomes == []
    assert client.calls == []


def test_batch_size_is_a_tunable_constant() -> None:
    assert BATCH_SIZE == 20
