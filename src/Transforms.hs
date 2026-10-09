-- =============================================================================
-- Transforms
-- Every Pandoc transform, and the pipeline that runs them.
-- =============================================================================

module Transforms
  ( -- * Combined transform
    allTransforms
    -- * Individual transforms
  , imageDimensionsTransform
  , japaneseTransform
  , emojiTransform
  , anchorTransform
  , admonitionTransform
  , chatTransform
  , companionExcerptTransform
  , forumPostTransform
  , cardTransform
  , cardNoticeTransform
  , figureLinkTransform
  , tableTransform
    -- * Per-page transforms, which site.hs applies only where a page asks
  , dropcapTransform
  ) where

import Text.Pandoc.Definition (Pandoc)
import Config (AdmonitionConfig, AvatarConfig)
import CardCache (CardCache)
import Emoji (EmojiAssets)
import ImageDimensions (ImageDimensions)

import Transforms.ImageDimensions (imageDimensionsTransform)
import Transforms.Japanese (japaneseTransform)
import Transforms.Emoji (emojiTransform)
import Transforms.Anchors (anchorTransform)
import Transforms.Admonitions (admonitionTransform)
import Transforms.Chat (chatTransform)
import Transforms.CompanionExcerpt (companionExcerptTransform)
import Transforms.ForumPost (forumPostTransform)
import Transforms.Cards (cardTransform)
import Transforms.CardNotice (cardNoticeTransform)
import Transforms.FigureLink (figureLinkTransform)
import Transforms.Tables (tableTransform)
import Transforms.Dropcap (dropcapTransform)

-- | Every transform a page gets. Composition runs right to left, so read the chain from the bottom up.
-- Some must run in order:
--   cardNoticeTransform before cardTransform: the notice's Thalia example is a .card span, which cardTransform resolves.
--   cardTransform before imageDimensionsTransform: card previews are Image nodes, waiting for their sizes from the cache.
--   emojiTransform after both card transforms, which add 🎴, and before japaneseTransform, so emoji aren't wrapped in lang="ja".
--   japaneseTransform last: it turns ruby into raw HTML and splits text into lang="ja" spans, and text a later transform adds would miss both.
allTransforms :: AdmonitionConfig -> AvatarConfig -> CardCache -> ImageDimensions -> EmojiAssets -> Pandoc -> Pandoc
allTransforms admonitionConfig avatarConfig cardCache imageDimensions emojiAssets =
  japaneseTransform
  . emojiTransform emojiAssets
  . companionExcerptTransform
  . tableTransform
  . figureLinkTransform
  . anchorTransform
  . imageDimensionsTransform imageDimensions
  . cardTransform cardCache
  . cardNoticeTransform
  . admonitionTransform admonitionConfig
  . chatTransform avatarConfig
  . forumPostTransform avatarConfig
