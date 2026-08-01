-- =============================================================================
-- Dropcap — wrap a page's opening paragraph so CSS can drop-cap its first letter.
--
-- Opt-in per page: the `dropcap: true` flag lives in Hakyll metadata, invisible to a pure
-- transform, so site.hs composes this in per page rather than through allTransforms.
-- =============================================================================

module Transforms.Dropcap (dropcapTransform) where

import Data.Char (isAsciiLower, isAsciiUpper, toLower)
import Data.Text qualified as T
import Debug.Trace (trace)
import Text.Pandoc.Definition
import Text.Pandoc.Shared (stringify)

-- | Below this, a three-line versal outruns its own paragraph and dangles.
minimumWords :: Int
minimumWords = 40

dropcapTransform :: Pandoc -> Pandoc
dropcapTransform (Pandoc meta blocks) = Pandoc meta (wrapOpening blocks)

-- | Cap the first top-level paragraph, or nothing: a versal marks where the text opens, not just any paragraph.
wrapOpening :: [Block] -> [Block]
wrapOpening [] = trace "[dropcap] page opted in but has no paragraph to cap" []
wrapOpening (Para inlines : rest) =
  case qualify inlines of
    Right letter ->
      Div ("", ["dropcap", "dropcap-" <> T.singleton letter], []) [Para inlines] : rest
    Left reason ->
      trace ("[dropcap] opening paragraph not capped: " <> reason) (Para inlines : rest)
wrapOpening (block : rest) = block : wrapOpening rest

-- | Returns the (lowercased) versal letter, or the reason there is none.
qualify :: [Inline] -> Either String Char
qualify inlines = case inlines of
  (Str text : _)
    | Just (firstChar, _) <- T.uncons text
    , isAsciiUpper firstChar || isAsciiLower firstChar ->
        if wordCount >= minimumWords
          then Right (toLower firstChar)
          else Left ("only " <> show wordCount <> " words; the float needs " <> show minimumWords)
    | otherwise -> Left "does not start with a plain ASCII letter"
  _ -> Left "does not start with plain text"
  where
    wordCount = length (T.words (stringify inlines))
