"""Tests for `/tax/parameters/{year}` — resolution, overrides and reset (§4c, §5c, §16).

What is at stake: the set a user reads is the set the estimate runs on; a barème is replaced whole
or not at all; the seeded set defines which keys exist; a reset gives back exactly the seeded
figures; and nothing a user does can reach a system row, another user's overrides, or another year.
"""

import io
import json
import zipfile
from datetime import date
from pathlib import Path
from typing import Any, cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.auth.models import User
from app.features.tax.models import TaxBracket, TaxParameter
from app.features.tax.parameters import (
    ResolvedBracket,
    TaxBracketsInvalidError,
    TaxParameterOutOfRangeError,
    TaxParameterUnknownError,
    check_brackets,
    check_parameter,
)
from app.features.tax.router import get_today as tax_today
from app.features.tax.seed import SYSTEM_TAX_SEED

TODAY = date(2026, 5, 15)
YEAR = SYSTEM_TAX_SEED.tax_year
NEXT_YEAR = YEAR + 1
URL = f"/api/v1/tax/parameters/{YEAR}"


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[tax_today] = lambda: TODAY


@pytest.fixture(autouse=True)
def seeded_parameters(tmp_path: Path) -> None:
    """The seed's system rows for two years, so per-year isolation has two real sets to compare."""
    with db(tmp_path) as session:
        for year in (YEAR, NEXT_YEAR):
            for kind, bands in SYSTEM_TAX_SEED.brackets.items():
                for ordinal, band in enumerate(bands):
                    session.add(
                        TaxBracket(
                            user_id=None,
                            tax_year=year,
                            kind=kind,
                            ordinal=ordinal,
                            lower_bound_minor=band.lower_bound_minor,
                            rate_bps=band.rate_bps,
                        )
                    )
            for key, parameter in SYSTEM_TAX_SEED.parameters.items():
                session.add(
                    TaxParameter(
                        user_id=None,
                        tax_year=year,
                        key=key,
                        int_value=parameter.int_value,
                        unit=parameter.unit,
                    )
                )
        session.commit()


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    assert response.status_code == 201, response.json()
    return {"Authorization": f"Bearer {response.json()['token']}"}


def seeded_view() -> dict[str, Any]:
    """The response a user with no overrides gets, built straight from the seed."""
    return {
        "brackets": {
            kind: [
                {"lower_bound_minor": band.lower_bound_minor, "rate_bps": band.rate_bps}
                for band in bands
            ]
            for kind, bands in sorted(SYSTEM_TAX_SEED.brackets.items())
        },
        "parameters": {
            key: {"int_value": parameter.int_value, "unit": parameter.unit}
            for key, parameter in sorted(SYSTEM_TAX_SEED.parameters.items())
        },
        "overridden": {"keys": [], "bracket_kinds": []},
    }


def read(client: TestClient, headers: dict[str, str], year: int = YEAR) -> dict[str, Any]:
    response = client.get(f"/api/v1/tax/parameters/{year}", headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def patch(client: TestClient, headers: dict[str, str], payload: dict[str, Any]) -> dict[str, Any]:
    response = client.patch(URL, json=payload, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def bands(*pairs: tuple[int, int]) -> list[dict[str, int]]:
    return [{"lower_bound_minor": floor, "rate_bps": rate} for floor, rate in pairs]


def user_rows(tmp_path: Path) -> tuple[list[tuple[Any, ...]], list[tuple[Any, ...]]]:
    """Every user-owned parameter and bracket row, to prove what a refused write did not do."""
    with db(tmp_path) as session:
        parameters = session.execute(
            select(TaxParameter.tax_year, TaxParameter.key, TaxParameter.int_value)
            .where(TaxParameter.user_id.is_not(None))
            .order_by(TaxParameter.tax_year, TaxParameter.key)
        ).all()
        brackets = session.execute(
            select(TaxBracket.tax_year, TaxBracket.kind, TaxBracket.ordinal, TaxBracket.rate_bps)
            .where(TaxBracket.user_id.is_not(None))
            .order_by(TaxBracket.tax_year, TaxBracket.kind, TaxBracket.ordinal)
        ).all()
    return [tuple(row) for row in parameters], [tuple(row) for row in brackets]


def system_rows(tmp_path: Path) -> tuple[list[tuple[Any, ...]], list[tuple[Any, ...]]]:
    with db(tmp_path) as session:
        parameters = session.execute(
            select(TaxParameter.id, TaxParameter.int_value, TaxParameter.unit)
            .where(TaxParameter.user_id.is_(None))
            .order_by(TaxParameter.id)
        ).all()
        brackets = session.execute(
            select(TaxBracket.id, TaxBracket.lower_bound_minor, TaxBracket.rate_bps)
            .where(TaxBracket.user_id.is_(None))
            .order_by(TaxBracket.id)
        ).all()
    return [tuple(row) for row in parameters], [tuple(row) for row in brackets]


# --- Resolution ------------------------------------------------------------------------------


def test_with_no_overrides_the_resolved_set_is_the_seeded_set(client: TestClient) -> None:
    headers = register(client)

    assert read(client, headers) == seeded_view()


def test_some_keys_overridden_are_named_and_the_rest_stay_seeded(client: TestClient) -> None:
    """A user who changes one key has said nothing about any other."""
    headers = register(client)

    body = patch(client, headers, {"parameters": {"pfu_income_tax_bps": 1300}})

    expected = seeded_view()
    expected["parameters"]["pfu_income_tax_bps"]["int_value"] = 1300
    expected["overridden"] = {"keys": ["pfu_income_tax_bps"], "bracket_kinds": []}
    assert body == expected
    assert read(client, headers) == expected


def test_all_keys_and_both_kinds_overridden(client: TestClient) -> None:
    headers = register(client)
    raised = {key: parameter.int_value + 1 for key, parameter in SYSTEM_TAX_SEED.parameters.items()}

    body = patch(
        client,
        headers,
        {
            "parameters": raised,
            "brackets": {"ir": bands((0, 0), (1_000_000, 2000)), "ifi": bands((0, 100))},
        },
    )

    assert {key: value["int_value"] for key, value in body["parameters"].items()} == raised
    assert body["brackets"] == {
        "ifi": bands((0, 100)),
        "ir": bands((0, 0), (1_000_000, 2000)),
    }
    assert body["overridden"] == {"keys": sorted(raised), "bracket_kinds": ["ifi", "ir"]}


def test_an_override_keeps_the_unit_of_the_key_it_shadows(client: TestClient) -> None:
    headers = register(client)

    body = patch(client, headers, {"parameters": {"micro_foncier_ceiling_minor": 2_000_000}})

    assert body["parameters"]["micro_foncier_ceiling_minor"] == {
        "int_value": 2_000_000,
        "unit": "minor",
    }


def test_patching_a_key_twice_updates_the_users_one_row(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    patch(client, headers, {"parameters": {"pfu_income_tax_bps": 1300}})

    patch(client, headers, {"parameters": {"pfu_income_tax_bps": 1400}})

    assert user_rows(tmp_path)[0] == [(YEAR, "pfu_income_tax_bps", 1400)]


# --- Wholesale bracket replacement -----------------------------------------------------------


def test_a_bracket_kind_is_replaced_wholesale(client: TestClient, tmp_path: Path) -> None:
    """A shorter set leaves no seeded band behind it, and a second set no band of the first."""
    headers = register(client)

    first = patch(
        client, headers, {"brackets": {"ir": bands((0, 0), (1_000_000, 1500), (5_000_000, 4000))}}
    )
    assert first["brackets"]["ir"] == bands((0, 0), (1_000_000, 1500), (5_000_000, 4000))
    # The other kind was not submitted, so it keeps the seeded set.
    assert first["brackets"]["ifi"] == seeded_view()["brackets"]["ifi"]
    assert first["overridden"]["bracket_kinds"] == ["ir"]

    second = patch(client, headers, {"brackets": {"ir": bands((0, 1000), (2_000_000, 3000))}})

    assert second["brackets"]["ir"] == bands((0, 1000), (2_000_000, 3000))
    assert user_rows(tmp_path)[1] == [(YEAR, "ir", 0, 1000), (YEAR, "ir", 1, 3000)]


INVALID_SETS = {
    "empty": [],
    "descending": bands((0, 0), (3_000_000, 3000), (1_000_000, 1100)),
    "gapped": bands((500_000, 0), (1_000_000, 1100)),
    "overlapping": bands((0, 0), (1_000_000, 1100), (1_000_000, 3000)),
    "rate_above_100_percent": bands((0, 0), (1_000_000, 10_001)),
    "negative_rate": bands((0, -100)),
}


@pytest.mark.parametrize("bad_set", INVALID_SETS.values(), ids=INVALID_SETS.keys())
def test_an_invalid_set_is_refused_whole_and_nothing_is_written(
    client: TestClient, tmp_path: Path, bad_set: list[dict[str, int]]
) -> None:
    """Refused with the valid scalar beside it: a partially applied payload is not an option."""
    headers = register(client)
    patch(client, headers, {"brackets": {"ifi": bands((0, 100))}})
    before = user_rows(tmp_path)

    response = client.patch(
        URL,
        json={"parameters": {"pfu_income_tax_bps": 1300}, "brackets": {"ir": bad_set}},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "TAX_BRACKETS_INVALID"
    assert user_rows(tmp_path) == before


NON_INTEGER_BANDS = {
    "float_rate": [{"lower_bound_minor": 0, "rate_bps": 11.5}],
    "integral_float_rate": [{"lower_bound_minor": 0, "rate_bps": 1100.0}],
    "string_floor": [{"lower_bound_minor": "0", "rate_bps": 0}],
    "missing_rate": [{"lower_bound_minor": 0}],
}


@pytest.mark.parametrize("bad_set", NON_INTEGER_BANDS.values(), ids=NON_INTEGER_BANDS.keys())
def test_a_band_that_is_not_integer_bps_is_refused(
    client: TestClient, tmp_path: Path, bad_set: list[dict[str, Any]]
) -> None:
    headers = register(client)

    response = client.patch(URL, json={"brackets": {"ir": bad_set}}, headers=headers)

    assert response.status_code == 422
    assert user_rows(tmp_path) == ([], [])


def test_an_unknown_bracket_kind_is_refused(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    response = client.patch(URL, json={"brackets": {"csg": bands((0, 920))}}, headers=headers)

    assert response.status_code == 422
    assert user_rows(tmp_path) == ([], [])


@pytest.mark.parametrize(
    ("bad_set", "reason"),
    [
        ([], "empty"),
        ([ResolvedBracket(100, 0)], "not_from_zero"),
        ([ResolvedBracket(0, 0), ResolvedBracket(0, 1100)], "not_ascending"),
        ([ResolvedBracket(0, 0), ResolvedBracket(10, 0), ResolvedBracket(5, 0)], "not_ascending"),
        ([ResolvedBracket(0, 10_001)], "rate_out_of_range"),
    ],
)
def test_check_brackets_names_the_rule_a_set_breaks(
    bad_set: list[ResolvedBracket], reason: str
) -> None:
    with pytest.raises(TaxBracketsInvalidError) as refused:
        check_brackets("ir", bad_set)

    assert refused.value.details is not None
    assert (refused.value.details["kind"], refused.value.details["reason"]) == ("ir", reason)


def test_check_brackets_accepts_a_single_band_from_zero() -> None:
    check_brackets("ifi", [ResolvedBracket(0, 0)])


# --- Scalar validation -----------------------------------------------------------------------


def test_an_unknown_key_is_refused_and_never_created(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    response = client.patch(
        URL,
        json={"parameters": {"pfu_income_tax_bps": 1300, "flat_tax_bps": 3000}},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "TAX_PARAMETER_UNKNOWN"
    assert response.json()["error"]["details"] == {"key": "flat_tax_bps"}
    assert user_rows(tmp_path) == ([], [])


OUT_OF_RANGE = {
    "bps_above_100_percent": ("pfu_income_tax_bps", 10_001),
    "bps_negative": ("decote_rate_bps", -1),
    "minor_negative": ("micro_foncier_ceiling_minor", -1),
}


@pytest.mark.parametrize(("key", "value"), OUT_OF_RANGE.values(), ids=OUT_OF_RANGE.keys())
def test_a_value_outside_its_units_range_is_refused(
    client: TestClient, tmp_path: Path, key: str, value: int
) -> None:
    headers = register(client)

    response = client.patch(URL, json={"parameters": {key: value}}, headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "TAX_PARAMETER_OUT_OF_RANGE"
    assert user_rows(tmp_path) == ([], [])


@pytest.mark.parametrize(
    ("key", "value"),
    [("pfu_income_tax_bps", 0), ("pfu_income_tax_bps", 10_000), ("ifi_threshold_minor", 0)],
)
def test_the_bounds_of_a_units_range_are_accepted(client: TestClient, key: str, value: int) -> None:
    headers = register(client)

    assert (
        patch(client, headers, {"parameters": {key: value}})["parameters"][key]["int_value"]
        == value
    )


def test_a_non_integer_value_is_refused(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    response = client.patch(URL, json={"parameters": {"pfu_income_tax_bps": 12.8}}, headers=headers)

    assert response.status_code == 422
    assert user_rows(tmp_path) == ([], [])


@pytest.mark.parametrize(
    ("unit", "value", "refused"),
    [
        ("bps", 10_001, True),
        ("bps", -1, True),
        ("minor", -1, True),
        ("minor", 10**12, False),
        ("count", -1, True),
        ("count", 0, False),
    ],
)
def test_check_parameter_applies_the_range_of_each_unit(
    unit: str, value: int, refused: bool
) -> None:
    """`count` has no seeded key yet, so its rule is held here rather than through the route."""
    units = {"some_key": unit}
    if refused:
        with pytest.raises(TaxParameterOutOfRangeError):
            check_parameter("some_key", value, units)
    else:
        assert check_parameter("some_key", value, units) == unit


def test_check_parameter_refuses_a_key_the_seed_does_not_hold() -> None:
    with pytest.raises(TaxParameterUnknownError):
        check_parameter("unknown_bps", 0, {"pfu_income_tax_bps": "bps"})


# --- Reset -----------------------------------------------------------------------------------


def test_a_whole_year_reset_restores_the_seeded_set_exactly(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    patch(
        client,
        headers,
        {
            "parameters": {"pfu_income_tax_bps": 1300, "micro_foncier_ceiling_minor": 2_000_000},
            "brackets": {"ir": bands((0, 500)), "ifi": bands((0, 100))},
        },
    )

    response = client.delete(URL, headers=headers)

    assert response.status_code == 200
    assert response.json() == seeded_view()
    assert read(client, headers) == seeded_view()
    assert user_rows(tmp_path) == ([], [])


def test_a_key_reset_drops_only_that_key(client: TestClient) -> None:
    headers = register(client)
    patch(
        client,
        headers,
        {
            "parameters": {"pfu_income_tax_bps": 1300, "decote_rate_bps": 5000},
            "brackets": {"ir": bands((0, 500))},
        },
    )

    response = client.delete(URL, params={"key": "pfu_income_tax_bps"}, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["parameters"]["pfu_income_tax_bps"]["int_value"] == 1280
    assert body["parameters"]["decote_rate_bps"]["int_value"] == 5000
    assert body["overridden"] == {"keys": ["decote_rate_bps"], "bracket_kinds": ["ir"]}


def test_a_kind_reset_drops_only_that_barème(client: TestClient) -> None:
    headers = register(client)
    patch(
        client,
        headers,
        {
            "parameters": {"pfu_income_tax_bps": 1300},
            "brackets": {"ir": bands((0, 500)), "ifi": bands((0, 100))},
        },
    )

    response = client.delete(URL, params={"kind": "ir"}, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["brackets"]["ir"] == seeded_view()["brackets"]["ir"]
    assert body["brackets"]["ifi"] == bands((0, 100))
    assert body["overridden"] == {"keys": ["pfu_income_tax_bps"], "bracket_kinds": ["ifi"]}


def test_resetting_an_unknown_key_or_kind_is_refused(client: TestClient) -> None:
    headers = register(client)

    unknown_key = client.delete(URL, params={"key": "flat_tax_bps"}, headers=headers)
    unknown_kind = client.delete(URL, params={"kind": "csg"}, headers=headers)

    assert unknown_key.status_code == 422
    assert unknown_key.json()["error"]["code"] == "TAX_PARAMETER_UNKNOWN"
    assert unknown_kind.status_code == 422


# --- Isolation -------------------------------------------------------------------------------


def test_overrides_for_one_year_do_not_affect_another(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    patch(
        client,
        headers,
        {"parameters": {"pfu_income_tax_bps": 1300}, "brackets": {"ir": bands((0, 500))}},
    )

    assert read(client, headers, NEXT_YEAR) == seeded_view()

    # Nor does resetting the other year reach this one.
    assert client.delete(f"/api/v1/tax/parameters/{NEXT_YEAR}", headers=headers).status_code == 200
    assert read(client, headers)["overridden"] == {
        "keys": ["pfu_income_tax_bps"],
        "bracket_kinds": ["ir"],
    }


def test_another_users_overrides_are_invisible_and_untouchable(
    client: TestClient, tmp_path: Path
) -> None:
    amelie = register(client)
    patch(client, amelie, {"parameters": {"pfu_income_tax_bps": 1300}})
    bruno = register(client, "bruno@example.com")

    assert read(client, bruno) == seeded_view()
    assert client.delete(URL, headers=bruno).status_code == 200

    assert read(client, amelie)["parameters"]["pfu_income_tax_bps"]["int_value"] == 1300


def test_no_write_or_reset_ever_touches_a_system_row(client: TestClient, tmp_path: Path) -> None:
    """PATCH shadows a seeded row with the caller's own; DELETE drops only the caller's rows."""
    headers = register(client)
    before = system_rows(tmp_path)

    patch(
        client,
        headers,
        {
            "parameters": {key: 0 for key in SYSTEM_TAX_SEED.parameters},
            "brackets": {"ir": bands((0, 0)), "ifi": bands((0, 0))},
        },
    )
    assert system_rows(tmp_path) == before
    with db(tmp_path) as session:
        owner = session.scalar(select(User.id).where(User.email == "amelie@example.com"))
        owners = set(
            session.scalars(select(TaxParameter.user_id).where(TaxParameter.tax_year == YEAR))
        )
    assert owners == {None, owner}

    assert client.delete(URL, headers=headers).status_code == 200
    assert system_rows(tmp_path) == before


def test_a_year_outside_the_estimable_range_is_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.get(f"/api/v1/tax/parameters/{TODAY.year + 1}", headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "TAX_YEAR_OUT_OF_RANGE"


def test_the_parameters_require_authentication(client: TestClient) -> None:
    for response in (
        client.get(URL),
        client.patch(URL, json={"parameters": {"pfu_income_tax_bps": 1300}}),
        client.delete(URL),
    ):
        assert response.status_code == 401
        assert response.json()["error"]["code"]


# --- The estimate and the backup -------------------------------------------------------------


def test_the_estimate_follows_an_override_immediately(client: TestClient) -> None:
    """The estimate reads the same resolution, so a write moves it and a reset moves it back."""
    headers = register(client)
    response = client.patch(
        f"/api/v1/tax/profiles/{YEAR}", json={"dividends_minor": 1_000_000}, headers=headers
    )
    assert response.status_code == 200, response.json()

    def estimate() -> dict[str, Any]:
        response = client.get(f"/api/v1/tax/profiles/{YEAR}/estimate", headers=headers)
        assert response.status_code == 200, response.json()
        return response.json()

    seeded = estimate()
    assert (seeded["parameter_source"], seeded["pfu"]["income_tax_minor"]) == ("seeded", 128_000)

    patch(client, headers, {"parameters": {"pfu_income_tax_bps": 2560}})
    overridden = estimate()
    assert overridden["parameter_source"] == "overridden"
    assert overridden["pfu"]["income_tax_minor"] == 256_000

    assert client.delete(URL, headers=headers).status_code == 200
    assert estimate() == seeded


def test_overrides_survive_a_backup_and_restore_round_trip(client: TestClient) -> None:
    """A user who tuned their parameters and restored a backup must not get the seeded set back."""
    headers = register(client)
    tuned = patch(
        client,
        headers,
        {
            "parameters": {"pfu_income_tax_bps": 1300},
            "brackets": {"ir": bands((0, 0), (1_000_000, 2000))},
        },
    )
    export = client.post("/api/v1/backup/export", headers=headers)
    assert export.status_code == 200
    archive = zipfile.ZipFile(io.BytesIO(export.content))
    manifest = json.loads(archive.read("manifest.json"))
    assert (manifest["tables"]["tax_parameters"], manifest["tables"]["tax_brackets"]) == (1, 2)

    assert client.delete(URL, headers=headers).status_code == 200
    assert read(client, headers) == seeded_view()

    restored = client.post(
        "/api/v1/backup/restore",
        headers=headers,
        files={"file": ("sauvegarde.finstride", export.content, "application/zip")},
    )

    assert restored.status_code == 200, restored.json()
    assert read(client, headers) == tuned
