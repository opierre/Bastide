"""Turn an uploaded picture into the avatar the app stores: a square 256×256 PNG.

Decoding and re-encoding the pixels, rather than keeping the uploaded bytes, is what drops
every piece of metadata a photo carries (EXIF, GPS position, camera serial, ICC comments):
only the pixels are written back.
"""

import io
import warnings
from http import HTTPStatus

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.errors import ValidationError

AVATAR_SIZE = 256
AVATAR_CONTENT_TYPE = "image/png"
#: Largest upload accepted, in bytes. Phone photos sit well under it.
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
#: Largest picture decoded, in pixels: guards against a small file that inflates hugely.
MAX_PIXELS = 50_000_000
ACCEPTED_FORMATS = frozenset({"PNG", "JPEG", "WEBP"})


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
    if len(data) > MAX_UPLOAD_BYTES:
        raise _too_large()
    try:
        with warnings.catch_warnings():
            # Pillow only warns between its limit and twice it; ours is the one that counts.
            warnings.simplefilter("ignore", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in ACCEPTED_FORMATS:
                    raise _invalid()
                if image.width * image.height > MAX_PIXELS:
                    raise _too_large()
                # A phone photo is often stored sideways with an orientation tag: apply it
                # before the tag goes, or the avatar comes out rotated.
                upright = ImageOps.exif_transpose(image)
                square = ImageOps.fit(
                    upright.convert("RGBA"),
                    (AVATAR_SIZE, AVATAR_SIZE),
                    method=Image.Resampling.LANCZOS,
                )
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError, ValueError) as exc:
        raise _invalid() from exc

    output = io.BytesIO()
    square.save(output, format="PNG", optimize=True)
    return output.getvalue()


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
