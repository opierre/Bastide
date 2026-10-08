# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "fonttools==4.66.1",
#     "pillow==12.3.0",
#     "resvg-py==0.5.0",
#     "uharfbuzz==0.56.3",
# ]
# ///
"""Build the Bastide lockups and app icons from the logo masters.

Run from anywhere with ``uv run tools/build_icons.py``.

Inputs are the hand-written vector masters in ``frontend/assets/brand/``
(``bastide-mark.svg`` and ``bastide-mark-small.svg``) and the bundled Space
Grotesk Bold. Outputs:

- the two lockup SVGs, with the wordmark outlined from the font;
- the Windows ``app_icon.ico``;
- every PNG of the macOS ``AppIcon.appiconset``;
- 256 and 512 px PNGs for Linux.

Each raster is rendered from a vector at its target size — the small-size
master up to 32 px, the main master above — never downscaled from a larger
PNG. Files are only rewritten when their bytes change, so a second run is a
no-op.
"""

import io
import re
from pathlib import Path

import resvg_py
import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"
BRAND = FRONTEND / "assets" / "brand"
FONT = (
    FRONTEND / "assets" / "fonts" / "Space_Grotesk" / "static" / "SpaceGrotesk-Bold.ttf"
)

MARK = BRAND / "bastide-mark.svg"
MARK_SMALL = BRAND / "bastide-mark-small.svg"

# The design's small variant covers 16–32 px; the main mark is for anything larger.
SMALL_MAX_PX = 32

WINDOWS_ICO = FRONTEND / "windows" / "runner" / "resources" / "app_icon.ico"
WINDOWS_SIZES = (16, 20, 24, 32, 40, 48, 64, 256)

MACOS_ICONSET = FRONTEND / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
# Apple's icon grid: the 824 px tile sits centred on a 1024 px canvas.
MACOS_TILE_FRACTION = 824 / 1024

LINUX_SIZES = (256, 512)

# Lockup geometry, in CSS px, from docs/design/bastide-logo.html §04:
# 48 px tile, 16 px gap, Space Grotesk 700 at 28 px, tracking −1.5 %,
# line-height 1, text centred vertically on the tile.
LOCKUP_TILE = 48
LOCKUP_GAP = 16
LOCKUP_FONT_SIZE = 28
LOCKUP_TRACKING_EM = -0.015
LOCKUP_TEXT = "Bastide"
LOCKUP_INKS = {"dark": "#EDF1F7", "light": "#0E1030"}


def write_if_changed(path: Path, data: bytes, label: str) -> None:
    rel = path.relative_to(ROOT).as_posix()
    if path.exists() and path.read_bytes() == data:
        print(f"unchanged  {rel}  ({label})")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"wrote      {rel}  ({label})")


def fmt(value: float) -> str:
    """Two decimals at most, no trailing zeros, no negative zero."""
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


# --- Lockups -----------------------------------------------------------------


def mark_body(svg: str) -> str:
    """The tile rect and glyph path of a mark master, without its gradient."""
    rect = re.search(r"<rect [^>]*/>", svg)
    path = re.search(r"<path [^>]*/>", svg)
    if rect is None or path is None:
        raise SystemExit(f"{MARK} no longer has a <rect> tile and a <path> glyph")
    return f"{rect.group(0)}\n    {path.group(0)}"


def outline_wordmark() -> tuple[str, float]:
    """The wordmark as one SVG path in lockup px, and its right ink edge.

    Shaped with HarfBuzz so the font's kerning applies, as it does in the
    browser that rendered the design; CSS letter-spacing is then added after
    every glyph.
    """
    font = TTFont(FONT)
    upm = font["head"].unitsPerEm
    scale = LOCKUP_FONT_SIZE / upm

    # CSS line-height 1: the line box is one em tall and the font's content
    # area (typo ascender + descender, since USE_TYPO_METRICS is set) is
    # centred in it. The line box itself is centred on the tile.
    os2 = font["OS/2"]
    content = (os2.sTypoAscender - os2.sTypoDescender) * scale
    half_leading = (LOCKUP_FONT_SIZE - content) / 2
    line_top = (LOCKUP_TILE - LOCKUP_FONT_SIZE) / 2
    baseline = line_top + half_leading + os2.sTypoAscender * scale

    hb_font = hb.Font(hb.Face(hb.Blob.from_file_path(str(FONT))))
    buf = hb.Buffer()
    buf.add_str(LOCKUP_TEXT)
    buf.guess_segment_properties()
    hb.shape(hb_font, buf, {"kern": True})

    glyph_set = font.getGlyphSet()
    glyph_order = font.getGlyphOrder()
    pen = SVGPathPen(glyph_set, ntos=fmt)
    x = LOCKUP_TILE + LOCKUP_GAP
    tracking = LOCKUP_TRACKING_EM * LOCKUP_FONT_SIZE
    right = x
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions, strict=True):
        name = glyph_order[info.codepoint]
        origin = x + pos.x_offset * scale
        glyph_set[name].draw(TransformPen(pen, (scale, 0, 0, -scale, origin, baseline)))
        bounds = BoundsPen(glyph_set)
        glyph_set[name].draw(bounds)
        if bounds.bounds is not None:
            right = max(right, origin + bounds.bounds[2] * scale)
        x += pos.x_advance * scale + tracking
    return pen.getCommands(), right


def build_lockups() -> None:
    body = mark_body(MARK.read_text(encoding="utf-8"))
    wordmark, right = outline_wordmark()
    width = fmt(right + 0.005)  # round the ink edge up so nothing is clipped
    for theme, ink in LOCKUP_INKS.items():
        gradient_id = f"bastide-lockup-{theme}-tile"
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {LOCKUP_TILE}">
  <title>Bastide</title>
  <defs>
    <linearGradient id="{gradient_id}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#8B8CF9"/>
      <stop offset="1" stop-color="#6C6AF0"/>
    </linearGradient>
  </defs>
  <g transform="scale({fmt(LOCKUP_TILE / 24)})">
    {body.replace("url(#bastide-mark-tile)", f"url(#{gradient_id})")}
  </g>
  <path fill="{ink}" d="{wordmark}"/>
</svg>
"""
        write_if_changed(
            BRAND / f"bastide-lockup-{theme}.svg",
            svg.encode(),
            f"viewBox {width} x {LOCKUP_TILE}",
        )


# --- Rasters -----------------------------------------------------------------


def master_for(px: int) -> str:
    return (MARK_SMALL if px <= SMALL_MAX_PX else MARK).read_text(encoding="utf-8")


def render(svg: str, px: int) -> bytes:
    return bytes(resvg_py.svg_to_bytes(svg_string=svg, width=px, height=px))


def inset(svg: str, tile_fraction: float) -> str:
    """Widen a 24-unit viewBox so the tile fills only `tile_fraction` of it."""
    full = 24 / tile_fraction
    margin = (full - 24) / 2
    return svg.replace(
        'viewBox="0 0 24 24"', f'viewBox="{-margin} {-margin} {full} {full}"', 1
    )


def build_windows() -> None:
    frames = [
        Image.open(io.BytesIO(render(master_for(px), px))) for px in WINDOWS_SIZES
    ]
    largest = frames[-1]
    out = io.BytesIO()
    # `append_images` hands Pillow a ready frame for each size, so it never
    # resamples the 256 px image down.
    largest.save(
        out,
        format="ICO",
        sizes=[(px, px) for px in WINDOWS_SIZES],
        append_images=frames[:-1],
    )
    sizes = ", ".join(str(px) for px in WINDOWS_SIZES)
    write_if_changed(WINDOWS_ICO, out.getvalue(), f"{sizes} px")


def build_macos() -> None:
    for path in sorted(MACOS_ICONSET.glob("app_icon_*.png")):
        px = int(path.stem.removeprefix("app_icon_"))
        svg = inset(master_for(px), MACOS_TILE_FRACTION)
        write_if_changed(path, render(svg, px), f"{px} x {px} px")


def build_linux() -> None:
    for px in LINUX_SIZES:
        write_if_changed(
            BRAND / f"bastide-mark-{px}.png",
            render(master_for(px), px),
            f"{px} x {px} px",
        )


def main() -> None:
    build_lockups()
    build_windows()
    build_macos()
    build_linux()


if __name__ == "__main__":
    main()
