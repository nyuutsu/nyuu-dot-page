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
import qualified Data.Text as Text
import Debug.Trace (trace)
import CardCache (CardCache, lookupCard, CardData(..), normalizeQuotes)
import Text.Pandoc.Shared (stringify)

-- | Build card preview HTML
-- setCode: Pokemon set code (e.g., "base1")
-- source: Franchise (e.g., "mtg", "yugioh", "pokemon") for disambiguation
buildCardPreview :: CardCache -> Text -> Maybe Text -> Maybe Text -> [Inline]
buildCardPreview cache rawName setCode source =
    [Span ("", ["card-preview"], []) [hanafuda, nameElement, previewImage]]
  where
    -- Normalize smart quotes for cache lookup (Pandoc converts ' -> ')
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
        Nothing -> trace (Text.unpack $ "[WARN] Card '" <> lookupKey <> "' not found in cache.")
                         "/images/cards/MISSING.webp"

    altText = maybe "" cardAltText cached
    hanafuda = Span ("", ["hanafuda"], [("aria-hidden", "true")]) [Str "🎴"]
    nameElement = Span ("", ["card-name"], []) [Str name]
    previewImage = Image ("", ["card-image"], [("loading", "eager"), ("decoding", "async")])
                         [Str altText] (imagePath, "")

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
