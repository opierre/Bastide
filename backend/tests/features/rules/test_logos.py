"""Tests for rule logos: the upload round trip, and the logo each transaction and series shows."""

import io
from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import func, select

from app.features.imports.models import ImportBatch
from app.features.rules import logos as logos_module
from app.features.rules.logos import RuleLogoInvalidImageError, normalize_logo
from app.features.rules.models import RuleLogo
from app.features.transactions.models import Transaction
from tests.api import register_user
from tests.db import open_session

# EXIF tags a phone photo carries: camera make and the GPS sub-IFD.
_MAKE, _GPS_IFD = 0x010F, 0x8825


def _picture(fmt: str = "JPEG", *, exif: bool = False, colour: tuple[int, int, int] = (0, 0, 0)):
    image = Image.new("RGB", (300, 200), colour)
    output = io.BytesIO()
    if exif:
        tags = Image.Exif()
        tags[_MAKE] = "ACME Phone"
        tags.get_ifd(_GPS_IFD)[2] = (48.0, 51.0, 24.0)  # GPSLatitude
        image.save(output, format=fmt, exif=tags.tobytes())
    else:
        image.save(output, format=fmt)
    return output.getvalue()


class _Ledger:
    """One registered user with an account and a category, writing straight to the test DB."""

    def __init__(self, client: TestClient, tmp_path: Path, email: str = "amelie@example.com"):
        self.client = client
        self.db_path = tmp_path / "test.db"
        user = register_user(client, email)
        self.headers = user.headers
        self.user_id = user.user_id
        self.account_id = client.post(
            "/api/v1/accounts",
            json={
                "name": "Compte courant",
                "type": "checking",
                "institution": "Banque Exemple",
                "opening_balance_minor": 0,
            },
            headers=self.headers,
        ).json()["id"]
        self.category_id = client.post(
            "/api/v1/categories",
            json={"name": "Loisirs", "kind": "expense", "icon": "movie", "color": "#10B981"},
            headers=self.headers,
        ).json()["id"]

    def rule(self, pattern: str, priority: int = 1, *, enabled: bool = True) -> str:
        response = self.client.post(
            "/api/v1/rules",
            json={
                "priority": priority,
                "match_field": "description_clean",
                "match_type": "contains",
                "pattern": pattern,
                "category_id": self.category_id,
                "enabled": enabled,
            },
            headers=self.headers,
        )
        assert response.status_code == 201, response.json()
        return response.json()["id"]

    def upload(self, rule_id: str, data: bytes | None = None):
        return self.client.put(
            f"/api/v1/rules/{rule_id}/logo",
            headers=self.headers,
            files={"file": ("logo.jpg", data or _picture(), "image/jpeg")},
        )

    def transaction(self, description: str, booked: date = date(2026, 1, 15)) -> str:
        session = open_session(self.db_path)
        batch = ImportBatch(
            user_id=self.user_id,
            account_id=self.account_id,
            source_format="ofx",
            file_name="releve.ofx",
            file_hash=f"hash-{description}-{booked}",
            period_start=booked,
            period_end=booked,
            transaction_count=1,
            new_count=1,
            duplicate_count=0,
            status="success",
        )
        session.add(batch)
        session.flush()
        row = Transaction(
            account_id=self.account_id,
            import_batch_id=batch.id,
            booked_date=booked,
            amount_minor=-1_399,
            currency="EUR",
            description_raw=description,
            description_clean=description,
            categorization_source="uncategorized",
            needs_review=True,
            dedup_hash=f"dedup-{description}-{booked}",
        )
        session.add(row)
        session.commit()
        transaction_id = row.id
        session.close()
        return transaction_id

    def listed(self) -> dict[str, dict]:
        response = self.client.get("/api/v1/transactions", headers=self.headers)
        assert response.status_code == 200
        return {row["description_clean"]: row for row in response.json()["items"]}


@pytest.fixture
def ledger(client: TestClient, tmp_path: Path) -> _Ledger:
    return _Ledger(client, tmp_path)


# --- normalization -------------------------------------------------------------------------


def test_a_jpeg_with_exif_comes_back_as_a_square_png_without_metadata() -> None:
    with Image.open(io.BytesIO(normalize_logo(_picture(exif=True)))) as result:
        assert result.format == "PNG"
        assert result.size == (256, 256)
        assert len(result.getexif()) == 0
        assert "exif" not in result.info


_RED, _GREEN, _BLUE = (255, 0, 0), (0, 160, 0), (0, 0, 255)


def _banded(size: tuple[int, int], fmt: str = "PNG") -> bytes:
    """A picture whose two ends (left/right if wide, top/bottom if tall) are red and blue."""
    width, height = size
    image = Image.new("RGB", size, _GREEN)
    if width >= height:
        band = width // 10
        image.paste(_RED, (0, 0, band, height))
        image.paste(_BLUE, (width - band, 0, width, height))
    else:
        band = height // 10
        image.paste(_RED, (0, 0, width, band))
        image.paste(_BLUE, (0, height - band, width, height))
    output = io.BytesIO()
    image.save(output, format=fmt, quality=95)
    return output.getvalue()


def _pixels(data: bytes) -> Image.Image:
    with Image.open(io.BytesIO(data)) as result:
        assert (result.format, result.size) == ("PNG", (256, 256))
        return result.convert("RGBA")


def _close(pixel: object, colour: tuple[int, int, int]) -> bool:
    assert isinstance(pixel, tuple)
    channels = cast(tuple[int, int, int, int], pixel)
    return channels[3] == 255 and all(
        abs(a - b) < 40 for a, b in zip(channels[:3], colour, strict=False)
    )


def _transparent(pixel: object) -> bool:
    assert isinstance(pixel, tuple)
    return pixel[3] == 0


@pytest.mark.parametrize("fmt", ["PNG", "JPEG"])
def test_a_wide_logo_is_padded_whole_not_cropped(fmt: str) -> None:
    result = _pixels(normalize_logo(_banded((400, 100), fmt)))

    # Both ends survive, on a 256x64 strip centred between transparent bands.
    assert _close(result.getpixel((5, 128)), _RED)
    assert _close(result.getpixel((250, 128)), _BLUE)
    assert _close(result.getpixel((128, 128)), _GREEN)
    assert _transparent(result.getpixel((128, 10)))
    assert _transparent(result.getpixel((128, 245)))


def test_a_tall_logo_is_padded_whole_not_cropped() -> None:
    result = _pixels(normalize_logo(_banded((100, 400))))

    assert _close(result.getpixel((128, 5)), _RED)
    assert _close(result.getpixel((128, 250)), _BLUE)
    assert _transparent(result.getpixel((10, 128)))
    assert _transparent(result.getpixel((245, 128)))


def test_a_square_logo_fills_the_square_without_padding() -> None:
    result = _pixels(normalize_logo(_banded((300, 300))))

    assert _close(result.getpixel((5, 128)), _RED)
    assert _close(result.getpixel((250, 128)), _BLUE)
    assert _close(result.getpixel((128, 0)), _GREEN)
    alpha = result.getchannel("A")
    assert alpha.getextrema() == (255, 255)


def test_bytes_that_are_no_picture_are_refused() -> None:
    with pytest.raises(RuleLogoInvalidImageError):
        normalize_logo(b"not a picture")


# --- upload, fetch, delete -----------------------------------------------------------------


def test_upload_fetch_and_delete_round_trip(ledger: _Ledger) -> None:
    rule_id = ledger.rule("CINEMA")

    uploaded = ledger.upload(rule_id, _picture(exif=True))

    assert uploaded.status_code == 200
    stamp = uploaded.json()["logo_updated_at"]
    assert stamp is not None
    listed = ledger.client.get("/api/v1/rules", headers=ledger.headers).json()
    assert listed[0]["logo_updated_at"] == stamp

    fetched = ledger.client.get(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/png"
    with Image.open(io.BytesIO(fetched.content)) as image:
        assert image.format == "PNG"
        assert "exif" not in image.info

    cached = ledger.client.get(
        f"/api/v1/rules/{rule_id}/logo",
        headers={**ledger.headers, "If-None-Match": fetched.headers["etag"]},
    )
    assert cached.status_code == 304

    removed = ledger.client.delete(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)
    assert removed.status_code == 200
    assert removed.json()["logo_updated_at"] is None
    gone = ledger.client.get(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)
    assert gone.status_code == 404
    assert gone.json()["error"]["code"] == "RULE_LOGO_NOT_FOUND"


def test_a_replaced_logo_gets_a_new_etag(ledger: _Ledger) -> None:
    rule_id = ledger.rule("CINEMA")
    ledger.upload(rule_id, _picture(colour=(0, 0, 0)))
    first = ledger.client.get(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)

    ledger.upload(rule_id, _picture(colour=(255, 255, 255)))
    second = ledger.client.get(
        f"/api/v1/rules/{rule_id}/logo",
        headers={**ledger.headers, "If-None-Match": first.headers["etag"]},
    )

    assert second.status_code == 200
    assert second.content != first.content


def test_a_file_that_is_no_picture_is_refused_with_422(ledger: _Ledger) -> None:
    response = ledger.upload(ledger.rule("CINEMA"), b"plain text")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "RULE_LOGO_INVALID_IMAGE"


def test_a_too_large_upload_is_refused_with_413(
    ledger: _Ledger, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(logos_module, "MAX_UPLOAD_BYTES", 100)

    response = ledger.upload(ledger.rule("CINEMA"))

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "RULE_LOGO_TOO_LARGE"


def test_another_users_rule_logo_is_out_of_reach(
    ledger: _Ledger, client: TestClient, tmp_path: Path
) -> None:
    rule_id = ledger.rule("CINEMA")
    ledger.upload(rule_id)
    intruder = register_user(client, "bastien@example.com").headers

    assert client.get(f"/api/v1/rules/{rule_id}/logo", headers=intruder).status_code == 404
    upload = client.put(
        f"/api/v1/rules/{rule_id}/logo",
        headers=intruder,
        files={"file": ("logo.jpg", _picture(), "image/jpeg")},
    )
    assert upload.status_code == 404
    assert client.delete(f"/api/v1/rules/{rule_id}/logo", headers=intruder).status_code == 404


def test_deleting_a_rule_deletes_its_logo(ledger: _Ledger) -> None:
    rule_id = ledger.rule("CINEMA")
    ledger.upload(rule_id)

    assert (
        ledger.client.delete(f"/api/v1/rules/{rule_id}", headers=ledger.headers).status_code == 204
    )

    session = open_session(ledger.db_path)
    assert session.scalar(select(func.count()).select_from(RuleLogo)) == 0
    session.close()


# --- the logo a row shows ------------------------------------------------------------------


def test_a_transaction_matched_by_a_rule_with_a_logo_carries_its_reference(
    ledger: _Ledger,
) -> None:
    rule_id = ledger.rule("CINEMA")
    stamp = ledger.upload(rule_id).json()["logo_updated_at"]
    ledger.transaction("CINEMA LUMIERE")
    ledger.transaction("BOULANGERIE DU COIN")

    rows = ledger.listed()

    assert rows["CINEMA LUMIERE"]["logo_rule_id"] == rule_id
    assert rows["CINEMA LUMIERE"]["logo_updated_at"] == stamp
    assert rows["BOULANGERIE DU COIN"]["logo_rule_id"] is None
    assert rows["BOULANGERIE DU COIN"]["logo_updated_at"] is None


def test_a_rule_without_a_logo_leaves_the_monogram(ledger: _Ledger) -> None:
    ledger.rule("CINEMA")
    transaction_id = ledger.transaction("CINEMA LUMIERE")

    detail = ledger.client.get(f"/api/v1/transactions/{transaction_id}", headers=ledger.headers)

    assert detail.json()["logo_rule_id"] is None


def test_the_first_matching_rule_with_a_logo_wins_in_priority_order(ledger: _Ledger) -> None:
    ledger.rule("CINEMA", priority=1)  # matches first, but has no logo
    disabled = ledger.rule("LUMIERE", priority=2, enabled=False)
    second = ledger.rule("CINEMA LUM", priority=3)
    third = ledger.rule("LUMIERE", priority=4)
    for rule_id in (disabled, second, third):
        ledger.upload(rule_id)
    ledger.transaction("CINEMA LUMIERE")

    assert ledger.listed()["CINEMA LUMIERE"]["logo_rule_id"] == second


def test_a_series_shows_the_logo_its_latest_charge_matches(ledger: _Ledger) -> None:
    rule_id = ledger.rule("STREAMFLIX")
    ledger.upload(rule_id)
    charges = [
        ledger.transaction("STREAMFLIX", date(2026, 1, 5)),
        ledger.transaction("STREAMFLIX", date(2026, 2, 5)),
    ]

    created = ledger.client.post(
        "/api/v1/recurring",
        json={
            "label": "Streamflix",
            "account_id": ledger.account_id,
            "expected_amount_minor": -1_399,
            "cadence": "monthly",
            "transaction_ids": charges,
        },
        headers=ledger.headers,
    )

    assert created.status_code == 201, created.json()
    assert created.json()["logo_rule_id"] == rule_id
    listed = ledger.client.get("/api/v1/recurring", headers=ledger.headers).json()
    assert [series["logo_rule_id"] for series in listed] == [rule_id]
    detail = ledger.client.get(
        f"/api/v1/recurring/{created.json()['id']}", headers=ledger.headers
    ).json()
    assert detail["logo_rule_id"] == rule_id
    assert {o["transaction"]["logo_rule_id"] for o in detail["occurrences"]} == {rule_id}


# --- backup and reset ----------------------------------------------------------------------


def test_backup_and_restore_keep_the_logos(ledger: _Ledger) -> None:
    rule_id = ledger.rule("CINEMA")
    ledger.upload(rule_id)
    before = ledger.client.get(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers).content
    archive = ledger.client.post("/api/v1/backup/export", headers=ledger.headers).content
    ledger.client.delete(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)

    restored = ledger.client.post(
        "/api/v1/backup/restore",
        headers=ledger.headers,
        files={"file": ("sauvegarde.bastide", archive, "application/zip")},
    )

    assert restored.status_code == 200, restored.json()
    after = ledger.client.get(f"/api/v1/rules/{rule_id}/logo", headers=ledger.headers)
    assert after.status_code == 200
    assert after.content == before


def test_a_database_reset_deletes_the_logos(ledger: _Ledger) -> None:
    ledger.upload(ledger.rule("CINEMA"))

    response = ledger.client.post("/api/v1/database/reset", headers=ledger.headers)

    assert response.status_code == 200
    session = open_session(ledger.db_path)
    assert session.scalar(select(func.count()).select_from(RuleLogo)) == 0
    session.close()
