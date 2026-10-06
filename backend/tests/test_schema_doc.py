"""The committed schema reference must match what the migrations build."""

from pathlib import Path

from sqlalchemy import create_engine

from scripts.schema_doc import OUTPUT, render


def test_docs_database_md_matches_the_migrated_schema(migrated_template: Path) -> None:
    engine = create_engine(f"sqlite:///{migrated_template}")
    try:
        expected = render(engine)
    finally:
        engine.dispose()
    assert OUTPUT.read_text(encoding="utf-8") == expected, (
        "docs/database.md is stale: run `uv run python -m scripts.schema_doc` from backend/"
    )
