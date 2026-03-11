-- =============================================================================
-- Transforms
-- Re-exports all Pandoc AST transformations and provides combined transform
-- =============================================================================

module Transforms
  ( -- * Combined transform
    allTransforms
    -- * Individual transforms (re-exported)
  , imageDimensionsTransform
  , japaneseTransform
  , emojiTransform
  , anchorTransform
  , admonitionTransform
  , chatTransform
  , forumPostTransform
  , cardTransform
  , cardNoticeTransform
  , figureLinkTransform
  ) where

import Text.Pandoc.Definition (Pandoc)
import Config (AdmonitionConfig, AvatarConfig)
import CardCache (CardCache)
import Emoji (EmojiAssets)
import ImageDimensions (ImageDimensions)

-- Re-export individual transforms
import Transforms.ImageDimensions (imageDimensionsTransform)
import Transforms.Japanese (japaneseTransform)
import Transforms.Emoji (emojiTransform)
import Transforms.Anchors (anchorTransform)
import Transforms.Admonitions (admonitionTransform)
import Transforms.Chat (chatTransform)
import Transforms.ForumPost (forumPostTransform)
import Transforms.Cards (cardTransform)
import Transforms.CardNotice (cardNoticeTransform)
import Transforms.FigureLink (figureLinkTransform)

-- | Combined transform that applies all transformations
-- Config loaded from config/*.toml and config/*.json files
-- Order matters:
--   1. forumPostTransform - convert forum-post/forum-reply divs
--   2. chatTransform - convert chat divs to message bubbles
--   3. admonitionTransform - convert fenced divs to admonition structure
--   4. cardNoticeTransform - expand :::cards::: into notice
--      (must precede cardTransform: its output contains a .card span for the
--       Thalia example, which cardTransform needs to resolve into a preview)
--   5. cardTransform - convert .card spans to hover previews (produces Image nodes)
--   6. imageDimensionsTransform - add width/height for CLS prevention
--      (must follow cardTransform: card previews use native Image nodes that
--       need dimensions injected from the cache)
--   7. anchorTransform - headings become clickable anchors
--   8. figureLinkTransform - make figure images clickable to full size
--   9. emojiTransform - replace emoji chars with inline SVG images
--      (must follow cardTransform/cardNoticeTransform which inject emoji,
--       must precede japaneseTransform so emoji aren't wrapped in lang="ja")
--  10. japaneseTransform - wrap CJK text (runs last to process all text)
--
-- Note: Figures are handled by Pandoc's implicit_figures extension.
-- Use ![Caption](image){alt="accessibility text"} syntax.
allTransforms :: AdmonitionConfig -> AvatarConfig -> CardCache -> ImageDimensions -> EmojiAssets -> Pandoc -> Pandoc
allTransforms admonitionConfig avatarConfig cardCache imageDims emojiAssets =
  japaneseTransform
  . emojiTransform emojiAssets
  . figureLinkTransform
  . anchorTransform
  . imageDimensionsTransform imageDims
  . cardTransform cardCache
  . cardNoticeTransform
  . admonitionTransform admonitionConfig
  . chatTransform avatarConfig
  . forumPostTransform avatarConfig
