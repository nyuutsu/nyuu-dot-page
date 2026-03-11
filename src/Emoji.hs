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

import Control.Monad (filterM, guard, unless)
import Data.Char (ord)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Debug.Trace (trace)
import Numeric (showHex)
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist,
                         doesFileExist, listDirectory)
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
      let base = T.pack (dropExtension name)
      guard (takeExtension name == ".svg")
      rest <- T.stripPrefix "emoji_u" base
      guard (not (T.any (== '_') rest))  -- single codepoint only
      readHexMaybe (T.unpack rest)

-- | Recursively scan directories for emoji characters in source files
scanForEmoji :: [FilePath] -> IO (Set Int)
scanForEmoji dirs = do
  files <- concat <$> mapM (findFiles [".md", ".hs", ".scss"]) dirs
  contents <- mapM TIO.readFile files
  let allText = T.concat contents
  return $ T.foldl' (\acc c ->
    if isEmojiCodepoint (ord c)
      then Set.insert (ord c) acc
      else acc) Set.empty allText

-- | Copy a single emoji SVG, skipping if destination already exists
-- (avoids retriggering Hakyll's file watcher during make watch)
copySvg :: FilePath -> FilePath -> Int -> IO ()
copySvg srcDir dstDir cp = do
  let hex = codepointHex cp
      src = srcDir </> ("emoji_u" ++ hex ++ ".svg")
      dst = dstDir </> (hex ++ ".svg")
  dstExists <- doesFileExist dst
  unless dstExists $ do
    srcExists <- doesFileExist src
    if srcExists
      then copyFile src dst
      else trace ("[WARN] Emoji SVG missing: " ++ src) (return ())


-- ---- Helpers ----

-- | Recursively find files with given extensions
findFiles :: [String] -> FilePath -> IO [FilePath]
findFiles exts dir = do
  entries <- map (dir </>) <$> listDirectory dir
  files   <- filterM doesFileExist entries
  subdirs <- filterM doesDirectoryExist entries
  let matching = filter ((`elem` exts) . takeExtension) files
  rest <- concat <$> mapM (findFiles exts) subdirs
  return (matching ++ rest)

-- | Check if a codepoint falls in an emoji Unicode range
isEmojiCodepoint :: Int -> Bool
isEmojiCodepoint cp = any (uncurry inRange) emojiRanges
  where inRange lo hi = cp >= lo && cp <= hi

emojiRanges :: [(Int, Int)]
emojiRanges =
  [ (0x203C, 0x203C), (0x2049, 0x2049)
  , (0x2122, 0x2122), (0x2139, 0x2139)
  , (0x2194, 0x2199), (0x21A9, 0x21AA)
  , (0x231A, 0x231B), (0x2328, 0x2328)
  , (0x23CF, 0x23CF), (0x23E9, 0x23F3), (0x23F8, 0x23FA)
  , (0x24C2, 0x24C2)
  , (0x25AA, 0x25AB), (0x25B6, 0x25B6), (0x25C0, 0x25C0), (0x25FB, 0x25FE)
  , (0x2600, 0x27BF)
  , (0x2934, 0x2935), (0x2B05, 0x2B07), (0x2B1B, 0x2B1C)
  , (0x2B50, 0x2B50), (0x2B55, 0x2B55)
  , (0x3030, 0x3030), (0x303D, 0x303D), (0x3297, 0x3297), (0x3299, 0x3299)
  , (0x1F000, 0x1F0FF), (0x1F100, 0x1F1FF), (0x1F200, 0x1F2FF)
  , (0x1F300, 0x1F5FF), (0x1F600, 0x1F64F), (0x1F680, 0x1F6FF)
  , (0x1F700, 0x1F77F), (0x1F780, 0x1F7FF), (0x1F800, 0x1F8FF)
  , (0x1F900, 0x1F9FF), (0x1FA00, 0x1FA6F), (0x1FA70, 0x1FAFF)
  , (0xE0020, 0xE007F)
  ]

codepointHex :: Int -> String
codepointHex cp = showHex cp ""

readHexMaybe :: String -> Maybe Int
readHexMaybe s = case reads ("0x" ++ s) of
  [(n, "")] -> Just n
  _         -> Nothing
