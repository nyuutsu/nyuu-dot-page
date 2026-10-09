-- =============================================================================
-- Companion Excerpt Transform
-- Quotes a section of one of the companion sites into a page, with a credit line saying where it came from.
--
-- Syntax:
--   ::: companion-excerpt
--   ### 🪄 What this is
--   The section, as it reads on the companion.
--   :::
--
-- Other classes ride along, so {.companion-excerpt .to-editor} takes that page's colours.
--
-- Output: a quotation with its source, the way HTML marks one up.
--   <figure class="companion-excerpt">
--     <blockquote>...</blockquote>
--     <figcaption>from the companion site, btw</figcaption>
--   </figure>
-- =============================================================================

module Transforms.CompanionExcerpt (companionExcerptTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import qualified Data.Text as Text
import Data.List (intersperse)

companionExcerptTransform :: Pandoc -> Pandoc
companionExcerptTransform = walk excerptToFigure

credit :: Caption
credit = Caption Nothing [Plain (intersperse Space (map Str (Text.words "from the companion site, btw")))]

excerptToFigure :: Block -> Block
excerptToFigure (Div (identifier, classes, _) quoted)
  | "companion-excerpt" `elem` classes = Figure (identifier, classes, []) credit [BlockQuote quoted]
excerptToFigure block = block
