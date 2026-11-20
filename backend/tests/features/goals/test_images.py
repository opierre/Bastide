"""Tests for a goal's banner image: normalization, the upload round trip, backup and reset."""

import io
import zipfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import func, select

from app.features.goals import images as images_module
from app.features.goals.images import BANNER_SIZE, GoalImageInvalidError, normalize_banner
from app.features.goals.models import GoalImage
from tests.api import register
from tests.db import open_session
from tests.features.backup.test_backup import _drop_members
from tests.features.goals.test_goals import create_goal, list_goals

# EXIF tags a phone photo carries: camera make and the GPS sub-IFD.
_MAKE, _GPS_IFD = 0x010F, 0x8825


def _picture(
    fmt: str = "JPEG",
    size: tuple[int, int] = (600, 400),
    *,
    exif: bool = False,
    colour: tuple[int, int, int] = (0, 0, 0),
) -> bytes:
    image = Image.new("RGB", size, colour)
    output = io.BytesIO()
    if exif:
        tags = Image.Exif()
        tags[_MAKE] = "ACME Phone"
        tags.get_ifd(_GPS_IFD)[2] = (48.0, 51.0, 24.0)  # GPSLatitude
        image.save(output, format=fmt, exif=tags.tobytes())
    else:
        image.save(output, format=fmt)
    return output.getvalue()


def _upload(client: TestClient, headers: dict[str, str], goal_id: str, data: bytes | None = None):
    return client.put(
        f"/api/v1/goals/{goal_id}/image",
        headers=headers,
        files={"file": ("banniere.jpg", data or _picture(), "image/jpeg")},
    )


# --- normalization -------------------------------------------------------------------------


def test_a_jpeg_with_exif_comes_back_as_a_44_by_19_png_without_metadata() -> None:
    banner = normalize_banner(_picture(exif=True))

    with Image.open(io.BytesIO(banner)) as image:
        assert image.format == "PNG"
        assert image.size == BANNER_SIZE
        assert "exif" not in image.info


@pytest.mark.parametrize("size", [(400, 400), (200, 900), (3000, 500)])
def test_any_shape_is_cover_cropped_to_the_banner(size: tuple[int, int]) -> None:
    with Image.open(io.BytesIO(normalize_banner(_picture(size=size)))) as image:
        assert image.size == BANNER_SIZE


@pytest.mark.parametrize("fmt", ["PNG", "WEBP"])
def test_png_and_webp_are_accepted(fmt: str) -> None:
    with Image.open(io.BytesIO(normalize_banner(_picture(fmt)))) as image:
        assert image.format == "PNG"


def test_bytes_that_are_no_picture_are_refused() -> None:
    with pytest.raises(GoalImageInvalidError):
        normalize_banner(b"not a picture")


# --- upload, fetch, delete -----------------------------------------------------------------


def test_upload_fetch_and_delete_round_trip(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)
    assert goal["image_updated_at"] is None

    uploaded = _upload(client, headers, goal["id"], _picture(exif=True))

    assert uploaded.status_code == 200, uploaded.json()
    stamp = uploaded.json()["image_updated_at"]
    assert stamp is not None
    assert list_goals(client, headers)[0]["image_updated_at"] == stamp

    fetched = client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers)
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/png"
    with Image.open(io.BytesIO(fetched.content)) as image:
        assert image.size == BANNER_SIZE
        assert "exif" not in image.info

    cached = client.get(
        f"/api/v1/goals/{goal['id']}/image",
        headers={**headers, "If-None-Match": fetched.headers["etag"]},
    )
    assert cached.status_code == 304

    removed = client.delete(f"/api/v1/goals/{goal['id']}/image", headers=headers)
    assert removed.status_code == 200
    assert removed.json()["image_updated_at"] is None
    gone = client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers)
    assert gone.status_code == 404
    assert gone.json()["error"]["code"] == "GOAL_IMAGE_NOT_FOUND"


def test_removing_without_an_image_is_a_no_op(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)

    response = client.delete(f"/api/v1/goals/{goal['id']}/image", headers=headers)

    assert response.status_code == 200
    assert response.json()["image_updated_at"] is None


def test_a_replaced_image_gets_a_new_etag(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)
    _upload(client, headers, goal["id"], _picture(colour=(0, 0, 0)))
    first = client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers)

    _upload(client, headers, goal["id"], _picture(colour=(255, 255, 255)))
    second = client.get(
        f"/api/v1/goals/{goal['id']}/image",
        headers={**headers, "If-None-Match": first.headers["etag"]},
    )

    assert second.status_code == 200
    assert second.content != first.content


def test_a_file_that_is_no_picture_is_refused_with_422(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)

    response = _upload(client, headers, goal["id"], b"plain text")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "GOAL_IMAGE_INVALID_IMAGE"


def test_a_too_large_upload_is_refused_with_413(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(images_module, "MAX_UPLOAD_BYTES", 100)
    headers = register(client)
    goal = create_goal(client, headers)

    response = _upload(client, headers, goal["id"])

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "GOAL_IMAGE_TOO_LARGE"


def test_another_users_goal_image_is_out_of_reach(client: TestClient) -> None:
    headers = register(client, "amelie@example.com")
    goal = create_goal(client, headers)
    _upload(client, headers, goal["id"])
    intruder = register(client, "bastien@example.com")

    assert client.get(f"/api/v1/goals/{goal['id']}/image", headers=intruder).status_code == 404
    assert _upload(client, intruder, goal["id"]).status_code == 404
    assert client.delete(f"/api/v1/goals/{goal['id']}/image", headers=intruder).status_code == 404


def test_an_archived_goal_keeps_its_image(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)
    _upload(client, headers, goal["id"])

    client.patch(f"/api/v1/goals/{goal['id']}", json={"status": "archived"}, headers=headers)

    assert client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers).status_code == 200


def test_image_endpoints_require_auth(client: TestClient) -> None:
    goal_id = "00000000-0000-0000-0000-000000000000"
    assert client.get(f"/api/v1/goals/{goal_id}/image").status_code == 401
    assert client.delete(f"/api/v1/goals/{goal_id}/image").status_code == 401


# --- backup and reset ----------------------------------------------------------------------


def test_backup_and_restore_keep_the_image(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)
    _upload(client, headers, goal["id"])
    before = client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers).content
    archive = client.post("/api/v1/backup/export", headers=headers).content
    assert "goal_images.jsonl" in zipfile.ZipFile(io.BytesIO(archive)).namelist()
    client.delete(f"/api/v1/goals/{goal['id']}/image", headers=headers)

    restored = client.post(
        "/api/v1/backup/restore",
        headers=headers,
        files={"file": ("sauvegarde.bastide", archive, "application/zip")},
    )

    assert restored.status_code == 200, restored.json()
    after = client.get(f"/api/v1/goals/{goal['id']}/image", headers=headers)
    assert after.status_code == 200
    assert after.content == before


def test_a_version_7_archive_restores_without_images(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)
    _upload(client, headers, goal["id"])
    archive = client.post("/api/v1/backup/export", headers=headers).content
    older = _drop_members(archive, "goal_images.jsonl", format_version=7)

    restored = client.post(
        "/api/v1/backup/restore",
        headers=headers,
        files={"file": ("sauvegarde.bastide", older, "application/zip")},
    )

    assert restored.status_code == 200, restored.json()
    assert list_goals(client, headers)[0]["image_updated_at"] is None


def test_a_database_reset_deletes_the_images(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    _upload(client, headers, create_goal(client, headers)["id"])

    response = client.post("/api/v1/database/reset", headers=headers)

    assert response.status_code == 200
    session = open_session(tmp_path / "test.db")
    assert session.scalar(select(func.count()).select_from(GoalImage)) == 0
    session.close()
