-- =============================================================================
-- Card Transform
-- Converts [Card Name]{.card} into hoverable card previews
--
-- Syntax:
--   [Card Name]{.card}
--   [Card Name]{.card set="base1"}     (for Pokemon reprints)
--   [Card Name]{.card source="mtg"}    (disambiguate between franchises)
--   [Card Name]{.card source="yugioh"} (if MTG/YGO share a name)
--
-- Looks up image and alt text from the card cache built at startup
-- by CardCache.buildCardCache (loads config/{pokemon,yugioh,mtg}/*.json).
-- =============================================================================

module Transforms.Cards (cardTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as T
import Debug.Trace (trace)
import CardCache (CardCache, lookupCard, CardData(..))
import Text.Pandoc.Shared (stringify)

-- | Normalize smart quotes to straight quotes
-- Pandoc's smart typography converts ' to ' (U+2019) etc.
-- Our cache uses straight quotes, so normalize before lookup.
normalizeQuotes :: Text -> Text
normalizeQuotes = T.map normalize
  where
    normalize '\x2019' = '\''  -- right single quote -> apostrophe
    normalize '\x2018' = '\''  -- left single quote -> apostrophe
    normalize '\x201C' = '"'   -- left double quote -> straight
    normalize '\x201D' = '"'   -- right double quote -> straight
    normalize c = c

-- | Build card preview HTML
-- setCode: Pokemon set code (e.g., "base1")
-- source: Franchise (e.g., "mtg", "yugioh", "pokemon") for disambiguation
buildCardPreview :: CardCache -> Text -> Maybe Text -> Maybe Text -> [Inline]
buildCardPreview cache rawName setCode source =
    let -- Normalize smart quotes for cache lookup (Pandoc converts ' -> ')
        name = normalizeQuotes rawName

        -- Build lookup key: set:name > source:name > name
        lookupKey = case setCode of
            Just s  -> s <> ":" <> name
            Nothing -> case source of
                Just franchise -> franchise <> ":" <> name
                Nothing  -> name

        cached = lookupCard lookupKey cache

        imagePath = case cached >>= cardImage of
            Just p  -> "/images/cards/" <> p
            Nothing -> trace (T.unpack $ "[WARN] Card '" <> lookupKey <> "' not found in cache.")
                             "/images/cards/MISSING.png"

        altText = maybe "" cardAltText cached
        hanafuda = Span ("", ["hanafuda"], [("aria-hidden", "true")]) [Str "🎴"]
        nameElement = Span ("", ["card-name"], []) [Str name]
        previewImage = Image ("", ["card-image"], [("loading", "eager"), ("decoding", "async")])
                             [Str altText] (imagePath, "")

    in [Span ("", ["card-preview"], []) [hanafuda, nameElement, previewImage]]

-- | Transform a single inline, returning one or more inlines
-- Card spans expand to multiple inlines; everything else passes through.
transformInline :: CardCache -> Inline -> [Inline]
transformInline cache (Span (_ident, classes, attributes) text)
  | "card" `elem` classes =
      let name = stringify text
          setCode = lookup "set" attributes
          source  = lookup "source" attributes
      in buildCardPreview cache name setCode source
transformInline _ x = [x]

cardTransform :: CardCache -> Pandoc -> Pandoc
cardTransform cache = walk (concatMap (transformInline cache))
