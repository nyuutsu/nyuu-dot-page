"""
Prepares the IM Fell italics' swashes, just before font-subset.py subsets them:

  limit_end_forms_to_sentence_ends    the swash k and tailed e only before . ! ?, where the flourish has room
  rename_as_modified                  the licence reserves the name "IM FELL" for the fonts as published
"""

import copy
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables

SENTENCE_ENDINGS = ".!?"

# Each end-of-word form, keyed by the letter it replaces
END_FORMS = {"k": "k.swash", "kcommaaccent": "kcommaaccent.swash", "e": "e.end"}

RESERVED_NAME = "IM FELL"
OUR_NAME = "Nyuu Fell"


# -----------------------------------------------------------------------------
# Building blocks for substitution lookups
# -----------------------------------------------------------------------------

def glyph_coverage(font: TTFont, glyph_names: list[str]) -> otTables.Coverage:
    coverage = otTables.Coverage()
    coverage.glyphs = sorted(set(glyph_names), key=font.getGlyphID)  # the format requires glyph-id order
    return coverage


def new_lookup(lookup_type: int, subtables: list) -> otTables.Lookup:
    lookup = otTables.Lookup()
    lookup.LookupType = lookup_type
    lookup.LookupFlag = 0
    lookup.SubTable = subtables
    lookup.SubTableCount = len(subtables)
    return lookup


def single_substitution(mapping: dict[str, str]) -> otTables.Lookup:
    subtable = otTables.SingleSubst()
    subtable.mapping = dict(mapping)
    return new_lookup(1, [subtable])


def substitution_before(font: TTFont, letters: list[str], following: list[str], substitution_index: int) -> otTables.Lookup:
    """A lookup that applies the lookup at substitution_index to these letters, only when one of `following` comes next."""
    record = otTables.SubstLookupRecord()
    record.SequenceIndex = 0
    record.LookupListIndex = substitution_index
    subtable = otTables.ChainContextSubst()
    subtable.Format = 3
    subtable.BacktrackCoverage = []
    subtable.InputCoverage = [glyph_coverage(font, letters)]
    subtable.LookAheadCoverage = [glyph_coverage(font, following)]
    subtable.BacktrackGlyphCount = 0
    subtable.InputGlyphCount = 1
    subtable.LookAheadGlyphCount = 1
    subtable.SubstLookupRecord = [record]
    subtable.SubstCount = 1
    return new_lookup(6, [subtable])


def unwrapped_subtables(lookup: otTables.Lookup) -> list:
    """A lookup's subtables, looking through the extension wrapper that large fonts put around them."""
    if lookup.LookupType == 7:
        return [subtable.ExtSubTable for subtable in lookup.SubTable]
    return list(lookup.SubTable)


def append_lookup(substitutions: otTables.GSUB, lookup: otTables.Lookup) -> int:
    substitutions.LookupList.Lookup.append(lookup)
    substitutions.LookupList.LookupCount = len(substitutions.LookupList.Lookup)
    return len(substitutions.LookupList.Lookup) - 1


def lookups_of_feature(substitutions: otTables.GSUB, tag: str) -> list[int]:
    return sorted({index
                   for feature_record in substitutions.FeatureList.FeatureRecord if feature_record.FeatureTag == tag
                   for index in feature_record.Feature.LookupListIndex})


# -----------------------------------------------------------------------------
# The steps
# -----------------------------------------------------------------------------

def limit_end_forms_to_sentence_ends(font: TTFont) -> bool:
    """The swash feature swaps every k and e for its flourished form;
    keep the capitals as they are, and the end forms only before . ! ?, the open space a compositor would have saved them for."""
    substitutions = font["GSUB"].table
    swash_lookups = lookups_of_feature(substitutions, "swsh")
    glyph_order = set(font.getGlyphOrder())
    end_forms = {letter: form for letter, form in END_FORMS.items() if letter in glyph_order and form in glyph_order}
    if not swash_lookups or not end_forms:
        return False
    capitals = copy.deepcopy(substitutions.LookupList.Lookup[swash_lookups[0]])  # a copy: the original also serves 'salt'
    for subtable in unwrapped_subtables(capitals):
        for letter in end_forms:
            subtable.mapping.pop(letter, None)
    characters = font.getBestCmap()
    sentence_endings = [characters[ord(mark)] for mark in SENTENCE_ENDINGS if ord(mark) in characters]
    to_end_form = append_lookup(substitutions, single_substitution(end_forms))
    end_form_rule = append_lookup(substitutions, substitution_before(font, list(end_forms), sentence_endings, to_end_form))
    capitals_index = append_lookup(substitutions, capitals)
    for feature_record in substitutions.FeatureList.FeatureRecord:
        if feature_record.FeatureTag == "swsh":
            feature_record.Feature.LookupListIndex = [capitals_index, end_form_rule]
            feature_record.Feature.LookupCount = 2
    return True


def rename_as_modified(font: TTFont) -> None:
    for record in font["name"].names:
        if record.nameID in (1, 3, 4, 6, 16):
            text = record.toUnicode()
            record.string = text.replace(RESERVED_NAME, OUR_NAME).replace(RESERVED_NAME.replace(" ", "_"), OUR_NAME.replace(" ", "_"))


# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------

def prepare_swashes(source: Path, destination: Path) -> None:
    font = TTFont(source, recalcTimestamp=False)  # same input, same bytes: a font's URL stamp changes only when the font does
    if limit_end_forms_to_sentence_ends(font):
        rename_as_modified(font)
    font.flavor = "woff2"
    font.save(destination)
