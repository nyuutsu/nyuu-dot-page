-- | Shared file-system utilities used across modules.
module FileUtils
  ( findFiles
  , withDirectoryOrDefault
  ) where

import Control.Monad (filterM)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath ((</>), takeExtension)

-- | Run an action if a directory exists; otherwise run a fallback.
-- The fallback is IO so callers can log warnings in the missing-directory path.
withDirectoryOrDefault :: IO a -> FilePath -> IO a -> IO a
withDirectoryOrDefault fallback dir action = do
  exists <- doesDirectoryExist dir
  if exists then action else fallback

-- | Recursively find files with given extensions under a directory.
findFiles :: [String] -> FilePath -> IO [FilePath]
findFiles extensions dir = do
  entries <- map (dir </>) <$> listDirectory dir
  files   <- filterM doesFileExist entries
  subdirs <- filterM doesDirectoryExist entries
  let matching = filter ((`elem` extensions) . takeExtension) files
  rest <- concat <$> mapM (findFiles extensions) subdirs
  return (matching ++ rest)
