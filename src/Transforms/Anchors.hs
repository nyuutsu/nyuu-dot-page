-- =============================================================================
-- Header Anchor Transform
-- Wraps heading content in clickable anchor links
--
-- ## Section Title
-- becomes:
-- <h2 id="section-title"><a href="#section-title">Section Title</a></h2>
--
-- CSS can then add § prefix via ::before
-- =============================================================================

module Transforms.Anchors (anchorTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import qualified Data.Text as Text

-- | Wrap header content in an anchor link pointing to the header's id
-- Only processes headers that have an id (Pandoc auto-generates these)
headerToAnchor :: Block -> Block
headerToAnchor (Header level attr@(idAttr, _, _) inlines)
  | not (Text.null idAttr) =
      -- Create a link with the header id as target
      let link = Link ("", [], []) inlines ("#" <> idAttr, "")
      in Header level attr [link]
headerToAnchor x = x

-- | Apply header anchor transformation to entire document
anchorTransform :: Pandoc -> Pandoc
anchorTransform = walk headerToAnchor
