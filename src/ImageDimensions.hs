-- =============================================================================
-- Image Dimensions
-- Scans static/images/ for image files and collects their dimensions.
-- Used by Transforms.ImageDimensions to inject width/height for CLS prevention.
--
-- Supports: PNG, JPEG, GIF (via JuicyPixels), WebP (manual header parsing)
-- SVG excluded - vector images don't have meaningful pixel dimensions.
-- =============================================================================

module ImageDimensions
  ( ImageDimensions
  , Dimensions(..)
  , scanImageDimensions
  , lookupDimensions
  ) where

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Char (toLower)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as T
import Control.Exception (try, SomeException)
import Control.Monad (forM)
import System.Directory (listDirectory, doesDirectoryExist)
import System.FilePath ((</>), takeExtension, makeRelative)
import System.IO (withBinaryFile, IOMode(ReadMode))
import Codec.Picture (readImage)
import Codec.Picture.Types (dynamicMap, imageWidth, imageHeight)

-- | Dimensions for a single image
data Dimensions = Dimensions
  { dimensionWidth  :: !Int
  , dimensionHeight :: !Int
  } deriving (Show, Eq)

-- | Map from URL path to dimensions
newtype ImageDimensions = ImageDimensions (Map Text Dimensions)
  deriving (Show, Eq)

lookupDimensions :: Text -> ImageDimensions -> Maybe Dimensions
lookupDimensions path (ImageDimensions m) = Map.lookup path m

-- | Scan static directory for images and collect their dimensions
scanImageDimensions :: FilePath -> IO ImageDimensions
scanImageDimensions staticDir = do
  let imagesDir = staticDir </> "images"
  exists <- doesDirectoryExist imagesDir
  if not exists
    then do
      putStrLn $ "[WARN] Image directory not found: " ++ imagesDir
      return emptyDimensions
    else do
      files <- findFilesRecursive imagesDir
      let imageFiles = filter (isImageExt . map toLower . takeExtension) files
      dimensions <- catMaybes <$> mapM (readDimensions staticDir) imageFiles
      putStrLn $ "Scanned dimensions for " ++ show (length dimensions) ++ " images"
      return $ ImageDimensions $ Map.fromList dimensions

-- ---------------------------------------------------------------------------
-- File discovery
-- ---------------------------------------------------------------------------

emptyDimensions :: ImageDimensions
emptyDimensions = ImageDimensions Map.empty

isImageExt :: String -> Bool
isImageExt ext = ext `elem` [".png", ".jpg", ".jpeg", ".gif", ".webp"]

findFilesRecursive :: FilePath -> IO [FilePath]
findFilesRecursive dir = do
  entries <- listDirectory dir
  concat <$> forM entries (\entry -> do
    let path = dir </> entry
    isDir <- doesDirectoryExist path
    if isDir then findFilesRecursive path else return [path])

-- ---------------------------------------------------------------------------
-- Dimension reading (dispatches by format)
-- ---------------------------------------------------------------------------

readDimensions :: FilePath -> FilePath -> IO (Maybe (Text, Dimensions))
readDimensions staticDir path = do
  let ext = map toLower $ takeExtension path
      urlPath = "/" <> makeRelative staticDir path
  result <- if ext == ".webp"
            then readWebPDims path
            else readJuicyDims path
  case result of
    Nothing -> do
      putStrLn $ "[WARN] Failed to read dimensions: " ++ path
      return Nothing
    Just dims -> return $ Just (T.pack urlPath, dims)

-- | Read dimensions via JuicyPixels (PNG, JPEG, GIF, BMP, TIFF)
readJuicyDims :: FilePath -> IO (Maybe Dimensions)
readJuicyDims path = do
  result <- readImage path
  return $ case result of
    Left _    -> Nothing
    Right img -> Just $ dynamicMap (\i -> Dimensions (imageWidth i) (imageHeight i)) img

-- | Read dimensions from WebP file header (first 30 bytes)
readWebPDims :: FilePath -> IO (Maybe Dimensions)
readWebPDims path = do
  result <- try $ withBinaryFile path ReadMode (`BS.hGet` 30)
  case result of
    Left (_ :: SomeException) -> return Nothing
    Right header -> return $ parseWebP header

-- ---------------------------------------------------------------------------
-- WebP header parsing
--
-- WebP container: RIFF <size> WEBP <chunk>
-- Three chunk types encode dimensions differently:
--   VP8  (lossy)    - frame header after 3-byte tag + start code
--   VP8L (lossless) - bit-packed after signature byte
--   VP8X (extended) - canvas size in 24-bit fields
-- ---------------------------------------------------------------------------

parseWebP :: BS.ByteString -> Maybe Dimensions
parseWebP bs
  | BS.length bs < 30 = Nothing
  | BS.take 4 bs /= "RIFF" = Nothing
  | BS.take 4 (BS.drop 8 bs) /= "WEBP" = Nothing
  | otherwise = case BS.take 4 (BS.drop 12 bs) of
      "VP8 " -> parseVP8  (BS.drop 20 bs)
      "VP8L" -> parseVP8L (BS.drop 20 bs)
      "VP8X" -> parseVP8X (BS.drop 20 bs)
      _      -> Nothing

-- | VP8 lossy: start code 9D 01 2A, then width/height as 16-bit LE (lower 14 bits)
parseVP8 :: BS.ByteString -> Maybe Dimensions
parseVP8 bs
  | BS.length bs < 10 = Nothing
  | BS.index bs 3 /= 0x9D || BS.index bs 4 /= 0x01 || BS.index bs 5 /= 0x2A = Nothing
  | otherwise =
      let width  = wordLE 2 bs 6 .&. 0x3FFF
          height = wordLE 2 bs 8 .&. 0x3FFF
      in Just (Dimensions width height)

-- | VP8L lossless: signature 0x2F, then width-1 and height-1 bit-packed in 4 bytes
parseVP8L :: BS.ByteString -> Maybe Dimensions
parseVP8L bs
  | BS.length bs < 5 = Nothing
  | BS.index bs 0 /= 0x2F = Nothing
  | otherwise =
      let bits   = wordLE 4 bs 1
          width  = (bits .&. 0x3FFF) + 1
          height = ((bits `shiftR` 14) .&. 0x3FFF) + 1
      in Just (Dimensions width height)

-- | VP8X extended: 4 bytes flags, then canvas width-1 and height-1 as 24-bit LE
parseVP8X :: BS.ByteString -> Maybe Dimensions
parseVP8X bs
  | BS.length bs < 10 = Nothing
  | otherwise =
      let width  = wordLE 3 bs 4 + 1
          height = wordLE 3 bs 7 + 1
      in Just (Dimensions width height)

-- ---------------------------------------------------------------------------
-- Little-endian integer helper
-- ---------------------------------------------------------------------------

-- | Read byteCount bytes as a little-endian unsigned integer starting at offset
wordLE :: Int -> BS.ByteString -> Int -> Int
wordLE byteCount bytes offset =
  foldl' (\result byteIndex ->
    result .|. (fromIntegral (BS.index bytes (offset + byteIndex)) `shiftL` (8 * byteIndex))
  ) 0 [0..byteCount - 1]