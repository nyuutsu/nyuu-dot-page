-- =============================================================================
-- Japanese Text Transform
-- Wraps CJK text runs in <span lang="ja"> for accessibility
-- Also handles ruby/furigana syntax: {漢|かん}{字|じ}
--
-- Screen readers need lang attribute to pronounce Japanese correctly.
-- Ruby syntax provides compact furigana markup without raw HTML.
--
-- Syntax: {kanji|reading}
-- Example: {漢|かん}{字|じ}を勉強する
-- Output: <span lang="ja"><ruby>漢<rt>かん</rt></ruby><ruby>字<rt>じ</rt></ruby>を勉強する</span>
-- =============================================================================

module Transforms.Japanese (japaneseTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Char (ord)
import Data.List (groupBy)
import Data.Function (on)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char (char)

type Parser = Parsec Void Text

-- | Escape text for safe interpolation into raw HTML (ruby annotations)
escapeHtml :: Text -> Text
escapeHtml = Text.concatMap escape
  where
    escape '&'  = "&amp;"
    escape '<'  = "&lt;"
    escape '>'  = "&gt;"
    escape '"'  = "&quot;"
    escape '\'' = "&#39;"
    escape c    = Text.singleton c

-- | Detect if a character is in CJK ranges (Japanese, Chinese, Korean)
-- Covers: CJK Symbols, Hiragana, Katakana, CJK Unified Ideographs, Fullwidth
isCJK :: Char -> Bool
isCJK c = let n = ord c in
  (n >= 0x3000 && n <= 0x30FF) ||  -- CJK Symbols, Hiragana, Katakana
  (n >= 0x31F0 && n <= 0x31FF) ||  -- Katakana Phonetic Extensions
  (n >= 0x4E00 && n <= 0x9FFF) ||  -- CJK Unified Ideographs
  (n >= 0xFF00 && n <= 0xFFEF)     -- Halfwidth and Fullwidth Forms

-- =============================================================================
-- Segment types
-- =============================================================================

-- | A segment is either plain text, CJK text, or a ruby annotation
data Segment
  = PlainText !Text      -- Non-CJK text
  | CJKText !Text        -- CJK text (to be wrapped in lang="ja")
  | Ruby !Text !Text     -- Ruby: base text and reading
  deriving (Show, Eq)

-- | Check if a segment should be grouped into a Japanese span
isJapaneseSegment :: Segment -> Bool
isJapaneseSegment (CJKText _) = True
isJapaneseSegment (Ruby _ _) = True
isJapaneseSegment _ = False

-- =============================================================================
-- Segment parser
-- =============================================================================

-- | Ruby annotation: {base|reading}
rubyP :: Parser Segment
rubyP = do
  _ <- char '{'
  base    <- takeWhile1P (Just "ruby base") (\c -> c /= '|' && c /= '}')
  _ <- char '|'
  reading <- takeWhile1P (Just "ruby reading") (/= '}')
  _ <- char '}'
  return $ Ruby base reading

-- | Run of CJK characters
cjkRunP :: Parser Segment
cjkRunP = CJKText <$> takeWhile1P (Just "CJK text") isCJK

-- | Run of non-CJK, non-brace characters
plainRunP :: Parser Segment
plainRunP = PlainText <$> takeWhile1P (Just "plain text") (\c -> not (isCJK c) && c /= '{')

-- | A { that didn't start a valid ruby pattern (try rubyP backtracks here)
literalBraceP :: Parser Segment
literalBraceP = PlainText . Text.singleton <$> char '{'

-- | One segment: try ruby first (backtracking on failure), then CJK, plain, or literal brace
segmentP :: Parser Segment
segmentP = try rubyP <|> cjkRunP <|> plainRunP <|> literalBraceP

-- | Parse text into segments
parseSegments :: Text -> [Segment]
parseSegments t = case parse (many segmentP <* eof) "" t of
  Right segs -> segs
  Left _     -> [PlainText t]  -- unreachable: alternatives cover all characters

-- =============================================================================
-- Segment → Inline conversion
-- =============================================================================

-- | Convert a segment to an Inline element
segmentToInline :: Segment -> Inline
segmentToInline (PlainText t) = Str t
segmentToInline (CJKText t) = Str t
segmentToInline (Ruby base reading) =
  RawInline "html" $
    "<ruby>" <> escapeHtml base <> "<rt>" <> escapeHtml reading <> "</rt></ruby>"

-- | Group consecutive Japanese segments together
groupJapanese :: [Segment] -> [[Segment]]
groupJapanese = groupBy ((==) `on` isJapaneseSegment)

-- | Convert a group of segments to Inlines, wrapping Japanese in lang="ja"
groupToInlines :: [Segment] -> [Inline]
groupToInlines [] = []
groupToInlines segs
  | all isJapaneseSegment segs =
      -- All Japanese: wrap in a single span
      [Span ("", [], [("lang", "ja")]) (map segmentToInline segs)]
  | otherwise =
      -- Non-Japanese: just convert directly
      map segmentToInline segs

-- | Process a text string into properly grouped Inlines
processText :: Text -> [Inline]
processText t =
  let segments = parseSegments t
      groups = groupJapanese segments
  in concatMap groupToInlines groups

-- =============================================================================
-- Transform entry point
-- =============================================================================

-- | Process an inline element, handling text nodes
wrapCJK :: Inline -> [Inline]
wrapCJK (Str t) = processText t
wrapCJK x = [x]

-- | Apply Japanese text wrapping to entire document
japaneseTransform :: Pandoc -> Pandoc
japaneseTransform = walk (concatMap wrapCJK)