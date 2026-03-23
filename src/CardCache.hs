-- =============================================================================
-- Card Cache
-- Builds card data (alt text, image paths) from local franchise JSON files.
-- Used by Transforms.Cards for hoverable card previews.
--
-- Franchise data:
--   config/pokemon/*.json  - Pokemon TCG cards (per-set files)
--   config/yugioh/*.json   - Yu-Gi-Oh cards
--   config/mtg/*.json      - Magic: The Gathering cards (incl. DFC support)
--
-- Also handles:
--   - Scanning content/ for card references ([Name]{.card})
--   - Copying only referenced card images to static/images/cards/
--
-- This is the largest module in the project (~540 lines). The franchise
-- loaders (Pokemon/YuGiOh/MTG) could each be their own module, but
-- they only interact at the merge point in buildCardCache, and the
-- normal workflow is adding card *data* (JSON + images to config/),
-- not modifying the loaders. Not worth the file overhead until it is.
-- =============================================================================

module CardCache
  ( CardCache
  , CardData(..)
  , buildCardCache
  , lookupCard
  , normalizeQuotes
  ) where

import Data.Aeson (FromJSON(..), (.:), (.:?), withObject)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as BS
import Data.List (sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Control.Exception (try, SomeException)
import Control.Monad (forM, foldM)
import FileUtils (findFiles, withDirectoryOrDefault)
import System.Directory (listDirectory, createDirectoryIfMissing, doesFileExist)
import System.FilePath ((</>), takeExtension, takeBaseName, takeDirectory)
import Text.Pandoc (runIO, readMarkdown)
import Text.Pandoc.Definition (Pandoc, Inline(..))
import Text.Pandoc.Options (ReaderOptions)
import Text.Pandoc.Shared (stringify)
import Text.Pandoc.Walk (query)
import Transforms.CardNotice (exampleCardName)

-- =============================================================================
-- Public types
-- =============================================================================

-- | Data for a single card (output format used by transforms)
data CardData = CardData
  { cardName    :: !Text
  , cardAltText :: !Text
  , cardImage   :: !(Maybe Text)
  , cardSource  :: !Text
  } deriving (Show, Eq)

-- | Map from lookup key to card data
newtype CardCache = CardCache (Map Text CardData)
  deriving (Show, Eq)

lookupCard :: Text -> CardCache -> Maybe CardData
lookupCard name (CardCache cards) = Map.lookup name cards

-- =============================================================================
-- Raw franchise JSON types (input formats, different per franchise)
-- =============================================================================

-- | Pokemon card as stored in per-set JSON files
data PokemonCard = PokemonCard
  { pokemonName       :: !Text
  , pokemonHP         :: !(Maybe Text)
  , pokemonTypes      :: !(Maybe [Text])
  , pokemonAbilities  :: !(Maybe [PokemonAbility])
  , pokemonAttacks    :: !(Maybe [PokemonAttack])
  , pokemonWeaknesses :: !(Maybe [PokemonWeakness])
  , pokemonImage      :: !(Maybe Text)
  } deriving (Show)

data PokemonAbility = PokemonAbility
  { abilityName :: !Text
  , abilityText :: !Text
  } deriving (Show)

data PokemonAttack = PokemonAttack
  { attackName   :: !Text
  , attackCost   :: !(Maybe [Text])
  , attackDamage :: !(Maybe Text)
  , attackText   :: !(Maybe Text)
  } deriving (Show)

data PokemonWeakness = PokemonWeakness
  { weaknessType  :: !Text
  , weaknessValue :: !Text
  } deriving (Show)

instance FromJSON PokemonCard where
  parseJSON = withObject "PokemonCard" $ \v -> PokemonCard
    <$> v .:  "name"
    <*> v .:? "hp"
    <*> v .:? "types"
    <*> v .:? "abilities"
    <*> v .:? "attacks"
    <*> v .:? "weaknesses"
    <*> v .:? "image"

instance FromJSON PokemonAbility where
  parseJSON = withObject "PokemonAbility" $ \v -> PokemonAbility
    <$> v .: "name"
    <*> v .: "text"

instance FromJSON PokemonAttack where
  parseJSON = withObject "PokemonAttack" $ \v -> PokemonAttack
    <$> v .: "name"
    <*> v .:? "cost"
    <*> v .:? "damage"
    <*> v .:? "text"

instance FromJSON PokemonWeakness where
  parseJSON = withObject "PokemonWeakness" $ \v -> PokemonWeakness
    <$> v .: "type"
    <*> v .: "value"

-- | Yu-Gi-Oh card
data YugiohCard = YugiohCard
  { yugiohName        :: !Text
  , yugiohType        :: !(Maybe Text)
  , yugiohRace        :: !(Maybe Text)
  , yugiohAttribute   :: !(Maybe Text)
  , yugiohLevel       :: !(Maybe Int)
  , yugiohAttack      :: !(Maybe Int)
  , yugiohDefense     :: !(Maybe Int)
  , yugiohDescription :: !(Maybe Text)
  , yugiohImage       :: !(Maybe Text)
  } deriving (Show)

instance FromJSON YugiohCard where
  parseJSON = withObject "YugiohCard" $ \v -> YugiohCard
    <$> v .:  "name"
    <*> v .:? "type"
    <*> v .:? "race"
    <*> v .:? "attribute"
    <*> v .:? "level"
    <*> v .:? "atk"
    <*> v .:? "def"
    <*> v .:? "desc"
    <*> v .:? "image"

-- | MTG card (single-faced or full DFC entry)
data MtgCard = MtgCard
  { mtgName       :: !Text
  , mtgManaCost   :: !(Maybe Text)
  , mtgTypeLine   :: !(Maybe Text)
  , mtgOracleText :: !(Maybe Text)
  , mtgPower      :: !(Maybe Text)
  , mtgToughness  :: !(Maybe Text)
  , mtgImage      :: !(Maybe Text)
  , mtgCardFaces  :: !(Maybe [MtgFace])
  } deriving (Show)

-- | A single face of a double-faced MTG card
data MtgFace = MtgFace
  { mtgFaceName       :: !Text
  , mtgFaceManaCost   :: !(Maybe Text)
  , mtgFaceTypeLine   :: !(Maybe Text)
  , mtgFaceOracleText :: !(Maybe Text)
  , mtgFacePower      :: !(Maybe Text)
  , mtgFaceToughness  :: !(Maybe Text)
  , mtgFaceImage      :: !(Maybe Text)
  } deriving (Show)

instance FromJSON MtgCard where
  parseJSON = withObject "MtgCard" $ \v -> MtgCard
    <$> v .:  "name"
    <*> v .:? "mana_cost"
    <*> v .:? "type_line"
    <*> v .:? "oracle_text"
    <*> v .:? "power"
    <*> v .:? "toughness"
    <*> v .:? "image"
    <*> v .:? "card_faces"

instance FromJSON MtgFace where
  parseJSON = withObject "MtgFace" $ \v -> MtgFace
    <$> v .:  "name"
    <*> v .:? "mana_cost"
    <*> v .:? "type_line"
    <*> v .:? "oracle_text"
    <*> v .:? "power"
    <*> v .:? "toughness"
    <*> v .:? "image"

-- =============================================================================
-- Alt text formatting
-- =============================================================================

-- | Build alt text from optional parts, dropping Nothings and joining with spaces
altParts :: [Maybe Text] -> Text
altParts = T.unwords . catMaybes

formatPokemonAlt :: PokemonCard -> Text
formatPokemonAlt card = altParts $
  [ Just (pokemonName card)
  , (\hp -> "- " <> hp <> " HP") <$> pokemonHP card
  , (\types -> "- " <> T.intercalate "/" types) <$> pokemonTypes card
  ] ++
  map formatAbility (fromMaybe [] $ pokemonAbilities card) ++
  map formatAttack (fromMaybe [] $ pokemonAttacks card) ++
  [ case pokemonWeaknesses card of
      Just (first:_) -> Just ("- Weakness: " <> weaknessType first <> " " <> weaknessValue first)
      _              -> Nothing
  ]
  where
    formatAbility ability = Just ("- " <> abilityName ability <> ": " <> abilityText ability)
    formatAttack attack =
      let cost = T.concat $ fromMaybe [] (attackCost attack)
          damage = fromMaybe "" (attackDamage attack)
          base = "- " <> attackName attack <> " [" <> cost <> "]"
                 <> if T.null damage then "" else " " <> damage
      in Just (base <> maybe "" (": " <>) (attackText attack))

formatYugiohAlt :: YugiohCard -> Text
formatYugiohAlt card = altParts
  [ Just (yugiohName card)
  , ("- " <>) <$> yugiohType card
  , (\race -> "(" <> race <> ")") <$> yugiohRace card
  , (\attr -> "[" <> attr <> "]") <$> yugiohAttribute card
  , (\level -> "- Level " <> T.pack (show level)) <$> yugiohLevel card
  , case (yugiohAttack card, yugiohDefense card) of
      (Just attack, Just defense) -> Just ("- ATK " <> T.pack (show attack) <> " / DEF " <> T.pack (show defense))
      _ -> Nothing
  , (\desc -> "- " <> truncateDescription desc) <$> yugiohDescription card
  ]
  where
    truncateDescription desc =
      let clean = T.replace "\n" " " desc
      in if T.length clean > 200 then T.take 200 clean <> "..." else clean

formatMtgCardAlt :: MtgCard -> Text
formatMtgCardAlt card = altParts
  [ Just (mtgName card)
  , mtgManaCost card
  , ("- " <>) <$> mtgTypeLine card
  , ("- " <>) . T.replace "\n" " " <$> mtgOracleText card
  , case (mtgPower card, mtgToughness card) of
      (Just powerValue, Just toughnessValue) -> Just ("- " <> powerValue <> "/" <> toughnessValue)
      _ -> Nothing
  ]

formatMtgFaceAlt :: MtgFace -> Text
formatMtgFaceAlt face = altParts
  [ Just (mtgFaceName face)
  , mtgFaceManaCost face
  , ("- " <>) <$> mtgFaceTypeLine face
  , ("- " <>) . T.replace "\n" " " <$> mtgFaceOracleText face
  , case (mtgFacePower face, mtgFaceToughness face) of
      (Just powerValue, Just toughnessValue) -> Just ("- " <> powerValue <> "/" <> toughnessValue)
      _ -> Nothing
  ]

-- =============================================================================
-- Franchise loading helpers
-- =============================================================================

-- | Load JSON files from a directory, decode each, and fold results.
-- Shared scaffolding for all franchise loaders. The caller provides:
--   - a predicate to filter which .json files to load
--   - a function that receives (filename, decoded cards) and folds into the accumulator
loadFranchiseDir :: FromJSON a
                 => FilePath                                  -- ^ Directory to scan
                 -> (String -> Bool)                          -- ^ File filter
                 -> acc                                       -- ^ Initial accumulator
                 -> (acc -> String -> [a] -> acc)             -- ^ Fold: acc -> filename -> cards -> acc
                 -> IO acc
loadFranchiseDir dir fileFilter initial foldFile =
  withDirectoryOrDefault (pure initial) dir $ do
    jsonFiles <- sort . filter fileFilter <$> listDirectory dir
    foldM processFile initial jsonFiles
  where
    processFile acc filename = do
      let path = dir </> filename
      result <- decodeJSONFile path
      case result of
        Nothing -> do
          putStrLn $ "  Warning: Failed to parse " ++ path
          return acc
        Just cards -> return $ foldFile acc filename cards

-- | Standard filter: all .json files
isJSON :: String -> Bool
isJSON f = takeExtension f == ".json"

-- | Insert a card under both its bare name and a franchise-prefixed key.
-- Common pattern: every franchise registers "name" and "franchise:name".
insertKeyed :: Text -> Text -> CardData -> Map Text CardData -> Map Text CardData
insertKeyed franchise name cardData =
  Map.insert (franchise <> ":" <> name) cardData . Map.insert name cardData

-- =============================================================================
-- Franchise loaders
-- =============================================================================

-- | Load Pokemon cards from config/pokemon/*.json
-- Keys: bare name (first occurrence), pokemon:name, set:name
-- Pokemon is the only franchise that tracks first-occurrence for bare names
-- (reprints across sets shouldn't overwrite the original bare-name entry).
loadPokemon :: FilePath -> IO (Map Text CardData)
loadPokemon configDir =
  fst <$> loadFranchiseDir (configDir </> "pokemon") isPokemonJSON (Map.empty, Set.empty) foldSet
  where
    -- en.json is a set metadata index (set names, release dates), not card data
    isPokemonJSON f = isJSON f && takeBaseName f /= "en"

    foldSet (acc, seen) filename cards =
      let setCode = T.pack $ takeBaseName filename
      in foldl' (addCard setCode) (acc, seen) cards

    addCard setCode (acc, seen) card =
      let name = pokemonName card
          imagePath = flattenImagePath (pokemonImage card)
          cardData = CardData name (formatPokemonAlt card) imagePath "pokemon"
          -- Always register set:name and pokemon:name
          withKeys = Map.insert (setCode <> ":" <> name) cardData
                   $ Map.insert ("pokemon:" <> name) cardData acc
      in if Set.member name seen
         then (withKeys, seen)
         else (Map.insert name cardData withKeys, Set.insert name seen)

-- | Load Yu-Gi-Oh cards from config/yugioh/*.json
-- Keys: bare name, yugioh:name
loadYugioh :: FilePath -> IO (Map Text CardData)
loadYugioh configDir =
  loadFranchiseDir (configDir </> "yugioh") isJSON Map.empty foldCards
  where
    foldCards acc _ = foldl' addCard acc

    addCard acc card =
      let name = yugiohName card
          imagePath = flattenImagePath (yugiohImage card)
          cardData = CardData name (formatYugiohAlt card) imagePath "yugioh"
      in insertKeyed "yugioh" name cardData acc

-- | Load MTG cards from config/mtg/*.json
-- Handles DFC: each face becomes its own entry
-- Keys: bare name, mtg:name
loadMtg :: FilePath -> IO (Map Text CardData)
loadMtg configDir =
  loadFranchiseDir (configDir </> "mtg") isJSON Map.empty foldCards
  where
    foldCards acc _ = foldl' addCard acc

    addCard acc card = case mtgCardFaces card of
      Just faces@(front:_) ->
        -- DFC: each face gets its own entry, full name points to front face
        let fullCardData = CardData (mtgName card) (formatMtgFaceAlt front)
                             (flattenImagePath $ mtgFaceImage front) "mtg"
            faceEntries = Map.fromList $ concatMap faceKeys faces
        in insertKeyed "mtg" (mtgName card) fullCardData
         $ Map.union faceEntries acc
      _ ->
        let cardData = CardData (mtgName card) (formatMtgCardAlt card)
                         (flattenImagePath $ mtgImage card) "mtg"
        in insertKeyed "mtg" (mtgName card) cardData acc

    faceKeys face =
      let cardData = CardData (mtgFaceName face) (formatMtgFaceAlt face)
                       (flattenImagePath $ mtgFaceImage face) "mtg"
          name = mtgFaceName face
      in [("mtg:" <> name, cardData), (name, cardData)]

-- =============================================================================
-- Content scanning
-- =============================================================================

-- | Cards always included (UI elements like the CardNotice example)
alwaysInclude :: [Text]
alwaysInclude = [exampleCardName]

-- | Scan content/ for [Card Name]{.card ...} references using Pandoc's parser
scanCardReferences :: ReaderOptions -> FilePath -> IO (Set Text)
scanCardReferences opts contentDir =
  withDirectoryOrDefault (pure Set.empty) contentDir $ do
    mdFiles <- findFiles [".md"] contentDir
    refs <- forM mdFiles $ \path -> do
      content <- TIO.readFile path
      result <- runIO (readMarkdown opts content)
      case result of
        Left err -> do
          putStrLn $ "  Warning: Failed to parse " ++ path ++ ": " ++ show err
          return Set.empty
        Right doc ->
          return $ Set.fromList (extractCardSpans doc)
    return $ Set.unions refs <> Set.fromList alwaysInclude

-- | Extract card lookup keys from a parsed Pandoc document
-- Finds all Span nodes with class "card" and builds the same lookup keys
-- that Transforms.Cards.transformInline would use.
extractCardSpans :: Pandoc -> [Text]
extractCardSpans = query extractSpan
  where
    extractSpan (Span (_ident, classes, attributes) inlines)
      | "card" `elem` classes =
          let name = normalizeQuotes (stringify inlines)
              setCode = lookup "set" attributes
              source  = lookup "source" attributes
          in [buildKey name setCode source]
    extractSpan _ = []

    buildKey name (Just set) _       = set <> ":" <> name
    buildKey name Nothing (Just src) = src <> ":" <> name
    buildKey name Nothing Nothing    = name

-- | Normalize smart quotes to straight quotes for cache lookup.
-- Pandoc's smart typography converts ' to U+2019 etc., but the card cache
-- uses straight quotes (from JSON data).
normalizeQuotes :: Text -> Text
normalizeQuotes = T.map normalize
  where
    normalize '\x2019' = '\''  -- right single quote -> apostrophe
    normalize '\x2018' = '\''  -- left single quote -> apostrophe
    normalize '\x201C' = '"'   -- left double quote -> straight
    normalize '\x201D' = '"'   -- right double quote -> straight
    normalize c = c

-- =============================================================================
-- Image copying
-- =============================================================================

-- | Collect deduplicated image paths for referenced cards
referencedImages :: Map Text CardData -> Set Text -> Set Text
referencedImages allCards referenced =
  Set.fromList $ mapMaybe getImage (Set.toList referenced)
  where
    getImage key = Map.lookup key allCards >>= cardImage

-- | Copy a single image if source exists and dest doesn't.
-- Returns True if a new copy was made.
copyImage :: FilePath -> FilePath -> Text -> IO Bool
copyImage configDir destDir flatPath = do
  let sourcePath = configDir </> unflattenImagePath (T.unpack flatPath)
      destPath = destDir </> T.unpack flatPath
  sourceExists <- doesFileExist sourcePath
  if not sourceExists
    then do
      putStrLn $ "  Warning: Image not found: " ++ sourcePath
      return False
    else do
      destExists <- doesFileExist destPath
      if destExists
        then return False  -- already copied; writing would re-trigger Hakyll's watcher
        else do
          createDirectoryIfMissing True (takeDirectory destPath)
          BS.readFile sourcePath >>= BS.writeFile destPath
          return True

-- | Copy images for referenced cards from config/*/images/ to static/images/cards/
copyCardImages :: FilePath -> FilePath -> Map Text CardData -> Set Text -> IO Int
copyCardImages configDir destDir allCards referenced = do
  createDirectoryIfMissing True destDir
  let images = referencedImages allCards referenced
  copied <- mapM (copyImage configDir destDir) (Set.toList images)
  return $ length [() | True <- copied]

-- | pokemon/base1-1.webp -> pokemon/images/base1-1.webp
unflattenImagePath :: FilePath -> FilePath
unflattenImagePath path = case break (== '/') path of
  (franchise, '/':rest) -> franchise </> "images" </> rest
  _                     -> path

-- =============================================================================
-- Main entry point
-- =============================================================================

-- | Build card cache from franchise JSON files, scan content, copy images
buildCardCache :: ReaderOptions -> FilePath -> FilePath -> FilePath -> IO CardCache
buildCardCache readerOpts configDir contentDir staticCardsDir = do
  putStrLn "Building card cache from local data..."

  pokemon <- loadPokemon configDir
  putStrLn $ "  Pokemon: " ++ show (Map.size pokemon) ++ " entries"

  yugioh <- loadYugioh configDir
  putStrLn $ "  Yu-Gi-Oh: " ++ show (Map.size yugioh) ++ " entries"

  mtg <- loadMtg configDir
  putStrLn $ "  MTG: " ++ show (Map.size mtg) ++ " entries"

  -- Merge: for bare-name collisions, MTG > Pokemon > Yu-Gi-Oh
  -- (Map.union is left-biased)
  let allCards = mtg `Map.union` pokemon `Map.union` yugioh
  putStrLn $ "  Total: " ++ show (Map.size allCards) ++ " entries in cache"

  -- Copy images for cards actually referenced in content
  putStrLn "Scanning content for card references..."
  referenced <- scanCardReferences readerOpts contentDir
  putStrLn $ "  Found " ++ show (Set.size referenced) ++ " unique card references"

  putStrLn "Copying images for referenced cards..."
  copied <- copyCardImages configDir staticCardsDir allCards referenced
  putStrLn $ "  Copied " ++ show copied ++ " images"

  return $ CardCache allCards

-- =============================================================================
-- Helpers
-- =============================================================================

-- | Flatten image path: pokemon/images/x.webp -> pokemon/x.webp
flattenImagePath :: Maybe Text -> Maybe Text
flattenImagePath = fmap flatten
  where
    flatten path = case T.splitOn "/" path of
      (franchise : "images" : rest) -> T.intercalate "/" (franchise : rest)
      _ -> path

-- | Decode a JSON file, returning Nothing on failure
decodeJSONFile :: FromJSON a => FilePath -> IO (Maybe a)
decodeJSONFile path = do
  result <- try (BS.readFile path) :: IO (Either SomeException BS.ByteString)
  case result of
    Left _   -> return Nothing
    Right bs -> return $ Aeson.decodeStrict bs