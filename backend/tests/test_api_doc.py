"""The committed endpoint reference must match the app's routes."""

from app.main import create_app
from scripts.api_doc import OUTPUT, render


def test_docs_api_md_matches_the_openapi_schema() -> None:
    expected = render(create_app().openapi())
    assert OUTPUT.read_text(encoding="utf-8") == expected, (
        "docs/api.md is stale: run `uv run python -m scripts.api_doc` from backend/"
    )
