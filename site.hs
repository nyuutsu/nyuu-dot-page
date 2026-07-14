--------------------------------------------------------------------------------
-- nyuu.page site generator
--
-- A minimal Hakyll configuration with:
-- - Clean URLs (/about/ not /about.html)
-- - Fenced div support for admonitions
-- - Blog posts with archive
--------------------------------------------------------------------------------

import Data.Functor ((<&>))
import Data.List (isSuffixOf, sortBy)
import Data.Maybe (fromMaybe)
import Data.Ord (comparing)
import Data.Char (ord)
import Numeric (showHex)
import Data.Time.Format (formatTime, parseTimeM, defaultTimeLocale)
import Data.Time.Calendar (Day)
import Hakyll
import System.Environment (lookupEnv)
import System.FilePath (takeBaseName, takeDirectory, (</>))
import Text.Pandoc.Options
import Text.Read (readMaybe)
import Transforms (allTransforms)
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

-- | Values that differ between the textured and smooth output trees.
flavorContext :: Flavor -> Context String
flavorContext Textured =
  constField "stylesheet"  "/css/main.css" <>
  constField "preloadFont" "/fonts/IMFellEnglish-Regular.woff2"
flavorContext Smooth =
  constField "stylesheet"  "/css/smooth.css" <>
  constField "preloadFont" "/fonts/SourceSerif4-Regular.woff2"

-- | Base context for all pages (flavor fields + canonical URL + defaults)
siteContext :: Flavor -> Context String
siteContext flavor = flavorContext flavor <> canonicalUrlField <> defaultContext

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
postContext :: Flavor -> Context String
postContext flavor =
  dateField "date" "%B %e, %Y" <>
  dateField "isodate" "%Y-%m-%d" <>
  updatedField <>
  siteContext flavor

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
  let writerOptions = defaultHakyllWriterOptions { writerSyntaxMap = syntaxMap }
  let sitePandocCompiler = pandocCompilerWithTransform readerOptions writerOptions (allTransforms admonitionConfig avatarConfig cardCache imageDims emojiAssets)

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
  match (fromList ["content/about.md", "content/contact.md"]) $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= loadAndApplyTemplate "templates/page.html" (siteContext flavor)
        >>= applyDefault (siteContext flavor)

  ----------------------------------------------------------------------------
  -- Project pages
  -- Flat: content/projects/foo.md -> /projects/foo/
  -- Nested: content/projects/foo/bar.md -> /projects/foo/bar/
  ----------------------------------------------------------------------------
  match "content/projects/**" $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= loadAndApplyTemplate "templates/page.html" (siteContext flavor)
        >>= applyDefault (siteContext flavor)

  ----------------------------------------------------------------------------
  -- Home page: project showcase + recent posts
  -- Projects loaded from content/projects/, sorted by weight
  ----------------------------------------------------------------------------
  match "content/index.md" $ do
    route $ constRoute "index.html"
    compile $ do
      posts <- fmap (take 5) . recentFirst =<< loadAll "content/posts/*"
      projectPages <- sortByWeight =<< loadAll "content/projects/*"
      let projectContext = emojiIconSrcField <> defaultContext
      let indexContext =
            listField "projects" projectContext (return projectPages) <>
            listField "posts" (postContext flavor) (return posts) <>
            constField "title" "Home" <>
            siteContext flavor
      makeItem ""
        >>= loadAndApplyTemplate "templates/index.html" indexContext
        >>= applyDefault indexContext

  ----------------------------------------------------------------------------
  -- Blog posts
  ----------------------------------------------------------------------------
  match "content/posts/*" $ do
    route contentRoute
    compile $
      sitePandocCompiler
        >>= saveSnapshot "content"  -- Save for RSS before templates
        >>= loadAndApplyTemplate "templates/post.html" (postContext flavor)
        >>= applyDefault (postContext flavor)

  ----------------------------------------------------------------------------
  -- Archive page: list of all posts
  ----------------------------------------------------------------------------
  create ["archive/index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "content/posts/*"
      let archiveContext =
            listField "posts" (postContext flavor) (return posts) <>
            constField "title" "Archive"             <>
            siteContext flavor
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
            listField "posts" (postContext flavor) (return posts) <>
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
      let feedContext = postContext flavor <> bodyField "description"
      posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "content/posts/*" "content"
      renderRss feedConfig feedContext posts
        <&> fmap (replaceAll "/index\\.html" (const "/"))
