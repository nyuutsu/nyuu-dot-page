-- =============================================================================
-- Emoji Transform
-- Replaces emoji characters in text with inline SVG images + hidden selectable
-- text, so emoji render consistently across platforms (including mobile).
--
-- Runs after all other transforms that might inject emoji (Cards, CardNotice)
-- and before japaneseTransform (so emoji aren't wrapped in lang="ja" spans).
--
-- Variation selectors (U+FE0F) following an emoji are consumed silently —
-- the base codepoint determines the SVG filename.
-- =============================================================================

module Transforms.Emoji (emojiTransform) where

import Data.Char (ord)
import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Text (Text)
import Numeric (showHex)
import Text.Pandoc.Definition
import Text.Pandoc.Walk (walk)

import Emoji (EmojiAssets)

-- | Replace emoji characters in Str nodes with inline SVG images
emojiTransform :: EmojiAssets -> Pandoc -> Pandoc
emojiTransform assets = walk (concatMap (transformInline assets))

transformInline :: EmojiAssets -> Inline -> [Inline]
transformInline assets (Str txt) = processText assets txt
transformInline _ x = [x]

-- | Build a Pandoc AST node for an inline emoji: an <img> pointing at the
-- Blobmoji SVG plus a hidden <span> with the real character for copy-paste.
emojiInline :: Char -> Inline
emojiInline c =
  let hex = T.pack (showHex (ord c) "")
      ch  = T.singleton c
      src = "/images/emoji/" <> hex <> ".svg"
      img = Image ("", ["emoji-img"], [("draggable", "false")]) [Str ch] (src, "")
      hiddenText = Span ("", ["emoji-text"], [("aria-hidden", "true")]) [Str ch]
  in Span ("", ["emoji"], []) [img, hiddenText]

-- | Split a text string around emoji characters, producing a mix of
-- Str nodes (regular text) and emoji Span/Image nodes.
processText :: EmojiAssets -> Text -> [Inline]
processText assets = go T.empty
  where
    go buffer txt = case T.uncons txt of
      Nothing -> flush buffer []
      Just (c, rest)
        | Set.member (ord c) assets ->
            let rest' = stripVariationSelector rest
            in flush buffer (emojiInline c : go T.empty rest')
        | otherwise ->
            go (T.snoc buffer c) rest

    flush buffer rest
      | T.null buffer = rest
      | otherwise     = Str buffer : rest

    stripVariationSelector t = case T.uncons t of
      Just ('\xFE0F', r) -> r
      _ -> t
