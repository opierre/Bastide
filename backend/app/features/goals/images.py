"""Turn an uploaded picture into the banner a goal stores: a 44:19 PNG."""

from http import HTTPStatus

from app.core import images
from app.core.errors import NotFoundError, ValidationError

#: Twice the inspector's 440 px width, at the banner's 44:19 ratio (`docs/design/11-goals.md`).
BANNER_SIZE = (880, 380)
BANNER_CONTENT_TYPE = images.PNG_CONTENT_TYPE
MAX_UPLOAD_BYTES = images.MAX_UPLOAD_BYTES
MAX_PIXELS = images.MAX_PIXELS


class GoalImageTooLargeError(ValidationError):
    """Raised when an uploaded picture is over `MAX_UPLOAD_BYTES` or `MAX_PIXELS`."""

    code = "GOAL_IMAGE_TOO_LARGE"
    status_code = HTTPStatus.REQUEST_ENTITY_TOO_LARGE


class GoalImageInvalidError(ValidationError):
    """Raised when an upload isn't a PNG, JPEG or WebP picture that decodes."""

    code = "GOAL_IMAGE_INVALID_IMAGE"


class GoalImageNotFoundError(NotFoundError):
    """Raised when a goal has no banner image."""

    code = "GOAL_IMAGE_NOT_FOUND"


def normalize_banner(data: bytes) -> bytes:
    """Decode an uploaded picture, cover-crop it to 44:19 and re-encode it as a PNG.

    The app already crops to that ratio before uploading; the centre crop here only keeps a
    picture from another client to the shape the banner draws.

    Raises:
        GoalImageTooLargeError: the file or its pixel count is over the limit.
        GoalImageInvalidError: the bytes aren't a PNG, JPEG or WebP picture.
    """
    return images.fitted_png(
        data,
        BANNER_SIZE,
        too_large=lambda: GoalImageTooLargeError(
            "The picture is too large.",
            details={"max_bytes": MAX_UPLOAD_BYTES, "max_pixels": MAX_PIXELS},
        ),
        invalid=lambda: GoalImageInvalidError(
            "The file is not a PNG, JPEG or WebP picture.",
            details={"accepted": sorted(images.ACCEPTED_FORMATS)},
        ),
        max_bytes=MAX_UPLOAD_BYTES,
        max_pixels=MAX_PIXELS,
    )
