"""Tests for the stage-2 prompt builder: what it offers, and what it must never leak."""

from datetime import date

from app.features.categories.models import Category
from app.features.categorization.prompt import (
    FEW_SHOT_EXAMPLES,
    REPLY_SCHEMA_NAME,
    PromptCategory,
    build_messages,
    build_response_format,
    leaf_categories,
)
from app.features.transactions.models import Transaction

GROCERIES = PromptCategory(id="cat-groceries", name="Courses", kind="expense")
SALARY = PromptCategory(id="cat-salary", name="Salaire", kind="income")
CATEGORIES = [GROCERIES, SALARY]


def _category(
    id_: str,
    name: str,
    kind: str = "expense",
    parent_id: str | None = None,
    is_system: bool = True,
) -> Category:
    return Category(
        id=id_,
        user_id=None if is_system else "user-1",
        parent_id=parent_id,
        name=name,
        kind=kind,
        icon="category",
        color="#64748B",
        is_system=is_system,
    )


def _transaction(
    description_clean: str = "CARREFOUR MARKET",
    merchant: str | None = "Carrefour",
    amount_minor: int = -4235,
    description_raw: str = "CB CARREFOUR MARKET 11/07 CARTE 4321",
    memo: str | None = "REF 998877",
) -> Transaction:
    return Transaction(
        id="txn-1",
        account_id="account-secret-1",
        import_batch_id="batch-1",
        booked_date=date(2026, 7, 11),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description_raw,
        description_clean=description_clean,
        memo=memo,
        merchant=merchant,
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash="hash-1",
    )


def _user_content(rows: list[Transaction], categories: list[PromptCategory]) -> str:
    messages = build_messages(rows, categories)
    return next(message["content"] for message in messages if message["role"] == "user")


def test_category_list_is_offered_with_id_name_and_kind() -> None:
    content = _user_content([_transaction()], CATEGORIES)

    assert "cat-groceries | Courses | expense" in content
    assert "cat-salary | Salaire | income" in content


def test_few_shot_examples_are_present_in_both_languages() -> None:
    content = _user_content([_transaction()], CATEGORIES)

    for example in FEW_SHOT_EXAMPLES:
        assert example.description_clean in content
        assert example.category_name in content
    # The set must anchor both languages: a French-only set makes the model answer French
    # rows well and English ones badly, and a real statement mixes the two.
    assert "VIREMENT SALAIRE JUILLET" in content
    assert "NETFLIX.COM MONTHLY" in content


def test_french_and_english_rows_both_render() -> None:
    rows = [
        _transaction(
            description_clean="VIREMENT SALAIRE JUILLET", merchant=None, amount_minor=285000
        ),
        _transaction(
            description_clean="AMAZON MARKETPLACE UK", merchant="Amazon", amount_minor=-2199
        ),
    ]

    content = _user_content(rows, CATEGORIES)

    assert "0. " in content
    assert "1. " in content
    assert "VIREMENT SALAIRE JUILLET" in content
    assert "AMAZON MARKETPLACE UK" in content


def test_rows_are_numbered_by_index_not_transaction_id() -> None:
    content = _user_content([_transaction(), _transaction()], CATEGORIES)

    assert "0. " in content
    assert "1. " in content
    assert "txn-1" not in content


def test_excluded_fields_are_absent_from_the_prompt() -> None:
    row = _transaction()

    content = _user_content([row], CATEGORIES)

    assert row.description_raw not in content
    assert "REF 998877" not in content
    assert "account-secret-1" not in content
    assert "batch-1" not in content
    assert "hash-1" not in content


def test_amount_renders_as_direction_and_absolute_value() -> None:
    outflow = _user_content([_transaction(amount_minor=-4235)], CATEGORIES)
    inflow = _user_content([_transaction(amount_minor=285000)], CATEGORIES)

    assert "direction=out amount=4235" in outflow
    assert "-4235" not in outflow
    assert "direction=in amount=285000" in inflow


def test_missing_merchant_is_omitted_rather_than_rendered_empty() -> None:
    content = _user_content([_transaction(merchant=None)], CATEGORIES)

    assert 'merchant=""' not in content
    assert "merchant=None" not in content


def test_leaf_categories_drops_parents_and_localizes_system_keys() -> None:
    categories = [
        _category("cat-food", "category.food"),
        _category("cat-groceries", "category.food.groceries", parent_id="cat-food"),
        _category("cat-subscriptions", "category.subscriptions"),
    ]

    french = leaf_categories(categories, "fr")
    english = leaf_categories(categories, "en")

    assert [c.id for c in french] == ["cat-groceries", "cat-subscriptions"]
    assert [c.name for c in french] == ["Courses", "Abonnements"]
    assert [c.name for c in english] == ["Groceries", "Subscriptions"]


def test_leaf_categories_passes_user_category_names_through_untouched() -> None:
    categories = [_category("cat-boat", "Bateau", is_system=False)]

    assert leaf_categories(categories, "en")[0].name == "Bateau"


def test_response_format_requests_the_reply_schema() -> None:
    response_format = build_response_format()

    assert response_format["type"] == "json_schema"
    assert response_format["json_schema"]["name"] == REPLY_SCHEMA_NAME
    properties = response_format["json_schema"]["schema"]["properties"]["suggestions"]["items"]
    assert set(properties["required"]) == {"index", "category_id", "confidence"}
