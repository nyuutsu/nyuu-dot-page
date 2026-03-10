#!/usr/bin/env python3
"""
Blobmoji Subset Builder - Builds emoji font with only glyphs used in content.

Scans content/ for emoji, maps to SVG sources, builds font if changed.
Uses hash-based caching to skip rebuilds when emoji set unchanged.

Usage: python3 build-subset.py
Run as part of `make build` or standalone.

Dependencies managed by pyproject.toml:
  cd config/blobmoji && uv sync
"""

import base64
import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
CONTENT_DIR = PROJECT_ROOT / "content"
SRC_DIR = PROJECT_ROOT / "src"
SVG_SOURCE = SCRIPT_DIR / "svg-fixed"
FONTS_OUT = PROJECT_ROOT / "static" / "fonts"
HASH_FILE = FONTS_OUT / ".blobmoji-hash"
VENV_DIR = SCRIPT_DIR / ".venv"

# Emoji Unicode ranges
EMOJI_RANGES = [
    (0x2600, 0x26FF),    # Misc symbols
    (0x2700, 0x27BF),    # Dingbats
    (0x1F000, 0x1F0FF),  # Mahjong, playing cards
    (0x1F300, 0x1F5FF),  # Misc symbols & pictographs
    (0x1F600, 0x1F64F),  # Emoticons
    (0x1F680, 0x1F6FF),  # Transport & map symbols
    (0x1F900, 0x1F9FF),  # Supplemental symbols & pictographs
    (0x1FA00, 0x1FAFF),  # Symbols extended-A
    (0x1F1E6, 0x1F1FF),  # Regional indicators (flags)
]

# Special codepoints needed for sequences
ZWJ = 0x200D
VS16 = 0xFE0F  # Emoji presentation selector


def is_emoji_codepoint(cp):
    """Check if codepoint is in emoji ranges."""
    return any(start <= cp <= end for start, end in EMOJI_RANGES)


def scan_content_for_emoji():
    """Scan content and src files for emoji. Returns set of codepoint tuples."""
    emoji_set = set()

    # Regex to find emoji (single or sequences)
    # This captures runs of emoji codepoints including ZWJ and VS16

    for pattern in ["content/**/*.md", "src/**/*.hs", "scss/**/*.scss"]:
        for f in PROJECT_ROOT.glob(pattern):
            try:
                text = f.read_text()
                for char in text:
                    cp = ord(char)
                    if is_emoji_codepoint(cp):
                        emoji_set.add((cp,))  # Single codepoint as tuple
            except Exception as e:
                print(f"  Warning: Could not read {f}: {e}")

    return emoji_set


def expand_emoji_dependencies(emoji_set):
    """Expand ZWJ sequences to include component codepoints."""
    expanded = set()
    has_zwj = False
    has_flags = False

    for emoji_tuple in emoji_set:
        expanded.add(emoji_tuple)

        # Check if this is a regional indicator (flag component)
        for cp in emoji_tuple:
            if 0x1F1E6 <= cp <= 0x1F1FF:
                has_flags = True

    # If any flags detected, include all regional indicators A-Z
    # This ensures any flag combination works
    if has_flags:
        for cp in range(0x1F1E6, 0x1F200):
            expanded.add((cp,))

    return expanded


def map_to_svg_files(emoji_set):
    """Map emoji codepoints to SVG filenames. Returns list of existing SVG paths."""
    svg_files = []
    missing = []

    for emoji_tuple in sorted(emoji_set):
        # Build filename: emoji_u{cp1}_{cp2}_{...}.svg
        hex_parts = [f"{cp:x}" for cp in emoji_tuple]
        filename = f"emoji_u{'_'.join(hex_parts)}.svg"
        svg_path = SVG_SOURCE / filename

        if svg_path.exists():
            svg_files.append(svg_path)
        else:
            missing.append(filename)

    if missing and len(missing) <= 10:
        print(f"  Note: {len(missing)} emoji not in Blobmoji: {', '.join(missing)}")
    elif missing:
        print(f"  Note: {len(missing)} emoji not in Blobmoji (system fallback)")

    return svg_files


def compute_hash(svg_files):
    """Compute hash of the SVG file list for cache validation."""
    # Hash the sorted list of filenames
    content = "\n".join(sorted(str(f.name) for f in svg_files))
    return hashlib.sha256(content.encode()).hexdigest()[:16]


def check_cache(current_hash):
    """Check if cached font matches current hash."""
    font_path = FONTS_OUT / "Blobmoji.woff2"

    if not font_path.exists():
        return False

    if not HASH_FILE.exists():
        return False

    stored_hash = HASH_FILE.read_text().strip()
    return stored_hash == current_hash


def build_font(svg_files):
    """Build the emoji font from SVG files."""
    if not svg_files:
        print("  No emoji to build - creating empty placeholder")
        # Create a minimal valid font or skip
        return False

    # Activate venv
    venv_python = VENV_DIR / "bin" / "python3"
    venv_activate = VENV_DIR / "bin" / "activate"

    if not venv_python.exists():
        print(f"  Error: venv not found at {VENV_DIR}")
        print(f"  Run: cd {SCRIPT_DIR} && uv sync")
        return False

    # Check for resvg (in venv)
    resvg_path = VENV_DIR / "bin" / "resvg"
    if not resvg_path.exists():
        print(f"  Error: resvg not found in venv. Run: cd {SCRIPT_DIR} && uv sync")
        return False

    print(f"  Building font with {len(svg_files)} glyphs...")

    # Create temp directories
    work_dir = SCRIPT_DIR / "build-work"
    svg_norm_dir = work_dir / "svg-norm"
    png_dir = work_dir / "png"

    shutil.rmtree(work_dir, ignore_errors=True)
    svg_norm_dir.mkdir(parents=True)
    png_dir.mkdir(parents=True)

    # Step 1: Normalize SVGs (render to PNG, wrap in clean SVG)
    print("  [1/4] Normalizing SVGs...")
    for i, svg_path in enumerate(svg_files):
        if i % 50 == 0 and i > 0:
            print(f"        {i}/{len(svg_files)}...")

        name = svg_path.stem
        png_path = png_dir / f"{name}.png"
        svg_out = svg_norm_dir / svg_path.name

        # Render to PNG (use venv's resvg)
        subprocess.run(
            [str(resvg_path), str(svg_path), str(png_path), "-w", "128", "-h", "128"],
            capture_output=True, check=True
        )

        # Create clean SVG wrapper
        with open(png_path, "rb") as f:
            png_b64 = base64.b64encode(f.read()).decode("ascii")

        clean_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="128" height="128" viewBox="0 0 128 128">
  <image width="128" height="128" xlink:href="data:image/png;base64,{png_b64}"/>
</svg>'''
        svg_out.write_text(clean_svg)

    # Write glyph list
    glyph_list = work_dir / "glyphs.txt"
    glyph_list.write_text("\n".join(str(svg_norm_dir / f.name) for f in svg_files))

    # Step 2: Build SVG font
    print("  [2/4] Building SVG font...")
    svg_ttf = work_dir / "BlobmojiSVG.ttf"
    nanoemoji_bin = VENV_DIR / "bin" / "nanoemoji"

    # Environment with venv bin on PATH (nanoemoji needs resvg)
    env = os.environ.copy()
    env["PATH"] = f"{VENV_DIR}/bin:{env.get('PATH', '')}"

    # Remove nanoemoji's build dir if exists
    nanoemoji_build = SCRIPT_DIR / "build"
    shutil.rmtree(nanoemoji_build, ignore_errors=True)

    result = subprocess.run(
        f"cat {glyph_list} | xargs {nanoemoji_bin} --color_format untouchedsvg --family Blobmoji --output_file {svg_ttf}",
        shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR, env=env
    )
    if result.returncode != 0:
        print(f"  Error building SVG font: {result.stderr}")
        return False

    # Step 3: Build CBDT font
    print("  [3/4] Building CBDT font...")
    cbdt_ttf = work_dir / "BlobmojiCBDT.ttf"
    shutil.rmtree(nanoemoji_build, ignore_errors=True)

    result = subprocess.run(
        f"cat {glyph_list} | xargs {nanoemoji_bin} --color_format cbdt --family Blobmoji --output_file {cbdt_ttf}",
        shell=True, capture_output=True, text=True, cwd=SCRIPT_DIR, env=env
    )
    if result.returncode != 0:
        print(f"  Error building CBDT font: {result.stderr}")
        return False

    # Step 4: Merge and finalize
    print("  [4/4] Merging tables and creating woff2...")

    merge_script = f'''
from fontTools.ttLib import TTFont

svg_font = TTFont("{svg_ttf}")
cbdt_font = TTFont("{cbdt_ttf}")

# Merge color tables
svg_font["CBDT"] = cbdt_font["CBDT"]
svg_font["CBLC"] = cbdt_font["CBLC"]

# Remove ASCII hijacking
remove_cps = [0x20, 0x23, 0x2A] + list(range(0x30, 0x3A))
for table in svg_font["cmap"].tables:
    for cp in remove_cps:
        if cp in table.cmap:
            del table.cmap[cp]

# Set metadata
name_table = svg_font["name"]
def set_name(nid, val):
    name_table.setName(val, nid, 3, 1, 0x409)
    name_table.setName(val, nid, 1, 0, 0)

set_name(0, "Based on Blobmoji by Constantin A. and Google Inc. Licensed under SIL OFL 1.1.")
set_name(1, "Blobmoji")
set_name(2, "Regular")
set_name(4, "Blobmoji")
set_name(5, "Version 1.0")
set_name(6, "Blobmoji-Regular")
set_name(8, "nyuu (subset), Constantin A. (Blobmoji), Google (Noto Emoji)")
set_name(9, "nyuu (subset), Constantin A. (Blobmoji), Google (Noto Emoji)")
set_name(13, "SIL Open Font License, Version 1.1")
set_name(14, "http://scripts.sil.org/OFL")

svg_font["OS/2"].achVendID = "NYUU"
svg_font["OS/2"].fsType = 0

svg_font.flavor = "woff2"
svg_font.save("{FONTS_OUT}/Blobmoji.woff2")
print(f"  Output: {{svg_font.reader.file.name}}")
'''

    # Use the venv's Python so fontTools is available without path hacks
    venv_python = VENV_DIR / "bin" / "python3"
    result = subprocess.run(
        [str(venv_python), "-c", merge_script],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  Error merging: {result.stderr}")
        return False

    # Cleanup
    shutil.rmtree(work_dir, ignore_errors=True)
    shutil.rmtree(nanoemoji_build, ignore_errors=True)

    return True


def main():
    print("Blobmoji subset builder...")

    # Step 1: Scan for emoji
    print("  Scanning content for emoji...")
    emoji_set = scan_content_for_emoji()
    print(f"  Found {len(emoji_set)} unique emoji")

    if not emoji_set:
        print("  No emoji in content - skipping font build")
        # Remove old font if exists to avoid confusion
        font_path = FONTS_OUT / "Blobmoji.woff2"
        if font_path.exists():
            font_path.unlink()
            HASH_FILE.unlink(missing_ok=True)
        return

    # Step 2: Expand dependencies
    expanded = expand_emoji_dependencies(emoji_set)
    print(f"  After expanding dependencies: {len(expanded)} codepoints")

    # Step 3: Map to SVG files
    svg_files = map_to_svg_files(expanded)
    print(f"  Mapped to {len(svg_files)} SVG sources")

    if not svg_files:
        print("  No matching SVGs found - cannot build font")
        return

    # Step 4: Check cache
    current_hash = compute_hash(svg_files)
    if check_cache(current_hash):
        print(f"  Cache hit (hash: {current_hash}) - skipping build")
        return

    print(f"  Cache miss (hash: {current_hash}) - building font...")

    # Step 5: Build font
    if build_font(svg_files):
        # Update cache
        HASH_FILE.write_text(current_hash)
        size = (FONTS_OUT / "Blobmoji.woff2").stat().st_size
        print(f"  Done: Blobmoji.woff2 ({size / 1024:.1f} KB)")
    else:
        print("  Build failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
