-- =============================================================================
-- Image Dimensions
-- Scans static/images/ for image files and collects their dimensions.
-- Used by Transforms.ImageDimensions to inject width/height for CLS prevention.
--
-- Dimensions read via Rust FFI (imagesize crate) — header-only, no full decode.
-- SVG excluded - vector images don't have meaningful pixel dimensions.
-- =============================================================================

module ImageDimensions
  ( ImageDimensions
  , Dimensions(..)
  , scanImageDimensions
  , lookupDimensions
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as Text
import FileUtils (findFiles, withDirectoryOrDefault)
import Foreign.C.String (withCString)
import Foreign.C.Types (CChar, CInt(..), CUInt(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peek)
import System.FilePath ((</>), makeRelative)

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
scanImageDimensions staticDir =
  withDirectoryOrDefault missingWarning imagesDir $ do
    imageFiles <- findFiles [".png", ".jpg", ".jpeg", ".gif", ".webp"] imagesDir
    dimensions <- catMaybes <$> mapM (readDimensions staticDir) imageFiles
    putStrLn $ "Scanned dimensions for " ++ show (length dimensions) ++ " images"
    return $ ImageDimensions $ Map.fromList dimensions
  where
    imagesDir = staticDir </> "images"
    missingWarning = do
      putStrLn $ "[WARN] Image directory not found: " ++ imagesDir
      return emptyDimensions

-- ---------------------------------------------------------------------------
-- File discovery
-- ---------------------------------------------------------------------------

emptyDimensions :: ImageDimensions
emptyDimensions = ImageDimensions Map.empty

-- ---------------------------------------------------------------------------
-- FFI binding to Rust imagesize crate
-- ---------------------------------------------------------------------------

foreign import ccall unsafe "image_dimensions"
  c_imageDimensions :: Ptr CChar -> Ptr CUInt -> Ptr CUInt -> IO CInt

readDimensionsFFI :: FilePath -> IO (Maybe Dimensions)
readDimensionsFFI path =
  withCString path $ \cPath ->
    alloca $ \widthPtr ->
      alloca $ \heightPtr -> do
        result <- c_imageDimensions cPath widthPtr heightPtr
        if result == 0
          then do
            width  <- fromIntegral <$> peek widthPtr
            height <- fromIntegral <$> peek heightPtr
            return $ Just (Dimensions width height)
          else return Nothing

-- ---------------------------------------------------------------------------
-- Dimension reading
-- ---------------------------------------------------------------------------

readDimensions :: FilePath -> FilePath -> IO (Maybe (Text, Dimensions))
readDimensions staticDir path = do
  let urlPath = "/" <> makeRelative staticDir path
  result <- readDimensionsFFI path
  case result of
    Nothing -> do
      putStrLn $ "[WARN] Failed to read dimensions: " ++ path
      return Nothing
    Just dims -> return $ Just (Text.pack urlPath, dims)