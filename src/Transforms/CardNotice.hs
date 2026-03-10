-- =============================================================================
-- Card Notice Transform
-- Converts :::cards::: into an explanatory notice about card hover previews
--
-- Syntax:
--   ::: cards
--   :::
--
-- Output: A notice box explaining the hanafuda symbol and hover behavior,
-- with a Thalia example card and details about click-to-visit and alt text.
-- =============================================================================

module Transforms.CardNotice (cardNoticeTransform, exampleCardName) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as T
import Data.List (intersperse, intercalate)

-- | Convert text into Pandoc inlines (words become Str separated by Space)
textToInlines :: Text -> [Inline]
textToInlines = intersperse Space . map Str . T.words

-- | Join inline fragments with spaces
joinInlines :: [[Inline]] -> [Inline]
joinInlines = intercalate [Space]

-- | The example card used in the notice widget.
-- Exported so CardCache.alwaysInclude can reference it by name.
exampleCardName :: Text
exampleCardName = "Thalia, Guardian of Thraben"

-- | The example card - just a .card span, Cards.hs handles the rest
thaliaExample :: Inline
thaliaExample = Span ("", ["card"], [])
  (textToInlines exampleCardName)

-- | The notice content
noticeContent :: [Block]
noticeContent =
  [ Para $ joinInlines
    [ [Str "☞"]
    , textToInlines "This post contains ✨on-hover card images✨, indicated by the hanafuda symbol"
    , [Span ("", ["hanafuda"], []) [Str "🎴"], Str ","]
    , textToInlines "like so:"
    , [thaliaExample]
    , [Str "☜"]
    ]
  , Div ("", ["card-notice-details"], [])
    [ Para $ textToInlines "Alt text contains card data for screen readers."
    ]
  ]

-- | Transform div
transformDiv :: Block -> Block
transformDiv (Div (_, classes, _) _)
  | "cards" `elem` classes = Div ("", ["card-notice"], []) noticeContent
transformDiv x = x

-- | Apply transform
cardNoticeTransform :: Pandoc -> Pandoc
cardNoticeTransform = walk transformDiv