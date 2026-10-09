--------------------------------------------------------------------------------
-- nyuu.page site generator
--
-- The config and data it loads, then where each page comes from and how it's made.
--------------------------------------------------------------------------------

import Data.Bits (xor)
import Data.ByteString qualified as ByteString
import Data.Functor ((<&>))
import Data.List (isSuffixOf, sortBy)
import Data.Maybe (fromMaybe)
import Data.Ord (comparing)
import Data.Char (ord)
import Data.Word (Word64)
import Numeric (showHex)
import Data.Time.Format (formatTime, parseTimeM, defaultTimeLocale)
import Data.Time.Calendar (Day)
import Hakyll
import Hakyll.Core.Dependencies (DependencySelector (IdentifierDependency), contentDependency)
import System.Environment (lookupEnv)
import System.FilePath (takeBaseName, takeDirectory, takeFileName, (</>))
import Text.Pandoc.Options
import Text.Read (readMaybe)
import Transforms (allTransforms, dropcapTransform)
import Config (loadAdmonitionConfig, loadAvatarConfig)
import CardCache (buildCardCache)
import Emoji (buildEmojiAssets)
import ImageDimensions (scanImageDimensions)
import SyntaxMap (loadCustomSyntaxMap)

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- | The two font flavors of the site. Each is a complete output tree.
data Flavor = Textured | Smooth
  deriving (Eq, Show, Enum, Bounded)

-- | Textured is the canonical flavor; FLAVOR=smooth selects the mirror.
flavorFromEnv :: Maybe String -> Flavor
flavorFromEnv Nothing         = Textured
flavorFromEnv (Just "smooth") = Smooth
flavorFromEnv (Just other)    =
  error ("unknown FLAVOR " ++ show other ++ "; expected \"smooth\" or unset")

configFor :: Flavor -> Configuration
configFor flavor = defaultConfiguration
  { destinationDirectory = destination
  , storeDirectory       = store
  , tmpDirectory         = store </> "tmp"
  , providerDirectory    = "."
  , ignoreFile           = \path ->
      ignoreFile defaultConfiguration path
      -- Hakyll already skips this flavor's own output and cache; this adds the other flavor's, and the source folders no rule matches.
      || path `elem` ["config", "scss", "src", "_site", "_site-smooth", "_cache", "_cache-smooth"]
  }
  where
    (destination, store) = case flavor of
      Textured -> ("_site", "_cache")
      Smooth   -> ("_site-smooth", "_cache-smooth")

feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration
  { feedTitle       = "nyuu.page"
  , feedDescription = "your #1 source for nyuu.page"
  , feedAuthorName  = "nyuu"
  , feedAuthorEmail = "nyuu@nyuu.page"
  , feedRoot        = "https://nyuu.page"
  }

--------------------------------------------------------------------------------
-- Clean URLs
--
-- Each page becomes a folder holding an index.html, so its address reads /about/ rather than /about.html.
--------------------------------------------------------------------------------

cleanRoute :: Routes
cleanRoute = customRoute createIndexPath
  where
    createIndexPath identifier =
      let path      = toFilePath identifier
          directory = takeDirectory path
          baseName  = takeBaseName path
      in case directory of
           "." -> baseName </> "index.html"
           _   -> directory </> baseName </> "index.html"

-- | Pages live under content/ in the repo but at the site root: content/about.md becomes /about/.
contentRoute :: Routes
contentRoute = gsubRoute "content/" (const "") `composeRoutes` cleanRoute

-- | "/about/index.html" -> "/about/"
stripIndexSuffix :: String -> String
stripIndexSuffix url
  | suffix `isSuffixOf` url = take (length url - length suffix) url
  | otherwise               = url
  where suffix = "index.html"

-- | The same, for every link in a page's HTML.
cleanUrls :: Item String -> Compiler (Item String)
cleanUrls = return . fmap (withUrls stripIndexSuffix)

-- | The steps every HTML page finishes with.
applyDefault :: Context String -> Item String -> Compiler (Item String)
applyDefault context item =
  loadAndApplyTemplate "templates/default.html" context item
    >>= relativizeUrls
    >>= cleanUrls

--------------------------------------------------------------------------------
-- Contexts
--------------------------------------------------------------------------------

-- | The page's full address, for the canonical link; it's always nyuu.page, even in the smooth tree.
canonicalUrlField :: Context String
canonicalUrlField = field "canonicalUrl" $ \item -> do
  maybeRoute <- getRoute (itemIdentifier item)
  return $ case maybeRoute of
        Nothing        -> "https://nyuu.page/"
        Just routePath -> "https://nyuu.page/" <> stripIndexSuffix routePath

-- | The stylesheet a flavor ships; its link and its stamp both come from here.
stylesheetSource :: Flavor -> FilePath
stylesheetSource Textured = "css/main.css"
stylesheetSource Smooth   = "css/smooth.css"

-- | The font a flavor preloads; its link and its stamp both come from here.
preloadFontSource :: Flavor -> FilePath
preloadFontSource Textured = "static/fonts/IMFellEnglish-Regular.woff2"
preloadFontSource Smooth   = "static/fonts/SourceSerif4-Regular.woff2"

-- | Content stamps for the assets the page head links by URL.
-- The preload stamp must match the one the stylesheet gives the same font, or the browser fetches it twice;
-- config/font-subset.py computes its stamps with the same FNV-1a as contentVersion for that reason.
data AssetVersions = AssetVersions
  { stylesheetVersion  :: !String
  , preloadFontVersion :: !String
  }

-- | FNV-1a hash of a file's bytes, as hex, for stamping asset URLs.
-- Browsers keep a stamped file for a year, so the stamp changes only when the file does: a new version is fetched once, and an unchanged one stays cached.
contentVersion :: FilePath -> IO String
contentVersion path = do
  bytes <- ByteString.readFile path
  pure $ showHex (ByteString.foldl' fnv1a fnvOffsetBasis bytes) ""
  where
    fnvOffsetBasis = 0xcbf29ce484222325 :: Word64
    fnv1a hash byte = (hash `xor` fromIntegral byte) * 0x100000001b3

-- | Values that differ between the textured and smooth output trees.
flavorContext :: Flavor -> AssetVersions -> Context String
flavorContext flavor versions =
  constField "stylesheet"  ("/" <> stylesheetSource flavor <> "?v=" <> stylesheetVersion versions) <>
  constField "preloadFont" ("/fonts/" <> takeFileName (preloadFontSource flavor) <> "?v=" <> preloadFontVersion versions)

-- | The fields every page's template can use.
siteContext :: Flavor -> AssetVersions -> Context String
siteContext flavor versions = flavorContext flavor versions <> canonicalUrlField <> defaultContext

-- | A post's "updated" date, written out for reading: "January 28, 2026".
-- The raw ISO date stays in $updated$ for the datetime attribute.
updatedField :: Context String
updatedField = field "updatedDisplay" $ \item -> do
  maybeUpdated <- getMetadataField (itemIdentifier item) "updated"
  case maybeUpdated of
    Nothing -> noResult "no updated field"
    Just isoDate ->
      case parseTimeM True defaultTimeLocale "%Y-%m-%d" isoDate of
        Nothing  -> noResult ("couldn't parse updated date: " ++ isoDate)
        Just day -> return $ formatTime defaultTimeLocale "%B %e, %Y" (day :: Day)

-- | Posts add their dates, written out and in ISO form.
postContext :: Flavor -> AssetVersions -> Context String
postContext flavor versions =
  dateField "date" "%B %e, %Y" <>
  dateField "isodate" "%Y-%m-%d" <>
  updatedField <>
  siteContext flavor versions

-- | Where a project's icon emoji lives as an SVG; only the first codepoint counts, so the icon must be a single-codepoint emoji.
-- The template shows that image, and keeps $icon$ itself for the alt text and the hidden copy-paste span.
emojiIconSrcField :: Context String
emojiIconSrcField = field "icon-src" $ \item -> do
  maybeIcon <- getMetadataField (itemIdentifier item) "icon"
  case maybeIcon of
    Just (iconCharacter:_) -> return $ "/images/emoji/" ++ showHex (ord iconCharacter) "" ++ ".svg"
    _                      -> noResult "no icon field"

-- | Lightest first, by the weight in each page's frontmatter; a page without one goes last.
sortByWeight :: [Item String] -> Compiler [Item String]
sortByWeight items = do
  withWeights <- mapM addWeight items
  return $ map snd $ sortBy (comparing fst) withWeights
  where
    addWeight item = do
      weightField <- getMetadataField (itemIdentifier item) "weight"
      let weight = fromMaybe 999 (readMaybe =<< weightField) :: Int
      return (weight, item)

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

main :: IO ()
main = do
  flavor <- flavorFromEnv <$> lookupEnv "FLAVOR"
  hakyllWith (configFor flavor) (siteRules flavor)

siteRules :: Flavor -> Rules ()
siteRules flavor = do

  ----------------------------------------------------------------------------
  -- Everything the pages draw on, loaded once before any of them compile
  ----------------------------------------------------------------------------
  admonitionConfig <- preprocess $ loadAdmonitionConfig "config/admonitions.toml"
  avatarConfig <- preprocess $ loadAvatarConfig "config/avatars.toml"
  cardCache <- preprocess $ buildCardCache defaultHakyllReaderOptions "config" "content" "static/images/cards"
  emojiAssets <- preprocess $ buildEmojiAssets "config/blobmoji/svg-fixed" "static/images/emoji" ["content", "src", "scss"]
  imageDimensions <- preprocess $ scanImageDimensions "static"
  syntaxMap <- preprocess $ loadCustomSyntaxMap "config/syntax"
                              (writerSyntaxMap defaultHakyllWriterOptions)
  assetVersions <- preprocess $
    AssetVersions <$> contentVersion (stylesheetSource flavor) <*> contentVersion (preloadFontSource flavor)
  let pageContext = siteContext flavor assetVersions
  let blogPostContext = postContext flavor assetVersions
  let writerOptions = defaultHakyllWriterOptions { writerSyntaxMap = syntaxMap }
  let baseTransforms = allTransforms admonitionConfig avatarConfig cardCache imageDimensions emojiAssets
  -- Pages opt into a drop cap with `dropcap: true` frontmatter.
  -- The flag is Hakyll metadata, invisible to the pure transform chain, so the choice is made here.
  let sitePandocCompiler = do
        identifier <- getUnderlying
        dropcapFlag <- getMetadataField identifier "dropcap"
        let transforms = if dropcapFlag == Just "true"
                           then dropcapTransform . baseTransforms
                           else baseTransforms
        pandocCompilerWithTransform defaultHakyllReaderOptions writerOptions transforms

  -- Pages bake in the stylesheet's content-hash URL, so they must rebuild when the stylesheet changes;
  -- Hakyll's tracker can't see context values, so the dependency is declared explicitly.
  -- The stylesheet carries every font's stamp too, so a changed preload font rebuilds the pages through it.
  let withStylesheetDependency = rulesExtraDependencies [contentDependency (IdentifierDependency (fromFilePath (stylesheetSource flavor)))]

  ----------------------------------------------------------------------------
  -- Static files: fonts, images
  -- Copies everything from static/ to the root of _site/
  ----------------------------------------------------------------------------
  match "static/**" $ do
    route $ gsubRoute "static/" (const "")
    compile copyFileCompiler

  ----------------------------------------------------------------------------
  -- CSS, as Sass wrote it
  ----------------------------------------------------------------------------
  match "css/*.css" $ do
    route idRoute
    compile getResourceBody  -- Sass already compresses; Hakyll's compressCss breaks max()/calc()

  match "css/*.css.map" $ do
    route idRoute
    compile copyFileCompiler

  ----------------------------------------------------------------------------
  -- Templates: compile for use by other rules
  ----------------------------------------------------------------------------
  match "templates/*" $ compile templateBodyCompiler

  ----------------------------------------------------------------------------
  -- Static pages: about, contact
  ----------------------------------------------------------------------------
  withStylesheetDependency $ match (fromList ["content/about.md", "content/contact.md"]) $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= loadAndApplyTemplate "templates/page.html" pageContext
        >>= applyDefault pageContext

  ----------------------------------------------------------------------------
  -- Project pages
  -- Flat: content/projects/foo.md -> /projects/foo/
  -- Nested: content/projects/foo/bar.md -> /projects/foo/bar/
  ----------------------------------------------------------------------------
  withStylesheetDependency $ match "content/projects/**" $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= loadAndApplyTemplate "templates/page.html" pageContext
        >>= applyDefault pageContext

  ----------------------------------------------------------------------------
  -- Home page: the project showcase and the five newest posts
  ----------------------------------------------------------------------------
  withStylesheetDependency $ match "content/index.md" $ do
    route $ constRoute "index.html"
    compile $ do
      posts <- fmap (take 5) . recentFirst =<< loadAll "content/posts/*"
      projectPages <- sortByWeight =<< loadAll "content/projects/*"
      let projectContext = emojiIconSrcField <> defaultContext
      let indexContext =
            listField "projects" projectContext (return projectPages) <>
            listField "posts" blogPostContext (return posts) <>
            constField "title" "Home" <>
            pageContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/index.html" indexContext
        >>= applyDefault indexContext

  ----------------------------------------------------------------------------
  -- Blog posts
  ----------------------------------------------------------------------------
  withStylesheetDependency $ match "content/posts/*" $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= saveSnapshot "content"  -- the bare post, for the RSS feed
        >>= loadAndApplyTemplate "templates/post.html" blogPostContext
        >>= applyDefault blogPostContext

  ----------------------------------------------------------------------------
  -- Archive page: list of all posts
  ----------------------------------------------------------------------------
  withStylesheetDependency $ create ["archive/index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "content/posts/*"
      let archiveContext =
            listField "posts" blogPostContext (return posts) <>
            constField "title" "Archive"             <>
            pageContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/archive.html" archiveContext
        >>= applyDefault archiveContext

  ----------------------------------------------------------------------------
  -- Sitemap
  ----------------------------------------------------------------------------
  create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "content/posts/*"
      projectPages <- sortByWeight =<< loadAll "content/projects/**"
      let sitemapContext =
            listField "projects" defaultContext (return projectPages) <>
            listField "posts" blogPostContext (return posts) <>
            defaultContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapContext
        <&> fmap (replaceAll "/index\\.html" (const "/"))

  ----------------------------------------------------------------------------
  -- RSS feed
  ----------------------------------------------------------------------------
  create ["rss.xml"] $ do
    route idRoute
    compile $ do
      let feedContext = blogPostContext <> bodyField "description"
      posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "content/posts/*" "content"
      renderRss feedConfig feedContext posts
        <&> fmap (replaceAll "/index\\.html" (const "/"))
