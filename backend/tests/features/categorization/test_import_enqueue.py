"""Tests for the run an import enqueues — and, more importantly, for when it enqueues none.

The load-bearing assertion in this file is the negative one: with AI switched off, an import
must be indistinguishable from the Phase 1 import that predates the model entirely.
"""

from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.core.db import SessionFactory
from app.features.inference.client import InferenceUnavailable
from tests.features.categorization.conftest import (
    GROCERIES_ID,
    RunLauncherSpy,
    StubRuntime,
    assign_all,
    read_transaction,
    seed_categories,
)

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"
RUNS = "/api/v1/categorization/runs"

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}


def _register(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "amelie@example.com",
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    return {"Authorization": f"Bearer {response.json()['token']}"}


def _create_account(client: TestClient, headers: dict[str, str]) -> str:
    return client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()["id"]


def _enable_ai(client: TestClient, headers: dict[str, str]) -> None:
    client.patch(
        "/api/v1/settings",
        json={"ai_enabled": True, "model_tag": "stub-model"},
        headers=headers,
    )


def _upload(
    client: TestClient,
    headers: dict[str, str],
    account_id: str,
    filename: str = "sample_sgml.ofx",
) -> httpx.Response:
    with (FIXTURES / filename).open("rb") as handle:
        return client.post(
            "/api/v1/imports",
            headers=headers,
            data={"account_id": account_id},
            files={"file": (filename, handle, "application/octet-stream")},
        )


def _uncategorized_ids(client: TestClient, headers: dict[str, str]) -> list[str]:
    rows = client.get("/api/v1/transactions", headers=headers).json()["items"]
    return [row["id"] for row in rows if row["categorization_source"] == "uncategorized"]


def test_ai_disabled_creates_no_run_and_leaves_the_import_response_unchanged(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    response = _upload(client, headers, account_id)

    assert response.status_code == 201
    assert response.json()["status"] == "success"
    assert response.json()["new_count"] == 2
    # Do nothing at all: no run row, no scheduled executor, no runtime contact.
    assert client.get(RUNS, headers=headers).json() == []
    assert launcher.pending == []
    assert runtime.calls == []


def test_ai_enabled_enqueues_a_run_carrying_the_trigger_and_the_batch_id(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)

    imported = _upload(client, headers, account_id)

    assert imported.status_code == 201
    runs = client.get(RUNS, headers=headers).json()
    assert len(runs) == 1
    assert runs[0]["trigger"] == "import"
    assert runs[0]["import_batch_id"] == imported.json()["id"]
    assert runs[0]["account_id"] == account_id
    assert runs[0]["status"] == "pending"
    # The import returned without waiting for a single token.
    assert runtime.calls == []
    launcher.discard()


def test_the_enqueued_run_categorizes_the_rows_the_import_left_for_review(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)
    seed_categories(api_session_factory)
    _upload(client, headers, account_id)
    pending_ids = _uncategorized_ids(client, headers)
    runtime.default = assign_all(len(pending_ids))

    assert launcher.drain() == 1

    run = client.get(RUNS, headers=headers).json()[0]
    assert run["status"] == "success"
    assert run["assigned_count"] == len(pending_ids)
    row = read_transaction(api_session_factory, pending_ids[0])
    assert row.categorization_source == "model"
    assert row.category_id == GROCERIES_ID
    assert row.needs_review is False


def test_an_import_still_succeeds_when_the_runtime_is_down_and_the_run_ends_failed(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)
    runtime.default = InferenceUnavailable("nothing is listening on 11434")

    imported = _upload(client, headers, account_id)
    pending_ids = _uncategorized_ids(client, headers)
    launcher.drain()

    # The import is untouched by the runtime's absence — that is the whole point.
    assert imported.status_code == 201
    assert imported.json()["status"] == "success"
    assert imported.json()["new_count"] == 2

    run = client.get(RUNS, headers=headers).json()[0]
    assert run["status"] == "failed"
    assert run["error_message"] is not None
    assert run["assigned_count"] == 0
    # And the rows stay exactly where rules left them: in the review queue.
    assert read_transaction(api_session_factory, pending_ids[0]).needs_review is True


def test_a_failed_import_enqueues_nothing(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)

    response = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": account_id},
        files={"file": ("broken.ofx", b"this is not an OFX file", "application/octet-stream")},
    )

    assert response.json()["status"] == "failed"
    assert client.get(RUNS, headers=headers).json() == []
    assert launcher.pending == []


def test_re_importing_an_identical_file_enqueues_nothing_new(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    """The second upload is a no-op that returns the first batch; a run would have no rows."""
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)
    first = _upload(client, headers, account_id)
    launcher.discard()

    second = _upload(client, headers, account_id)

    assert second.json()["id"] == first.json()["id"]
    assert len(client.get(RUNS, headers=headers).json()) == 1
    assert launcher.pending == []


def test_a_second_import_while_a_run_is_in_flight_does_not_start_a_second_run(
    client: TestClient, launcher: RunLauncherSpy, runtime: StubRuntime
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _enable_ai(client, headers)
    _upload(client, headers, account_id)

    second = _upload(client, headers, account_id, filename="sample_sgml_later_month.ofx")

    assert second.status_code == 201
    assert len(client.get(RUNS, headers=headers).json()) == 1
    assert len(launcher.pending) == 1
    launcher.discard()
