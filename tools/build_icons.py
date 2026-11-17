# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "fonttools==4.66.1",
#     "pillow==12.3.0",
#     "resvg-py==0.5.0",
#     "uharfbuzz==0.56.3",
# ]
# ///
"""Build the Bastide logo files, app icons and installer splash.

Run from anywhere with ``uv run tools/build_icons.py``.

The single source is the « Plan » geometry in ``docs/design/18-brand.md``,
transcribed below, and the bundled Geist. Outputs:

- the vector masters in ``frontend/assets/brand/``: the mark (app-icon
  colours), the small mark (same geometry, kept for the callers that load
  it), the monochrome glyph and the dark and light lockups, with the name
  outlined from the font;
- the Windows ``app_icon.ico``;
- every PNG of the macOS ``AppIcon.appiconset``;
- 256 and 512 px PNGs for Linux;
- the Windows installer splash, ``splash.svg`` and ``splash.png``.

Each raster is rendered from a vector at its target size, never downscaled
from a larger PNG. Files are only rewritten when their bytes change, so a
second run is a no-op.
"""

import io
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
FONTS = FRONTEND / "assets" / "fonts" / "Geist" / "static"
FONT_NAME = FONTS / "Geist-SemiBold.ttf"
FONT_BODY = FONTS / "Geist-Regular.ttf"

MARK = BRAND / "bastide-mark.svg"
MARK_SMALL = BRAND / "bastide-mark-small.svg"
GLYPH_MONO = BRAND / "bastide-glyph-mono.svg"

WINDOWS_ICO = FRONTEND / "windows" / "runner" / "resources" / "app_icon.ico"
WINDOWS_SIZES = (16, 20, 24, 32, 40, 48, 64, 256)

MACOS_ICONSET = FRONTEND / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
# Apple's icon grid: the 824 px tile sits centred on a 1024 px canvas.
MACOS_TILE_FRACTION = 824 / 1024

LINUX_SIZES = (256, 512)

SPLASH_DIR = FRONTEND / "windows" / "installer"

# --- The « Plan » mark (18-brand.md §1) ---------------------------------------

GRID = 24
TILE_RADIUS = 5.3
CELL = 4
CELL_RADIUS = 0.8
CELL_POSITIONS = (4.5, 10, 15.5)
MONO_CENTRE_OPACITY = 0.45

# (tile, glyph, accent) per ground, from the colour table.
ON_DARK = ("#ECEDEF", "#111214", "#7FA6FF")
ON_LIGHT = ("#17181A", "#FFFFFF", "#2B5CD0")
APP_ICON = ("#17181A", "#FFFFFF", "#7FA6FF")

# Lockup: the name's cap height is two cells and a gap, the gap between the
# mark and the name 8 units, tracking −0.02 em. Files are drawn with a 48 px
# tile; the name's cap height is centred on the tile.
LOCKUP_TILE = 48
LOCKUP_NAME = "Bastide"
LOCKUP_CAP_UNITS = 2 * CELL + (CELL_POSITIONS[1] - CELL_POSITIONS[0] - CELL)
LOCKUP_GAP_UNITS = 8
TRACKING_EM = -0.02
LOCKUPS = {"dark": (ON_DARK, "#ECEDEF"), "light": (ON_LIGHT, "#17181A")}

# --- Installer splash (18-brand.md §3) ----------------------------------------

SPLASH_W, SPLASH_H = 560, 320
SPLASH_GROUND = "#111214"
SPLASH_TOMETTE_OPACITY = 0.09
SPLASH_MARK_PX = 64
SPLASH_MARK_TOP = 84
SPLASH_NAME = (LOCKUP_NAME, FONT_NAME, 26, TRACKING_EM, "#ECEDEF", 190)
SPLASH_SENTENCE = (
    "Vos données restent sur cet ordinateur.",
    FONT_BODY,
    13,
    0.0,
    "#A3A7AE",
    216,
)
SPLASH_TRACK = "#25272B"
SPLASH_TRACK_HEIGHT = 12

# The tomettes tile (00-design-system.md §12).
TOMETTE_W, TOMETTE_H = 24.25, 42
TOMETTE_PATH = "M0 7 12.125 0l12.125 7M0 7v14M24.25 7v14M0 21l12.125 7 12.125-7M12.125 28v14"


def write_if_changed(path: Path, data: bytes, label: str) -> None:
    rel = path.relative_to(ROOT).as_posix()
    if path.exists() and path.read_bytes() == data:
        print(f"unchanged  {rel}  ({label})")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"wrote      {rel}  ({label})")


def fmt(value: float) -> str:
    """Three decimals at most, no trailing zeros, no negative zero."""
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def cells(glyph: str, accent: str, accent_opacity: float | None = None) -> str:
    """The nine squares on the 24-unit grid; the centre one in `accent`."""
    rects = []
    for y in CELL_POSITIONS:
        for x in CELL_POSITIONS:
            centre = x == CELL_POSITIONS[1] and y == CELL_POSITIONS[1]
            fill = accent if centre else glyph
            extra = (
                f' fill-opacity="{fmt(accent_opacity)}"'
                if centre and accent_opacity is not None
                else ""
            )
            rects.append(
                f'<rect x="{fmt(x)}" y="{fmt(y)}" width="{CELL}" height="{CELL}" '
                f'rx="{fmt(CELL_RADIUS)}" fill="{fill}"{extra}/>'
            )
    return "\n  ".join(rects)


def mark_body(colours: tuple[str, str, str]) -> str:
    tile, glyph, accent = colours
    return (
        f'<rect width="{GRID}" height="{GRID}" rx="{fmt(TILE_RADIUS)}" fill="{tile}"/>\n  '
        + cells(glyph, accent)
    )


def mark_svg(colours: tuple[str, str, str]) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {GRID} {GRID}">
  <title>Bastide</title>
  {mark_body(colours)}
</svg>
"""


def mono_svg() -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {GRID} {GRID}">
  <title>Bastide</title>
  {cells("currentColor", "currentColor", MONO_CENTRE_OPACITY)}
</svg>
"""


def build_masters() -> None:
    write_if_changed(MARK, mark_svg(APP_ICON).encode(), "app-icon colours")
    write_if_changed(MARK_SMALL, mark_svg(APP_ICON).encode(), "same geometry")
    write_if_changed(GLYPH_MONO, mono_svg().encode(), "monochrome")


# --- Text outlines -------------------------------------------------------------


def outline_text(
    text: str, font_path: Path, size: float, tracking_em: float, x: float, baseline: float
) -> tuple[str, float, float]:
    """`text` as one SVG path, left edge at `x`, on `baseline`.

    Shaped with HarfBuzz so the font's kerning applies, as it does in a
    browser; CSS letter-spacing is then added between glyphs. Returns the
    path, the advance width (without trailing tracking) and the right ink
    edge.
    """
    font = TTFont(font_path)
    scale = size / font["head"].unitsPerEm

    hb_font = hb.Font(hb.Face(hb.Blob.from_file_path(str(font_path))))
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hb_font, buf, {"kern": True})

    glyph_set = font.getGlyphSet()
    glyph_order = font.getGlyphOrder()
    pen = SVGPathPen(glyph_set, ntos=fmt)
    tracking = tracking_em * size
    cursor = x
    right = x
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions, strict=True):
        name = glyph_order[info.codepoint]
        origin = cursor + pos.x_offset * scale
        glyph_set[name].draw(TransformPen(pen, (scale, 0, 0, -scale, origin, baseline)))
        bounds = BoundsPen(glyph_set)
        glyph_set[name].draw(bounds)
        if bounds.bounds is not None:
            right = max(right, origin + bounds.bounds[2] * scale)
        cursor += pos.x_advance * scale + tracking
    return pen.getCommands(), cursor - tracking - x, right


def cap_height_ratio(font_path: Path) -> float:
    font = TTFont(font_path)
    return font["OS/2"].sCapHeight / font["head"].unitsPerEm


# --- Lockups -------------------------------------------------------------------


def build_lockups() -> None:
    unit = LOCKUP_TILE / GRID
    cap = LOCKUP_CAP_UNITS * unit
    size = cap / cap_height_ratio(FONT_NAME)
    baseline = (LOCKUP_TILE + cap) / 2
    x = LOCKUP_TILE + LOCKUP_GAP_UNITS * unit
    for theme, (colours, ink) in LOCKUPS.items():
        name, _, right = outline_text(LOCKUP_NAME, FONT_NAME, size, TRACKING_EM, x, baseline)
        width = fmt(right + 0.005)  # round the ink edge up so nothing is clipped
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {LOCKUP_TILE}">
  <title>Bastide</title>
  <g transform="scale({fmt(unit)})">
  {mark_body(colours)}
  </g>
  <path fill="{ink}" d="{name}"/>
</svg>
"""
        write_if_changed(
            BRAND / f"bastide-lockup-{theme}.svg",
            svg.encode(),
            f"viewBox {width} x {LOCKUP_TILE}",
        )


# --- Splash ----------------------------------------------------------------------


def centred_text(spec: tuple[str, Path, float, float, str, float]) -> str:
    text, font_path, size, tracking, ink, baseline = spec
    _, advance, _ = outline_text(text, font_path, size, tracking, 0, baseline)
    path, _, _ = outline_text(text, font_path, size, tracking, (SPLASH_W - advance) / 2, baseline)
    return f'<path fill="{ink}" d="{path}"/>'


def splash_svg() -> str:
    scale = SPLASH_MARK_PX / GRID
    mark_x = (SPLASH_W - SPLASH_MARK_PX) / 2
    track_y = SPLASH_H - SPLASH_TRACK_HEIGHT
    size = f'width="{SPLASH_W}" height="{SPLASH_H}" viewBox="0 0 {SPLASH_W} {SPLASH_H}"'
    tile = f'width="{fmt(TOMETTE_W)}" height="{TOMETTE_H}" patternUnits="userSpaceOnUse"'
    stroke = f'stroke="#FFFFFF" stroke-opacity="{fmt(SPLASH_TOMETTE_OPACITY)}"'
    return f"""<svg xmlns="http://www.w3.org/2000/svg" {size}>
  <title>Bastide</title>
  <defs>
    <pattern id="tomettes" {tile}>
      <path d="{TOMETTE_PATH}" fill="none" {stroke}/>
    </pattern>
    <radialGradient id="fade" cx="50%" cy="46%" r="62%">
      <stop offset=".28" stop-color="{SPLASH_GROUND}"/>
      <stop offset="1" stop-color="{SPLASH_GROUND}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{SPLASH_W}" height="{SPLASH_H}" fill="{SPLASH_GROUND}"/>
  <rect width="{SPLASH_W}" height="{SPLASH_H}" fill="url(#tomettes)"/>
  <rect width="{SPLASH_W}" height="{SPLASH_H}" fill="url(#fade)"/>
  <g transform="translate({fmt(mark_x)} {SPLASH_MARK_TOP}) scale({fmt(scale)})">
  {mark_body(ON_DARK)}
  </g>
  {centred_text(SPLASH_NAME)}
  {centred_text(SPLASH_SENTENCE)}
  <rect y="{track_y}" width="{SPLASH_W}" height="{SPLASH_TRACK_HEIGHT}" fill="{SPLASH_TRACK}"/>
</svg>
"""


def build_splash() -> None:
    svg = splash_svg()
    write_if_changed(SPLASH_DIR / "splash.svg", svg.encode(), f"{SPLASH_W} x {SPLASH_H}")
    rgba = Image.open(
        io.BytesIO(bytes(resvg_py.svg_to_bytes(svg_string=svg, width=SPLASH_W, height=SPLASH_H)))
    )
    out = io.BytesIO()
    rgba.convert("RGB").save(out, format="PNG", optimize=True)  # opaque
    write_if_changed(SPLASH_DIR / "splash.png", out.getvalue(), f"{SPLASH_W} x {SPLASH_H} px")


# --- Icons ---------------------------------------------------------------------


def render(svg: str, px: int) -> bytes:
    return bytes(resvg_py.svg_to_bytes(svg_string=svg, width=px, height=px))


def inset(svg: str, tile_fraction: float) -> str:
    """Widen a 24-unit viewBox so the tile fills only `tile_fraction` of it."""
    full = GRID / tile_fraction
    margin = (full - GRID) / 2
    return svg.replace(
        f'viewBox="0 0 {GRID} {GRID}"',
        f'viewBox="{fmt(-margin)} {fmt(-margin)} {fmt(full)} {fmt(full)}"',
        1,
    )


def build_windows() -> None:
    # 16 and 20 px draw the same geometry as every other size (18-brand.md §1).
    master = mark_svg(APP_ICON)
    frames = [Image.open(io.BytesIO(render(master, px))) for px in WINDOWS_SIZES]
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
    svg = inset(mark_svg(APP_ICON), MACOS_TILE_FRACTION)
    for path in sorted(MACOS_ICONSET.glob("app_icon_*.png")):
        px = int(path.stem.removeprefix("app_icon_"))
        write_if_changed(path, render(svg, px), f"{px} x {px} px")


def build_linux() -> None:
    for px in LINUX_SIZES:
        write_if_changed(
            BRAND / f"bastide-mark-{px}.png",
            render(mark_svg(APP_ICON), px),
            f"{px} x {px} px",
        )


def main() -> None:
    build_masters()
    build_lockups()
    build_windows()
    build_macos()
    build_linux()
    build_splash()


if __name__ == "__main__":
    main()
