"""Turn an uploaded picture into the square PNG the app stores (avatars, rule logos).

Decoding and re-encoding the pixels, rather than keeping the uploaded bytes, is what drops
every piece of metadata a photo carries (EXIF, GPS position, camera serial, ICC comments):
only the pixels are written back.
"""

import io
import warnings
from collections.abc import Callable
from typing import Literal

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.errors import DomainError

PNG_CONTENT_TYPE = "image/png"
#: Largest upload accepted, in bytes. Phone photos sit well under it.
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
#: Largest picture decoded, in pixels: guards against a small file that inflates hugely.
MAX_PIXELS = 50_000_000
ACCEPTED_FORMATS = frozenset({"PNG", "JPEG", "WEBP"})

#: How a picture that is not square becomes one: cropped to its centre, or padded.
type Fit = Literal["crop", "pad"]


def square_png(
    data: bytes,
    size: int,
    *,
    too_large: Callable[[], DomainError],
    invalid: Callable[[], DomainError],
    max_bytes: int = MAX_UPLOAD_BYTES,
    max_pixels: int = MAX_PIXELS,
    fit: Fit = "crop",
) -> bytes:
    """Decode an uploaded picture, make it square and re-encode it as a PNG.

    The caller names the errors, so each feature reports a refused upload in its own words.

    `fit` says how a picture that is not square becomes one: `"crop"` keeps its centre square
    (a face in a round avatar), `"pad"` keeps all of it, centred on a transparent square (a
    wide wordmark logo would lose its ends to a crop).

    Raises:
        The `too_large()` error: the file or its pixel count is over the limit.
        The `invalid()` error: the bytes aren't a PNG, JPEG or WebP picture.
    """
    if len(data) > max_bytes:
        raise too_large()
    try:
        with warnings.catch_warnings():
            # Pillow only warns between its limit and twice it; ours is the one that counts.
            warnings.simplefilter("ignore", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in ACCEPTED_FORMATS:
                    raise invalid()
                if image.width * image.height > max_pixels:
                    raise too_large()
                # A phone photo is often stored sideways with an orientation tag: apply it
                # before the tag goes, or the picture comes out rotated.
                upright = ImageOps.exif_transpose(image)
                rgba = upright.convert("RGBA")
                if fit == "pad":
                    # Transparent padding, whatever the input: a JPEG has no alpha of its own,
                    # but the output is a PNG.
                    square = ImageOps.pad(
                        rgba,
                        (size, size),
                        method=Image.Resampling.LANCZOS,
                        color=(0, 0, 0, 0),
                    )
                else:
                    square = ImageOps.fit(rgba, (size, size), method=Image.Resampling.LANCZOS)
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError, ValueError) as exc:
        raise invalid() from exc

    output = io.BytesIO()
    square.save(output, format="PNG", optimize=True)
    return output.getvalue()
