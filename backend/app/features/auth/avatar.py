"""Turn an uploaded picture into the avatar the app stores: a square 256×256 PNG."""

from http import HTTPStatus

from app.core import images
from app.core.errors import ValidationError

AVATAR_SIZE = 256
AVATAR_CONTENT_TYPE = images.PNG_CONTENT_TYPE
MAX_UPLOAD_BYTES = images.MAX_UPLOAD_BYTES
MAX_PIXELS = images.MAX_PIXELS
ACCEPTED_FORMATS = images.ACCEPTED_FORMATS


class AvatarTooLargeError(ValidationError):
    """Raised when an uploaded picture is over `MAX_UPLOAD_BYTES` or `MAX_PIXELS`."""

    code = "AVATAR_TOO_LARGE"
    status_code = HTTPStatus.REQUEST_ENTITY_TOO_LARGE


class AvatarInvalidImageError(ValidationError):
    """Raised when an upload isn't a PNG, JPEG or WebP picture that decodes."""

    code = "AVATAR_INVALID_IMAGE"


def normalize_avatar(data: bytes) -> bytes:
    """Decode an uploaded picture, crop it to its centre square and re-encode it as a PNG.

    Raises:
        AvatarTooLargeError: the file or its pixel count is over the limit.
        AvatarInvalidImageError: the bytes aren't a PNG, JPEG or WebP picture.
    """
    return images.square_png(
        data,
        AVATAR_SIZE,
        too_large=_too_large,
        invalid=_invalid,
        max_bytes=MAX_UPLOAD_BYTES,
        max_pixels=MAX_PIXELS,
    )


def _too_large() -> AvatarTooLargeError:
    return AvatarTooLargeError(
        "The picture is too large.",
        details={"max_bytes": MAX_UPLOAD_BYTES, "max_pixels": MAX_PIXELS},
    )


def _invalid() -> AvatarInvalidImageError:
    return AvatarInvalidImageError(
        "The file is not a PNG, JPEG or WebP picture.",
        details={"accepted": sorted(ACCEPTED_FORMATS)},
    )
