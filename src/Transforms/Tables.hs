-- =============================================================================
-- Tables Transform
-- Pandoc bakes inline column widths into any pipe table whose source rows overrun the writer's column budget,
-- and no stylesheet rule can override an inline style; resetting every column to ColWidthDefault hands layout back to the CSS.
-- Each table is also wrapped in <div class="table-wrap">, because a table cannot scroll sideways by itself:
-- the wrapper is where overflow-x lives, made focusable and named after the caption so a keyboard can reach it.
-- The first column is declared the row-label column, so screen readers announce it alongside each cell.
-- =============================================================================

{-# LANGUAGE OverloadedStrings #-}

module Transforms.Tables (tableTransform) where

import Data.Text (Text)
import Text.Pandoc.Walk (walk, query)
import Text.Pandoc.Definition

contentWidth :: ColSpec -> ColSpec
contentWidth (alignment, _) = (alignment, ColWidthDefault)

labelColumn :: TableBody -> TableBody
labelColumn (TableBody bodyAttr _ headRows rows) = TableBody bodyAttr (RowHeadColumns 1) headRows rows

captionText :: Caption -> Text
captionText (Caption _ blocks) = query inlineText blocks
  where
    inlineText (Str text) = text
    inlineText Space      = " "
    inlineText SoftBreak  = " "
    inlineText _          = ""

wrapTable :: Block -> Block
wrapTable (Table attr caption colSpecs tableHead tableBodies tableFoot) =
  Div ("", ["table-wrap"], wrapperAttrs)
    [Table attr caption (map contentWidth colSpecs) tableHead (map labelColumn tableBodies) tableFoot]
  where
    wrapperAttrs = case captionText caption of
      ""   -> [("tabindex", "0")]
      name -> [("tabindex", "0"), ("role", "region"), ("aria-label", name)]
wrapTable block = block

tableTransform :: Pandoc -> Pandoc
tableTransform = walk wrapTable
