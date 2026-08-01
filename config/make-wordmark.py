#!/usr/bin/env python3
"""
Wordmark Generator - the site logo as an outlined-path SVG.

"nyuu.page" shaped in IM Fell English Italic via HarfBuzz (real kerning), then every glyph flattened to raw paths.
Referencing no font, it renders identically everywhere, ignores the <img> sandbox, and costs the smooth tree zero font bytes.

Usage: uv run --project config config/make-wordmark.py
Rerun only when the wordmark text or the pool italic font changes.

Dependencies: fonttools, uharfbuzz
  cd config && uv sync
"""

import io
from pathlib import Path

import uharfbuzz as harfbuzz
from fontTools.misc.transform import Transform
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

SCRIPT_DIR = Path(__file__).parent
SOURCE_FONT = SCRIPT_DIR / "fonts-src" / "IMFellEnglish-Italic.woff2"
OUTPUT_SVG = SCRIPT_DIR.parent / "static/images/wordmark.svg"

TEXT = "nyuu.page"
FILL = "#F2E7CF"
FULL_STOP_FILL = "#E7B25A"  # matches ACCENT in make-favicon.py and $color-amber in scss/_variables.scss
STROKE = "#14110E"
STROKE_EM = 22 / 132  # stroke width : font size
PADDING_EM = 0.04

FULL_STOP_CLUSTER = TEXT.index(".")


def shape_text(font_bytes):
    """Shape TEXT with HarfBuzz; returns (glyph_infos, glyph_positions)."""
    face = harfbuzz.Face(font_bytes)
    font = harfbuzz.Font(face)
    buffer = harfbuzz.Buffer()
    buffer.add_str(TEXT)
    buffer.guess_segment_properties()
    harfbuzz.shape(font, buffer)
    return buffer.glyph_infos, buffer.glyph_positions


def main():
    font = TTFont(SOURCE_FONT)
    units_per_em = font["head"].unitsPerEm

    # HarfBuzz wants raw sfnt bytes, not woff2
    sfnt = io.BytesIO()
    font.flavor = None
    font.save(sfnt)

    infos, positions = shape_text(sfnt.getvalue())
    glyph_order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()

    stroke_width = STROKE_EM * units_per_em
    padding = PADDING_EM * units_per_em + stroke_width / 2

    # Draw each glyph at its shaped position, y-flipped into SVG space
    paths = []
    bounds_min_x = bounds_min_y = float("inf")
    bounds_max_x = bounds_max_y = float("-inf")
    cursor_x = 0
    for info, position in zip(infos, positions):
        glyph_name = glyph_order[info.codepoint]
        glyph = glyph_set[glyph_name]
        placement = Transform(
            1, 0, 0, -1, cursor_x + position.x_offset, -position.y_offset
        )

        svg_pen = SVGPathPen(glyph_set, ntos=lambda v: f"{v:.0f}")
        glyph.draw(TransformPen(svg_pen, placement))
        path_data = svg_pen.getCommands()
        if path_data:
            fill = FULL_STOP_FILL if info.cluster == FULL_STOP_CLUSTER else FILL
            paths.append((path_data, fill))

            bounds_pen = BoundsPen(glyph_set)
            glyph.draw(TransformPen(bounds_pen, placement))
            min_x, min_y, max_x, max_y = bounds_pen.bounds
            bounds_min_x = min(bounds_min_x, min_x)
            bounds_min_y = min(bounds_min_y, min_y)
            bounds_max_x = max(bounds_max_x, max_x)
            bounds_max_y = max(bounds_max_y, max_y)

        cursor_x += position.x_advance

    view_x = bounds_min_x - padding
    view_y = bounds_min_y - padding
    view_w = (bounds_max_x - bounds_min_x) + 2 * padding
    view_h = (bounds_max_y - bounds_min_y) + 2 * padding

    defs = "\n".join(
        f'    <path id="g{i}" d="{d}"/>' for i, (d, fill) in enumerate(paths)
    )
    stroke_uses = "\n".join(f'    <use href="#g{i}"/>' for i in range(len(paths)))
    fill_uses = "\n".join(
        f'    <use href="#g{i}" fill="{fill}"/>' for i, (d, fill) in enumerate(paths)
    )

    # Stroke layer painted first, fill layer on top: outward-only stroke without relying on paint-order support
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_x:.0f} {view_y:.0f} {view_w:.0f} {view_h:.0f}" width="{view_w:.0f}" height="{view_h:.0f}" role="img" aria-label="nyuu.page">
  <title>nyuu.page</title>
  <defs>
{defs}
  </defs>
  <g fill="none" stroke="{STROKE}" stroke-width="{stroke_width:.0f}" stroke-linejoin="round" stroke-linecap="round">
{stroke_uses}
  </g>
  <g>
{fill_uses}
  </g>
</svg>
'''
    OUTPUT_SVG.write_text(svg)
    size = OUTPUT_SVG.stat().st_size
    print(f"Wrote {OUTPUT_SVG} ({size:,} bytes, viewBox {view_w:.0f}x{view_h:.0f})")


if __name__ == "__main__":
    main()
