-- =============================================================================
-- Image Dimensions Transform
-- Adds width/height attributes to images for CLS prevention.
--
-- Uses dimensions scanned at build time by ImageDimensions.scanImageDimensions.
-- Only adds dimensions if not already present in the markdown.
-- =============================================================================

module Transforms.ImageDimensions (imageDimensionsTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as Text
import ImageDimensions (ImageDimensions, lookupDimensions, Dimensions(..))

-- | Add width/height to an Image if not already present
addDimensions :: ImageDimensions -> Inline -> Inline
addDimensions cache img@(Image (identifier, classes, attributes) alt (url, title))
  | hasKey "width" attributes || hasKey "height" attributes = img
  | otherwise = case lookupDimensions url cache of
      Nothing -> img
      Just dimensions ->
        let newAttributes = attributes ++
              [ ("width",  Text.pack $ show $ dimensionWidth dimensions)
              , ("height", Text.pack $ show $ dimensionHeight dimensions)
              ]
        in Image (identifier, classes, newAttributes) alt (url, title)
addDimensions _ x = x

hasKey :: Text -> [(Text, Text)] -> Bool
hasKey k = any ((== k) . fst)

imageDimensionsTransform :: ImageDimensions -> Pandoc -> Pandoc
imageDimensionsTransform cache = walk (addDimensions cache)
