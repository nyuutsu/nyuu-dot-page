--------------------------------------------------------------------------------
-- nyuu.page site generator
--
-- A minimal Hakyll configuration with:
-- - Clean URLs (/about/ not /about.html)
-- - Fenced div support for admonitions
-- - Blog posts with archive
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
import System.FilePath (takeBaseName, takeDirectory, (</>))
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
      -- Hakyll only auto-ignores its own output dirs; list both flavors'
      -- so neither build scans the other's tree.
      || path `elem` ["config", "scss", "src", "_site", "_site-smooth", "_cache", "_cache-smooth"]
  }
  where
    (destination, store) = case flavor of
      Textured -> ("_site", "_cache")
      Smooth   -> ("_site-smooth", "_cache-smooth")

-- | RSS feed configuration
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
-- Converts paths like "about.html" to "about/index.html"
-- so URLs can be "/about/" instead of "/about.html"
--------------------------------------------------------------------------------

cleanRoute :: Routes
cleanRoute = customRoute createIndexPath
  where
    createIndexPath identifier =
      let path = toFilePath identifier
          dir  = takeDirectory path
          base = takeBaseName path
      in case dir of
           "." -> base </> "index.html"
           _   -> dir </> base </> "index.html"

-- | Strip "content/" prefix and apply clean URL routing.
-- Used by pages, posts, and projects under content/.
contentRoute :: Routes
contentRoute = gsubRoute "content/" (const "") `composeRoutes` cleanRoute

-- | Strip trailing "index.html" from a URL path
-- "/about/index.html" -> "/about/"
stripIndexSuffix :: String -> String
stripIndexSuffix url
  | suffix `isSuffixOf` url = take (length url - length suffix) url
  | otherwise               = url
  where suffix = "index.html"

-- | Remove "index.html" from the end of URLs in generated content
cleanUrls :: Item String -> Compiler (Item String)
cleanUrls = return . fmap (withUrls stripIndexSuffix)

-- | Wrap content in the default template, relativize URLs, and clean them
-- Common tail of every page's compile pipeline.
applyDefault :: Context String -> Item String -> Compiler (Item String)
applyDefault ctx item =
  loadAndApplyTemplate "templates/default.html" ctx item
    >>= relativizeUrls
    >>= cleanUrls

--------------------------------------------------------------------------------
-- Pandoc Compiler
--
-- Enables fenced_divs and bracketed_spans extensions for widgets.
-- All transforms are applied from Transforms module - see src/Transforms.hs
-- Admonition config is loaded from config/admonitions.toml
--------------------------------------------------------------------------------

readerOptions :: ReaderOptions
readerOptions = defaultHakyllReaderOptions
  { readerExtensions =
      enableExtension Ext_fenced_divs $
      enableExtension Ext_bracketed_spans $
      readerExtensions defaultHakyllReaderOptions
  }

--------------------------------------------------------------------------------
-- Contexts
--------------------------------------------------------------------------------

-- | Absolute canonical URL for SEO tags (bypasses relativizeUrls/cleanUrls)
canonicalUrlField :: Context String
canonicalUrlField = field "canonicalUrl" $ \item -> do
  maybeRoute <- getRoute (itemIdentifier item)
  return $ case maybeRoute of
        Nothing -> "https://nyuu.page/"
        Just r  -> "https://nyuu.page/" <> stripIndexSuffix r

-- | Which compiled stylesheet a flavor ships; single source of truth for the link href and the version hash.
stylesheetSource :: Flavor -> FilePath
stylesheetSource Textured = "css/main.css"
stylesheetSource Smooth   = "css/smooth.css"

-- | FNV-1a hash of a file's bytes, as hex. Changes exactly when the file changes.
-- Used to version asset URLs: browsers cache them for a year by URL, so a content-derived
-- query string makes every deploy a cache miss and every non-deploy a cache hit.
contentVersion :: FilePath -> IO String
contentVersion path = do
  bytes <- ByteString.readFile path
  pure $ showHex (ByteString.foldl' fnv1a fnvOffsetBasis bytes) ""
  where
    fnvOffsetBasis = 0xcbf29ce484222325 :: Word64
    fnv1a acc byte = (acc `xor` fromIntegral byte) * 0x100000001b3

-- | Values that differ between the textured and smooth output trees.
flavorContext :: Flavor -> String -> Context String
flavorContext flavor cssVersion =
  constField "stylesheet"  ("/" <> stylesheetSource flavor <> "?v=" <> cssVersion) <>
  constField "preloadFont" (preloadFont flavor)
  where
    preloadFont Textured = "/fonts/IMFellEnglish-Regular.woff2"
    preloadFont Smooth   = "/fonts/SourceSerif4-Regular.woff2"

-- | Base context for all pages (flavor fields + canonical URL + defaults)
siteContext :: Flavor -> String -> Context String
siteContext flavor cssVersion = flavorContext flavor cssVersion <> canonicalUrlField <> defaultContext

-- | Format the "updated" metadata field for display (e.g. "January 28, 2026")
-- Leaves the raw ISO value in $updated$ for the datetime attribute.
updatedField :: Context String
updatedField = field "updatedDisplay" $ \item -> do
  maybeUpdated <- getMetadataField (itemIdentifier item) "updated"
  case maybeUpdated of
    Nothing -> noResult "no updated field"
    Just dateStr ->
      case parseTimeM True defaultTimeLocale "%Y-%m-%d" dateStr of
        Nothing  -> noResult ("couldn't parse updated date: " ++ dateStr)
        Just day -> return $ formatTime defaultTimeLocale "%B %e, %Y" (day :: Day)

-- | Context for blog posts (includes formatted date + machine-readable ISO date)
postContext :: Flavor -> String -> Context String
postContext flavor cssVersion =
  dateField "date" "%B %e, %Y" <>
  dateField "isodate" "%Y-%m-%d" <>
  updatedField <>
  siteContext flavor cssVersion

-- | Computed field: SVG path for the project icon emoji.
-- Reads the first character of the "icon" metadata, converts to a codepoint
-- hex path.  The template uses this for the <img> src alongside $icon$ for
-- alt text and the hidden copy-paste span.
emojiIconSrcField :: Context String
emojiIconSrcField = field "icon-src" $ \item -> do
  maybeIcon <- getMetadataField (itemIdentifier item) "icon"
  case maybeIcon of
    Just (c:_) -> return $ "/images/emoji/" ++ showHex (ord c) "" ++ ".svg"
    _          -> noResult "no icon field"

-- | Sort items by a metadata field (numeric, ascending)
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
  -- Load config (runs before rules)
  ----------------------------------------------------------------------------
  admonitionConfig <- preprocess $ loadAdmonitionConfig "config/admonitions.toml"
  avatarConfig <- preprocess $ loadAvatarConfig "config/avatars.toml"
  cardCache <- preprocess $ buildCardCache readerOptions "config" "content" "static/images/cards"
  emojiAssets <- preprocess $ buildEmojiAssets "config/blobmoji/svg-fixed" "static/images/emoji" ["content", "src", "scss"]
  imageDims <- preprocess $ scanImageDimensions "static"
  syntaxMap <- preprocess $ loadCustomSyntaxMap "config/syntax"
                              (writerSyntaxMap defaultHakyllWriterOptions)
  cssVersion <- preprocess $ contentVersion (stylesheetSource flavor)
  let pageContext = siteContext flavor cssVersion
  let blogPostContext = postContext flavor cssVersion
  let writerOptions = defaultHakyllWriterOptions { writerSyntaxMap = syntaxMap }
  let baseTransforms = allTransforms admonitionConfig avatarConfig cardCache imageDims emojiAssets
  -- Pages opt into a drop cap with `dropcap: true` frontmatter. The flag is Hakyll
  -- metadata, invisible to the pure transform chain, so the choice is made here.
  let sitePandocCompiler = do
        identifier <- getUnderlying
        dropcapFlag <- getMetadataField identifier "dropcap"
        let transforms = if dropcapFlag == Just "true"
                           then dropcapTransform . baseTransforms
                           else baseTransforms
        pandocCompilerWithTransform readerOptions writerOptions transforms

  -- Pages bake in the stylesheet's content-hash URL, so they must rebuild when the stylesheet changes;
  -- Hakyll's tracker can't see context values, so the dependency is declared explicitly.
  let withStylesheetDependency = rulesExtraDependencies [contentDependency (IdentifierDependency (fromFilePath (stylesheetSource flavor)))]

  ----------------------------------------------------------------------------
  -- Static files: fonts, images
  -- Copies everything from static/ to the root of _site/
  ----------------------------------------------------------------------------
  match "static/**" $ do
    route $ gsubRoute "static/" (const "")
    compile copyFileCompiler

  ----------------------------------------------------------------------------
  -- CSS: compress and copy
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
  -- Uses contentRoute for clean URLs
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
  -- Home page: project showcase + recent posts
  -- Projects loaded from content/projects/, sorted by weight
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
        >>= saveSnapshot "content"  -- Save for RSS before templates
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
