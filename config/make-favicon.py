#!/usr/bin/env python3
"""
Favicon Generator - the tab mark as an outlined-path SVG plus PNG fallbacks.

"n." shaped in IM Fell English via HarfBuzz, outlined to raw paths on the dark ink square.
Upright, not italic like the wordmark: the italic smears at 16px, and a favicon's whole job is 16px.
Outlined rather than live <text> because a favicon renders in a sandbox with no page font.

Usage: uv run --project config config/make-favicon.py
Rerun only when the mark or the pool font changes.

Dependencies: fonttools, uharfbuzz
  cd config && uv sync
"""

import io
import subprocess
import tempfile
from pathlib import Path

import uharfbuzz as harfbuzz
from fontTools.misc.transform import Transform
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

SCRIPT_DIR = Path(__file__).parent
SOURCE_FONT = SCRIPT_DIR / "fonts-src" / "IMFellEnglish-Regular.woff2"
IMAGES = SCRIPT_DIR.parent / "static/images"
OUTPUT_SVG = IMAGES / "favicon.svg"
OUTPUT_PNG = IMAGES / "favicon-32.png"          # fallback for browsers that ignore SVG favicons
OUTPUT_APPLE = IMAGES / "apple-touch-icon.png"  # iOS home screen; full-bleed so iOS applies its own corner mask

TEXT = "n."
PERIOD_CLUSTER = TEXT.index(".")

INK = "#2E2B27"
CREAM = "#F2E7CF"
ACCENT = "#E7B25A"  # matches FULL_STOP_FILL in make-wordmark.py and $color-amber in scss/_variables.scss
BOX = 64
CORNER_RADIUS = 14
FILL_FRACTION = 0.62  # glyph extent as a share of the box; leaves optical margin inside the rounded corners
PERIOD_SCALE = 1.3    # the period is grown past its true proportion so the accent dot still reads at 16px


def outline(font, sfnt_bytes, text):
    """Shape text and outline each glyph; returns (glyphs, bbox) in y-flipped SVG space.
    Each glyph entry is (path, cluster, glyph_bbox); the per-glyph bbox lets the caller transform one glyph in place."""
    face = harfbuzz.Face(sfnt_bytes)
    hb_font = harfbuzz.Font(face)
    buffer = harfbuzz.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    harfbuzz.shape(hb_font, buffer)

    glyph_order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    glyphs = []
    bounds = [float("inf"), float("inf"), float("-inf"), float("-inf")]
    cursor = 0
    for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
        glyph = glyph_set[glyph_order[info.codepoint]]
        placement = Transform(1, 0, 0, -1, cursor + position.x_offset, -position.y_offset)

        pen = SVGPathPen(glyph_set, ntos=lambda v: f"{v:.1f}")
        glyph.draw(TransformPen(pen, placement))
        path = pen.getCommands()
        if path:
            bounds_pen = BoundsPen(glyph_set)
            glyph.draw(TransformPen(bounds_pen, placement))
            glyph_bounds = list(bounds_pen.bounds)
            glyphs.append((path, info.cluster, glyph_bounds))
            bounds = [min(bounds[0], glyph_bounds[0]), min(bounds[1], glyph_bounds[1]),
                      max(bounds[2], glyph_bounds[2]), max(bounds[3], glyph_bounds[3])]
        cursor += position.x_advance
    return glyphs, bounds


def render_glyph(path, cluster, glyph_bounds):
    """One <path>, with the period recoloured amber and grown around its own centre so it stays put but reads larger."""
    if cluster != PERIOD_CLUSTER:
        return f'    <path d="{path}" fill="{CREAM}"/>'
    if PERIOD_SCALE == 1.0:
        return f'    <path d="{path}" fill="{ACCENT}"/>'
    period_x = (glyph_bounds[0] + glyph_bounds[2]) / 2
    period_y = (glyph_bounds[1] + glyph_bounds[3]) / 2
    grow = f"translate({period_x:.1f} {period_y:.1f}) scale({PERIOD_SCALE}) translate({-period_x:.1f} {-period_y:.1f})"
    return f'    <g transform="{grow}"><path d="{path}" fill="{ACCENT}"/></g>'


def build_svg(glyphs, geometry, corner_radius):
    """Compose the mark SVG. corner_radius=0 gives a full-bleed square for the apple-touch icon."""
    translate_x, translate_y, scale = geometry
    paths = "\n".join(render_glyph(*glyph) for glyph in glyphs)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {BOX} {BOX}" role="img" aria-label="nyuu.page">
  <title>nyuu.page</title>
  <rect width="{BOX}" height="{BOX}" rx="{corner_radius}" fill="{INK}"/>
  <g transform="translate({translate_x:.2f} {translate_y:.2f}) scale({scale:.4f})">
{paths}
  </g>
</svg>
'''


def rasterize(svg, size, target):
    """Render an SVG string to a PNG via rsvg-convert (librsvg); the source SVG is never kept on disk."""
    with tempfile.NamedTemporaryFile("w", suffix=".svg") as source:
        source.write(svg)
        source.flush()
        subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size), source.name, "-o", str(target)],
            check=True,
        )
    print(f"Wrote {target} ({target.stat().st_size:,} bytes)")


def main():
    font = TTFont(SOURCE_FONT)
    sfnt = io.BytesIO()
    font.flavor = None
    font.save(sfnt)

    glyphs, (min_x, min_y, max_x, max_y) = outline(font, sfnt.getvalue(), TEXT)
    extent = max(max_x - min_x, max_y - min_y)
    scale = (BOX * FILL_FRACTION) / extent
    center_x, center_y = (min_x + max_x) / 2, (min_y + max_y) / 2
    geometry = (BOX / 2 - scale * center_x, BOX / 2 - scale * center_y, scale)

    rounded = build_svg(glyphs, geometry, CORNER_RADIUS)
    OUTPUT_SVG.write_text(rounded)
    print(f"Wrote {OUTPUT_SVG} ({OUTPUT_SVG.stat().st_size:,} bytes)")

    rasterize(rounded, 32, OUTPUT_PNG)
    rasterize(build_svg(glyphs, geometry, 0), 180, OUTPUT_APPLE)


if __name__ == "__main__":
    main()
