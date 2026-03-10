-- =============================================================================
-- Figure Link Transform
-- Makes .clickable images inside <figure> clickable, linking to full size.
--
-- Pandoc's implicit_figures extension wraps standalone images in <figure>.
-- This transform finds images with the "clickable" class and wraps them
-- in a link to their own URL, preserving the figure and caption.
--
-- Usage in markdown:
--   ![Caption](image.png){alt="description" .clickable}
-- =============================================================================

module Transforms.FigureLink (figureLinkTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition

-- | Only linkify figures whose image has the "clickable" class
-- Adds "clickable" class to the figure itself for CSS targeting
linkifyFigureImage :: Block -> Block
linkifyFigureImage (Figure (figureId, figureClasses, figureKeyValues) caption blocks) =
  let newBlocks = map linkifyBlock blocks
      hasClickable = any blockHasClickable newBlocks
      updatedClasses = if hasClickable then "clickable" : figureClasses else figureClasses
  in Figure (figureId, updatedClasses, figureKeyValues) caption newBlocks
linkifyFigureImage block = block

blockHasClickable :: Block -> Bool
blockHasClickable (Plain inlines) = any isLinkedImage inlines
blockHasClickable (Para inlines)  = any isLinkedImage inlines
blockHasClickable _               = False

isLinkedImage :: Inline -> Bool
isLinkedImage (Link _ [Image {}] _) = True
isLinkedImage _                     = False

linkifyBlock :: Block -> Block
linkifyBlock (Plain inlines) = Plain (map linkifyInline inlines)
linkifyBlock (Para inlines)  = Para (map linkifyInline inlines)
linkifyBlock block = block

linkifyInline :: Inline -> Inline
linkifyInline (Image (identifier, classes, attributes) alt (url, title))
  | "clickable" `elem` classes =
      let cleanClasses = filter (/= "clickable") classes
          cleanImage = Image (identifier, cleanClasses, attributes) alt (url, title)
      in Link ("", [], []) [cleanImage] (url, title)
linkifyInline inline = inline

figureLinkTransform :: Pandoc -> Pandoc
figureLinkTransform = walk linkifyFigureImage
