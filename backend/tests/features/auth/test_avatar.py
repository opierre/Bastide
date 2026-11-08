"""Tests for the user's avatar: the default choice, an uploaded picture, and its normalization."""

import io
from datetime import UTC, datetime
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.features.auth import avatar as avatar_module
from app.features.auth.avatar import (
    AvatarInvalidImageError,
    AvatarTooLargeError,
    normalize_avatar,
)
from app.features.auth.models import User, UserAvatar
from app.features.auth.service import AuthService
from tests.api import register

AVATAR_URL = "/api/v1/auth/me/avatar"
CHOICE_URL = "/api/v1/auth/me/avatar-choice"

# EXIF tags a phone photo carries: camera make, orientation, and the GPS sub-IFD.
_MAKE, _ORIENTATION, _GPS_IFD = 0x010F, 0x0112, 0x8825


def _picture(fmt: str = "JPEG", size: tuple[int, int] = (400, 300), *, exif: bool = False) -> bytes:
    image = Image.new("RGB", size, (79, 70, 229))
    output = io.BytesIO()
    if exif:
        tags = Image.Exif()
        tags[_MAKE] = "ACME Phone"
        tags[_ORIENTATION] = 1
        tags.get_ifd(_GPS_IFD)[2] = (48.0, 51.0, 24.0)  # GPSLatitude
        image.save(output, format=fmt, exif=tags.tobytes())
    else:
        image.save(output, format=fmt)
    return output.getvalue()


def _upload(client: TestClient, headers: dict[str, str], data: bytes, name: str = "me.jpg"):
    return client.put(AVATAR_URL, headers=headers, files={"file": (name, data, "image/jpeg")})


# --- normalization -------------------------------------------------------------------------


def test_a_jpeg_with_exif_comes_back_as_a_square_png_without_metadata() -> None:
    source = _picture(exif=True)
    with Image.open(io.BytesIO(source)) as original:
        assert original.getexif()[_MAKE] == "ACME Phone"

    with Image.open(io.BytesIO(normalize_avatar(source))) as result:
        assert result.format == "PNG"
        assert result.size == (256, 256)
        assert len(result.getexif()) == 0
        assert "exif" not in result.info


def test_a_wide_avatar_is_still_cropped_to_its_centre() -> None:
    image = Image.new("RGB", (400, 100), (0, 160, 0))
    image.paste((255, 0, 0), (0, 0, 40, 100))  # a red left end the centre crop drops
    output = io.BytesIO()
    image.save(output, format="PNG")

    with Image.open(io.BytesIO(normalize_avatar(output.getvalue()))) as result:
        rgba = result.convert("RGBA")
    assert rgba.getchannel("A").getextrema() == (255, 255)  # no padding
    edge = rgba.getpixel((2, 128))
    assert isinstance(edge, tuple) and edge[0] < 50  # the red end is gone


@pytest.mark.parametrize("fmt", ["PNG", "WEBP"])
def test_png_and_webp_are_accepted(fmt: str) -> None:
    with Image.open(io.BytesIO(normalize_avatar(_picture(fmt)))) as result:
        assert result.format == "PNG"


def test_the_orientation_tag_is_applied_before_it_is_dropped() -> None:
    image = Image.new("RGB", (200, 100), (0, 0, 0))
    image.paste((255, 255, 255), (0, 0, 100, 100))  # left half white
    tags = Image.Exif()
    tags[_ORIENTATION] = 6  # rotate 90° clockwise to display
    output = io.BytesIO()
    image.save(output, format="JPEG", exif=tags.tobytes(), quality=95)

    with Image.open(io.BytesIO(normalize_avatar(output.getvalue()))) as result:
        # Upright, the white half is on top; the centre crop keeps both halves.
        top, bottom = result.getpixel((128, 10)), result.getpixel((128, 245))
    assert isinstance(top, tuple) and isinstance(bottom, tuple)
    assert top[0] > 200 > 50 > bottom[0]


def test_a_gif_is_refused() -> None:
    with pytest.raises(AvatarInvalidImageError):
        normalize_avatar(_picture("GIF"))


def test_bytes_that_are_no_picture_are_refused() -> None:
    with pytest.raises(AvatarInvalidImageError):
        normalize_avatar(b"not a picture at all")


def test_a_file_over_the_byte_cap_is_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(avatar_module, "MAX_UPLOAD_BYTES", 100)
    with pytest.raises(AvatarTooLargeError):
        normalize_avatar(_picture())


def test_a_picture_over_the_pixel_cap_is_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(avatar_module, "MAX_PIXELS", 1000)
    with pytest.raises(AvatarTooLargeError):
        normalize_avatar(_picture(size=(40, 40)))


# --- service -------------------------------------------------------------------------------


def _user(avatar: str) -> User:
    return User(id="user-1", avatar=avatar)


def test_uploading_remembers_the_default_it_replaces() -> None:
    repository = Mock()
    service = AuthService(repository, clock=lambda: datetime(2026, 3, 1, tzinfo=UTC))

    service.upload_avatar(_user("preset:blue"), _picture())

    saved = repository.save_avatar.call_args.args[1]
    assert saved.previous_choice == "preset:blue"
    assert saved.content_type == "image/png"
    assert saved.updated_at == datetime(2026, 3, 1, tzinfo=UTC)


def test_replacing_a_picture_keeps_the_monogram_as_fallback_not_image() -> None:
    repository = Mock()

    AuthService(repository).upload_avatar(_user("image"), _picture())

    assert repository.save_avatar.call_args.args[1].previous_choice == "monogram"


def test_removing_without_a_picture_changes_nothing() -> None:
    repository = Mock()
    repository.get_avatar.return_value = None
    user = _user("preset:lime")

    assert AuthService(repository).remove_avatar(user) is user
    repository.set_avatar_choice.assert_not_called()


def test_removing_a_picture_brings_back_the_previous_default() -> None:
    repository = Mock()
    repository.get_avatar.return_value = UserAvatar(previous_choice="preset:green")
    user = _user("image")

    AuthService(repository).remove_avatar(user)

    repository.set_avatar_choice.assert_called_once_with(user, "preset:green")


# --- API -----------------------------------------------------------------------------------


def test_a_new_user_has_the_monogram_and_no_picture(client: TestClient) -> None:
    headers = register(client)

    assert client.get("/api/v1/auth/me", headers=headers).json()["user"]["avatar"] == "monogram"
    response = client.get(AVATAR_URL, headers=headers)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "AVATAR_NOT_FOUND"


def test_upload_fetch_and_delete_round_trip(client: TestClient) -> None:
    headers = register(client)
    client.put(CHOICE_URL, headers=headers, json={"avatar": "preset:cyan"})

    uploaded = _upload(client, headers, _picture(exif=True))
    assert uploaded.status_code == 200
    assert uploaded.json()["user"]["avatar"] == "image"

    fetched = client.get(AVATAR_URL, headers=headers)
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/png"
    with Image.open(io.BytesIO(fetched.content)) as result:
        assert result.size == (256, 256)
        assert len(result.getexif()) == 0

    removed = client.delete(AVATAR_URL, headers=headers)
    assert removed.status_code == 200
    assert removed.json()["user"]["avatar"] == "preset:cyan"
    assert client.get(AVATAR_URL, headers=headers).status_code == 404


def test_a_matching_etag_gets_304_and_a_new_picture_a_new_etag(client: TestClient) -> None:
    headers = register(client)
    _upload(client, headers, _picture())
    etag = client.get(AVATAR_URL, headers=headers).headers["etag"]

    cached = client.get(AVATAR_URL, headers={**headers, "If-None-Match": etag})
    assert cached.status_code == 304
    assert cached.content == b""

    _upload(client, headers, _picture("PNG"))
    assert client.get(AVATAR_URL, headers=headers).headers["etag"] != etag


def test_choosing_a_preset_drops_the_picture(client: TestClient) -> None:
    headers = register(client)
    _upload(client, headers, _picture())

    response = client.put(CHOICE_URL, headers=headers, json={"avatar": "preset:pink"})

    assert response.json()["user"]["avatar"] == "preset:pink"
    assert client.get(AVATAR_URL, headers=headers).status_code == 404
    # Nothing left to remove: the preset stays.
    assert client.delete(AVATAR_URL, headers=headers).json()["user"]["avatar"] == "preset:pink"


@pytest.mark.parametrize("choice", ["image", "preset:unknown", "preset:", "cyan", ""])
def test_an_unknown_choice_is_refused(client: TestClient, choice: str) -> None:
    headers = register(client)

    assert client.put(CHOICE_URL, headers=headers, json={"avatar": choice}).status_code == 422


def test_a_wrong_type_upload_is_refused_and_keeps_the_avatar(client: TestClient) -> None:
    headers = register(client)
    _upload(client, headers, _picture())
    before = client.get(AVATAR_URL, headers=headers).content

    response = _upload(client, headers, _picture("GIF"), name="me.gif")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "AVATAR_INVALID_IMAGE"
    assert client.get(AVATAR_URL, headers=headers).content == before


def test_a_too_large_upload_is_refused_with_413(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers = register(client)
    monkeypatch.setattr(avatar_module, "MAX_UPLOAD_BYTES", 100)

    response = _upload(client, headers, _picture())

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "AVATAR_TOO_LARGE"
    assert client.get("/api/v1/auth/me", headers=headers).json()["user"]["avatar"] == "monogram"


def test_a_user_only_ever_gets_their_own_picture(client: TestClient) -> None:
    amelie = register(client)
    bastien = register(client, email="bastien@example.com")
    _upload(client, amelie, _picture())

    assert client.get(AVATAR_URL, headers=bastien).status_code == 404


def test_a_database_reset_leaves_the_avatar_in_place(client: TestClient) -> None:
    headers = register(client)
    _upload(client, headers, _picture())
    before = client.get(AVATAR_URL, headers=headers).content

    assert client.post("/api/v1/database/reset", headers=headers).status_code == 200

    assert client.get("/api/v1/auth/me", headers=headers).json()["user"]["avatar"] == "image"
    assert client.get(AVATAR_URL, headers=headers).content == before


def test_avatar_endpoints_require_auth(client: TestClient) -> None:
    assert client.get(AVATAR_URL).status_code == 401
    assert client.put(AVATAR_URL, files={"file": ("a.png", b"x", "image/png")}).status_code == 401
    assert client.delete(AVATAR_URL).status_code == 401
    assert client.put(CHOICE_URL, json={"avatar": "monogram"}).status_code == 401
