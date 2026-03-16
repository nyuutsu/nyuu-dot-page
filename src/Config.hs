-- =============================================================================
-- Config
-- Loads configuration from TOML files
--
-- Config files are the single source of truth:
--   config/admonitions.toml - admonition types (name, icon, colors)
--   config/avatars.toml     - avatar key → filename mappings
-- =============================================================================

module Config
  ( -- * Admonitions
    AdmonitionType(..)
  , AdmonitionConfig
  , loadAdmonitionConfig
  , lookupAdmonition
    -- * Avatars
  , AvatarConfig
  , loadAvatarConfig
  , lookupAvatar
  , defaultAvatarFile
  , resolveAvatar
  ) where

import Toml (TomlCodec, (.=))
import qualified Toml
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.HashMap.Strict as HM
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Maybe (fromMaybe)
import Debug.Trace (trace)

-- =============================================================================
-- Admonitions
-- =============================================================================

-- | Configuration for a single admonition type
data AdmonitionType = AdmonitionType
  { admonitionKey        :: !Text    -- ^ Type key (e.g., "note", "warning")
  , admonitionName       :: !Text    -- ^ Display name (e.g., "Note", "Warning")
  , admonitionIcon       :: !Text    -- ^ Icon filename or "none"
  , admonitionBackground :: !Text    -- ^ Background color (hex)
  , admonitionBorder     :: !Text    -- ^ Border color (hex)
  } deriving (Show)

-- | Codec for a single admonition type entry
admonitionTypeCodec :: TomlCodec AdmonitionType
admonitionTypeCodec = AdmonitionType
  <$> Toml.text "key"    .= admonitionKey
  <*> Toml.text "name"   .= admonitionName
  <*> Toml.text "icon"   .= admonitionIcon
  <*> Toml.text "bg"     .= admonitionBackground
  <*> Toml.text "border" .= admonitionBorder

-- | Wrapper for the config file (list of types)
newtype AdmonitionFile = AdmonitionFile { admonitionTypes :: [AdmonitionType] }

admonitionFileCodec :: TomlCodec AdmonitionFile
admonitionFileCodec = AdmonitionFile
  <$> Toml.list admonitionTypeCodec "type" .= admonitionTypes

-- | Map from type name to configuration
type AdmonitionConfig = Map Text AdmonitionType

-- | Load admonition config from TOML file
-- Crashes on missing/malformed file; startup should fail loudly if config is wrong. Admonition config
-- is required for the site to render correctly; a graceful fallback would
-- silently produce broken output.
loadAdmonitionConfig :: FilePath -> IO AdmonitionConfig
loadAdmonitionConfig path = do
  content <- TIO.readFile path
  case Toml.decode admonitionFileCodec content of
    Left errs -> error $ "Failed to load " ++ path ++ ": " ++ show errs
    Right file -> return $ Map.fromList [(admonitionKey t, t) | t <- admonitionTypes file]

-- | Look up an admonition type, returning Nothing if not found
lookupAdmonition :: Text -> AdmonitionConfig -> Maybe AdmonitionType
lookupAdmonition = Map.lookup

-- =============================================================================
-- Avatars
-- =============================================================================

-- | Map from avatar key to filename
type AvatarConfig = Map Text Text

-- | Codec for avatar table (returns HashMap, converted to Map in load)
avatarFileCodec :: TomlCodec (HM.HashMap Text Text)
avatarFileCodec = Toml.tableHashMap Toml._KeyText Toml.text "avatars"

-- | Load avatar config from TOML file
-- Crashes on missing/malformed file; same rationale as loadAdmonitionConfig.
loadAvatarConfig :: FilePath -> IO AvatarConfig
loadAvatarConfig path = do
  content <- TIO.readFile path
  case Toml.decode avatarFileCodec content of
    Left errs -> error $ "Failed to load " ++ path ++ ": " ++ show errs
    Right table -> return $ Map.fromList (HM.toList table)

-- | Look up avatar filename by key, returning Nothing if not found.
-- Callers handle the fallback/warning; see defaultAvatarFile.
lookupAvatar :: Text -> AvatarConfig -> Maybe Text
lookupAvatar = Map.lookup

-- | The default avatar filename from config (falls back to "robot.webp"
-- if no "default" key exists in the TOML).
defaultAvatarFile :: AvatarConfig -> Text
defaultAvatarFile = Map.findWithDefault "robot.webp" "default"

-- | Resolve an avatar key to a full image path, warning on missing keys.
-- context: identifies the caller for the warning (e.g., "Chat", "forum-post")
resolveAvatar :: Text -> Text -> AvatarConfig -> Text
resolveAvatar context key config =
  let file = fromMaybe
        (trace (T.unpack $ "[WARN] " <> context <> " avatar '" <> key <> "' not in config, using default")
               (defaultAvatarFile config))
        (lookupAvatar key config)
  in "/images/avatars/" <> file