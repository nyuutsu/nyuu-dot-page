-- | Shared file-system utilities used across modules.
module FileUtils
  ( findFiles
  ) where

import Control.Monad (filterM)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath ((</>), takeExtension)

-- | Recursively find files with given extensions under a directory.
findFiles :: [String] -> FilePath -> IO [FilePath]
findFiles extensions dir = do
  entries <- map (dir </>) <$> listDirectory dir
  files   <- filterM doesFileExist entries
  subdirs <- filterM doesDirectoryExist entries
  let matching = filter ((`elem` extensions) . takeExtension) files
  rest <- concat <$> mapM (findFiles extensions) subdirs
  return (matching ++ rest)
