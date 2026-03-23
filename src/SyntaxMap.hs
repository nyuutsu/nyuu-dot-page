-- =============================================================================
-- SyntaxMap
-- Loads custom Kate XML syntax definitions from config/syntax/
-- and merges them into Pandoc's default syntax map.
--
-- To add a new language: drop a .xml file in config/syntax/ and rebuild.
-- =============================================================================

module SyntaxMap (loadCustomSyntaxMap) where

import qualified Data.Map.Strict as Map
import Skylighting.Types (SyntaxMap)
import FileUtils (withDirectoryOrDefault)
import Skylighting.Loader (loadSyntaxesFromDir)

-- | Load all .xml syntax definitions from a directory and merge them
-- into the provided base syntax map. Custom definitions take precedence.
-- If the directory does not exist, returns the base map unchanged.
loadCustomSyntaxMap :: FilePath -> SyntaxMap -> IO SyntaxMap
loadCustomSyntaxMap dir baseMap =
  withDirectoryOrDefault (pure baseMap) dir $ do
    result <- loadSyntaxesFromDir dir
    case result of
      Left err -> do
        putStrLn $ "Warning: failed to load syntax definitions from " ++ dir ++ ": " ++ err
        return baseMap
      Right customMap ->
        return $ Map.union customMap baseMap
