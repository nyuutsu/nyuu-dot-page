-- =============================================================================
-- Emoji Assets
-- Manages SVG emoji images: scans content for used emoji, copies SVGs from
-- the Blobmoji source library, and provides rendering functions.
--
-- Used by:
--   - Transforms.Emoji (Pandoc transform for inline emoji)
--   - site.hs (Hakyll context field for project card icons)
-- =============================================================================

module Emoji
  ( EmojiAssets
  , buildEmojiAssets
  ) where

import Control.Monad (guard, unless)
import Data.Char (ord)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Text as Text
import qualified Data.Text.IO as TIO
import Debug.Trace (trace)
import Numeric (showHex)
import FileUtils (findFiles)
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist,
                         listDirectory)
import System.FilePath ((</>), dropExtension, takeExtension)

-- | Set of emoji codepoints that have SVG assets available
type EmojiAssets = Set Int

-- | Codepoints to always copy even if not found in scanned content.
-- Needed for assets referenced from CSS (which isn't processed by the
-- Pandoc transform but still needs the SVG file).
alwaysIncluded :: Set Int
alwaysIncluded = Set.fromList
  [ 0x1F50D  -- 🔍 CSS background-image for clickable figure overlay
  ]

-- | Scan Blobmoji SVG library, copy used emoji to output, return available set.
buildEmojiAssets :: FilePath    -- ^ SVG source dir (config/blobmoji/svg-fixed)
                -> FilePath    -- ^ SVG output dir (static/images/emoji)
                -> [FilePath]  -- ^ Directories to scan for emoji usage
                -> IO EmojiAssets
buildEmojiAssets svgSourceDir svgDestDir scanDirs = do
  available <- scanAvailableSvgs svgSourceDir
  used      <- scanForEmoji scanDirs
  let assets = Set.intersection available (Set.union used alwaysIncluded)
  createDirectoryIfMissing True svgDestDir
  mapM_ (copySvg svgSourceDir svgDestDir) (Set.toList assets)
  return assets

-- | Parse SVG filenames to build set of available single-codepoint emoji
scanAvailableSvgs :: FilePath -> IO (Set Int)
scanAvailableSvgs dir = do
  files <- listDirectory dir
  return $ Set.fromList (mapMaybe parseSvgFilename files)
  where
    parseSvgFilename name = do
      let base = Text.pack (dropExtension name)
      guard (takeExtension name == ".svg")
      rest <- Text.stripPrefix "emoji_u" base
      guard (not (Text.any (== '_') rest))  -- single codepoint only
      readHexMaybe (Text.unpack rest)

-- | Recursively scan directories for emoji characters in source files
scanForEmoji :: [FilePath] -> IO (Set Int)
scanForEmoji dirs = do
  files <- concat <$> mapM (findFiles [".md", ".hs", ".scss"]) dirs
  contents <- mapM TIO.readFile files
  let allText = Text.concat contents
  return $ Text.foldl' (\codepoints character ->
    if isEmojiCodepoint (ord character)
      then Set.insert (ord character) codepoints
      else codepoints) Set.empty allText

-- | Copy a single emoji SVG, skipping if destination already exists
-- (avoids retriggering Hakyll's file watcher during make watch)
copySvg :: FilePath -> FilePath -> Int -> IO ()
copySvg srcDir dstDir codepoint = do
  let hex = codepointHex codepoint
      src = srcDir </> ("emoji_u" ++ hex ++ ".svg")
      dst = dstDir </> (hex ++ ".svg")
  dstExists <- doesFileExist dst
  unless dstExists $ do
    srcExists <- doesFileExist src
    if srcExists
      then copyFile src dst
      else trace ("[WARN] Emoji SVG missing: " ++ src) (return ())


-- ---- Helpers ----

data EmojiRange = EmojiRange
  { rangeStart :: !Int
  , rangeEnd   :: !Int
  }

-- | Check if a codepoint falls in an emoji Unicode range
isEmojiCodepoint :: Int -> Bool
isEmojiCodepoint codepoint = any inRange emojiRanges
  where inRange range = codepoint >= rangeStart range && codepoint <= rangeEnd range

emojiRanges :: [EmojiRange]
emojiRanges =
  [ EmojiRange 0x203C 0x203C, EmojiRange 0x2049 0x2049
  , EmojiRange 0x2122 0x2122, EmojiRange 0x2139 0x2139
  , EmojiRange 0x2194 0x2199, EmojiRange 0x21A9 0x21AA
  , EmojiRange 0x231A 0x231B, EmojiRange 0x2328 0x2328
  , EmojiRange 0x23CF 0x23CF, EmojiRange 0x23E9 0x23F3, EmojiRange 0x23F8 0x23FA
  , EmojiRange 0x24C2 0x24C2
  , EmojiRange 0x25AA 0x25AB, EmojiRange 0x25B6 0x25B6, EmojiRange 0x25C0 0x25C0, EmojiRange 0x25FB 0x25FE
  , EmojiRange 0x2600 0x27BF
  , EmojiRange 0x2934 0x2935, EmojiRange 0x2B05 0x2B07, EmojiRange 0x2B1B 0x2B1C
  , EmojiRange 0x2B50 0x2B50, EmojiRange 0x2B55 0x2B55
  , EmojiRange 0x3030 0x3030, EmojiRange 0x303D 0x303D, EmojiRange 0x3297 0x3297, EmojiRange 0x3299 0x3299
  , EmojiRange 0x1F000 0x1F0FF, EmojiRange 0x1F100 0x1F1FF, EmojiRange 0x1F200 0x1F2FF
  , EmojiRange 0x1F300 0x1F5FF, EmojiRange 0x1F600 0x1F64F, EmojiRange 0x1F680 0x1F6FF
  , EmojiRange 0x1F700 0x1F77F, EmojiRange 0x1F780 0x1F7FF, EmojiRange 0x1F800 0x1F8FF
  , EmojiRange 0x1F900 0x1F9FF, EmojiRange 0x1FA00 0x1FA6F, EmojiRange 0x1FA70 0x1FAFF
  , EmojiRange 0xE0020 0xE007F
  ]

codepointHex :: Int -> String
codepointHex cp = showHex cp ""

readHexMaybe :: String -> Maybe Int
readHexMaybe s = case reads ("0x" ++ s) of
  [(n, "")] -> Just n
  _         -> Nothing
