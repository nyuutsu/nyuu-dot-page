#!/usr/bin/env python3
"""
Font Subsetter - Creates subsets of fonts based on actual content usage.

Scans content/ and src/ for characters, subsets fonts in config/fonts-src/
to static/fonts/. Each font has its own Unicode range detection.

Uses hash-based caching to skip rebuilds when character sets unchanged.

Usage: ./font-subset.py
Run before building the site (or use `make build`).

Dependencies: fonttools, brotli
  cd config && uv sync
"""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
FONTS_SRC = SCRIPT_DIR / "fonts-src"
FONTS_OUT = PROJECT_ROOT / "static/fonts"
HASH_FILE = FONTS_OUT / ".font-subset-cache.json"

# Unicode ranges for scanning
LATIN_RANGES = [
    (0x0000, 0x007F),    # Basic Latin (ASCII)
    (0x0080, 0x00FF),    # Latin-1 Supplement
    (0x0100, 0x017F),    # Latin Extended-A
    (0x0180, 0x024F),    # Latin Extended-B
    (0x2000, 0x206F),    # General Punctuation
    (0x20A0, 0x20CF),    # Currency Symbols
    (0x2100, 0x214F),    # Letterlike Symbols
]

# Always include these for Latin fonts (Pandoc smart quotes, common punctuation)
# Even if not found in raw markdown, Pandoc may output them
LATIN_ALWAYS_INCLUDE = {
    # Smart quotes (Pandoc converts straight quotes to these)
    '\u2018',  # ' left single
    '\u2019',  # ' right single (apostrophe)
    '\u201C',  # " left double
    '\u201D',  # " right double
    # Dashes (Pandoc converts -- and --- to these)
    '\u2013',  # – en dash
    '\u2014',  # — em dash
    # Ellipsis
    '\u2026',  # … horizontal ellipsis
    # Common punctuation (just in case)
    '.', ',', ';', ':', '!', '?', "'", '"',
    '(', ')', '[', ']', '{', '}',
    '-', '/', '\\', '@', '#', '$', '%', '&', '*',
    '+', '=', '<', '>', '|', '~', '^', '`',
}

# Mono fonts get standard programming punctuation plus symbols common in
# Haskell/math code that might not appear in current content yet
MONO_ALWAYS_INCLUDE = LATIN_ALWAYS_INCLUDE | {
    '\u2190',  # ← leftwards arrow
    '\u2192',  # → rightwards arrow
    '\u2191',  # ↑ upwards arrow
    '\u2193',  # ↓ downwards arrow
    '\u21d2',  # ⇒ rightwards double arrow
    '\u21d0',  # ⇐ leftwards double arrow
    '\u2200',  # ∀ for all
    '\u2203',  # ∃ there exists
    '\u2208',  # ∈ element of
    '\u2209',  # ∉ not element of
    '\u2260',  # ≠ not equal
    '\u2264',  # ≤ less-than or equal
    '\u2265',  # ≥ greater-than or equal
    '\u2227',  # ∧ logical and
    '\u2228',  # ∨ logical or
    '\u00ac',  # ¬ not sign
    '\u22a5',  # ⊥ bottom / up tack
    '\u22a4',  # ⊤ top / down tack
    '\u2261',  # ≡ identical to
    '\u2282',  # ⊂ subset of
    '\u2283',  # ⊃ superset of
    '\u222b',  # ∫ integral
    '\u2218',  # ∘ ring operator (function composition)
    '\u2026',  # … horizontal ellipsis
    '\u2502',  # │ box drawing vertical
    '\u2500',  # ─ box drawing horizontal
    '\u250c',  # ┌ box drawing top-left
    '\u2510',  # ┐ box drawing top-right
    '\u2514',  # └ box drawing bottom-left
    '\u2518',  # ┘ box drawing bottom-right
    '\u251c',  # ├ box drawing vertical-right
    '\u2524',  # ┤ box drawing vertical-left
    '\u2534',  # ┴ box drawing horizontal-up
    '\u252c',  # ┬ box drawing horizontal-down
    '\u253c',  # ┼ box drawing cross
}

CJK_RANGES = [
    (0x3000, 0x303F),    # CJK punctuation
    (0x3040, 0x309F),    # Hiragana
    (0x30A0, 0x30FF),    # Katakana
    (0x4E00, 0x9FFF),    # CJK Unified Ideographs
    (0xFF00, 0xFFEF),    # Fullwidth forms
]

# Additional ranges for monospace/code fonts (symbols that appear in code contexts)
CODE_EXTRA_RANGES = [
    (0x2190, 0x21FF),    # Arrows (→ ← ↑ ↓ etc.)
    (0x2200, 0x22FF),    # Mathematical Operators (∀ ∃ ≠ ≤ ≥ ∈ etc.)
    (0x2300, 0x23FF),    # Miscellaneous Technical (⌘ ⏎ etc.)
    (0x2500, 0x257F),    # Box Drawing (┌ ─ │ etc.)
    (0x2580, 0x259F),    # Block Elements (█ ▄ etc.)
]

# Combined ranges for monospace fonts (need Latin, CJK, and code symbols)
MONO_RANGES = LATIN_RANGES + CJK_RANGES + CODE_EXTRA_RANGES

# Font configurations: font filename -> unicode ranges to scan for
# Note: Blobmoji is NOT subsetted (handled by blobmoji/build-subset.py)
FONTS = {
    "OradanoGSRR.woff2": {"ranges": CJK_RANGES, "always_include": set()},
    # IM Fell English — body text
    # Manicules (☜ ☞) included: used in card notice widget, from the same typeface
    "IMFellEnglish-Regular.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE | {'\u261C', '\u261E'}},
    "IMFellEnglish-Italic.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellEnglish-SC.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    # IM Fell Great Primer — subheadings (h3, h4)
    "IMFellGreatPrimer-Regular.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellGreatPrimer-Italic.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellGreatPrimer-SC.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    # IM Fell Double Pica — headings (h1, h2)
    "IMFellDoublePica-Regular.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellDoublePica-Italic.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellDoublePica-SC.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    # IM Fell DW Pica — small UI text
    "IMFellDWPica-Regular.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellDWPica-Italic.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "IMFellDWPica-SC.woff2": {"ranges": LATIN_RANGES, "always_include": LATIN_ALWAYS_INCLUDE},
    "SarasaMonoJ-Regular.woff2": {"ranges": MONO_RANGES, "always_include": MONO_ALWAYS_INCLUDE},
    "SarasaMonoJ-Bold.woff2": {"ranges": MONO_RANGES, "always_include": MONO_ALWAYS_INCLUDE},
}


def in_ranges(char, ranges):
    """Check if character is in any of the given unicode ranges."""
    cp = ord(char)
    return any(start <= cp <= end for start, end in ranges)


def scan_content(ranges):
    """Scan content/ and src/ for characters in given ranges."""
    found = set()

    for pattern in ["content/**/*.md", "src/**/*.hs"]:
        for f in PROJECT_ROOT.glob(pattern):
            try:
                text = f.read_text()
                for char in text:
                    if in_ranges(char, ranges):
                        found.add(char)
            except Exception as e:
                print(f"  Warning: Could not read {f}: {e}")

    return found


def compute_hash(chars, source_path):
    """Compute hash of character set and source font mtime for cache validation."""
    # Sort codepoints for deterministic hash
    sorted_codepoints = sorted(ord(c) for c in chars)
    content = ",".join(str(cp) for cp in sorted_codepoints)
    # Include source font mtime so edits to the font itself bust the cache
    mtime = str(os.path.getmtime(source_path))
    content = content + "|" + mtime
    return hashlib.sha256(content.encode()).hexdigest()[:16]


def load_cache():
    """Load cached hashes from file."""
    if not HASH_FILE.exists():
        return {}
    try:
        return json.loads(HASH_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def save_cache(cache):
    """Save hashes to cache file."""
    HASH_FILE.write_text(json.dumps(cache, indent=2))


def subset_font(source, target, codepoints):
    """Create subset using pyftsubset."""
    if not codepoints:
        print(f"  [WARN] No characters found for {source.name} — subsetting to space only")
        codepoints = {" "}

    unicodes = ",".join(f"U+{ord(c):04X}" for c in codepoints)

    cmd = [
        "pyftsubset",
        str(source),
        f"--unicodes={unicodes}",
        "--flavor=woff2",
        f"--output-file={target}",
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"  Error running pyftsubset: {e.stderr.decode()}")
        sys.exit(1)
    except FileNotFoundError:
        print("  Error: pyftsubset not found. Install with: cd config && uv sync")
        sys.exit(1)


def main():
    if not FONTS_SRC.exists():
        print(f"Error: fonts-src directory not found: {FONTS_SRC}")
        sys.exit(1)

    FONTS_OUT.mkdir(parents=True, exist_ok=True)

    cache = load_cache()
    updated = False

    for font_name, config in FONTS.items():
        source = FONTS_SRC / font_name
        target = FONTS_OUT / font_name

        if not source.exists():
            print(f"Warning: {source} not found, skipping")
            continue

        # Scan for characters
        chars = scan_content(config["ranges"])
        chars = chars | config.get("always_include", set())
        current_hash = compute_hash(chars, source)

        # Check cache
        cached_hash = cache.get(font_name)
        if cached_hash == current_hash and target.exists():
            print(f"Skipping {font_name} (cache hit: {current_hash})")
            continue

        print(f"Processing {font_name}...")
        print(f"  Found {len(chars)} characters (hash: {current_hash})")

        subset_font(source, target, chars)

        orig_size = source.stat().st_size
        new_size = target.stat().st_size
        reduction = (1 - new_size / orig_size) * 100

        print(f"  {orig_size:,} -> {new_size:,} bytes ({reduction:.1f}% reduction)")

        cache[font_name] = current_hash
        updated = True

    if updated:
        save_cache(cache)

    print("Done.")


if __name__ == "__main__":
    main()
