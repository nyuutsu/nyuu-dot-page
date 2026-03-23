-- =============================================================================
-- Admonition Transform
--
-- Syntax:
--   ::: note
--   Content here.
--   :::
--
--   ::: warning Watch Out!
--   Custom title (everything after type name).
--   :::
--
-- Types are defined in config/admonitions.toml (single source of truth).
-- Unknown types pass through as plain divs (fenced divs serve many purposes;
-- there's no reliable way to distinguish a typo from a different widget).
--
-- Output:
--   <div class="admonition" style="--adm-bg: #304f60; --adm-border: #007acc" role="note">
--     <span class="admonition-title">
--       <img class="admonition-icon" src="/images/icons/note.png" alt="">Note
--     </span>
--     <div class="admonition-content">...</div>
--   </div>
-- =============================================================================

module Transforms.Admonitions (admonitionTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as Text
import Control.Applicative ((<|>))
import Data.Maybe (fromMaybe)
import Config (AdmonitionConfig, AdmonitionType(..), lookupAdmonition)

-- | Build transform with config
admonitionTransform :: AdmonitionConfig -> Pandoc -> Pandoc
admonitionTransform config = walk (transformBlock config)

-- | Resolve the display title from three sources (first Just wins):
--   1. Custom title from extra classes ("::: warning Watch Out!")
--   2. Explicit title attribute ("::: {.warning title="Watch Out!"}")
--   3. Default name from config ("Warning")
resolveTitle :: Maybe Text -> [(Text, Text)] -> AdmonitionType -> Text
resolveTitle customTitle attributes typeConfig =
  fromMaybe (admonitionName typeConfig) $
    customTitle <|> lookup "title" attributes

-- | Transform div into admonition if the first class is a known admonition type.
-- One lookup does both the matching and the config retrieval.
transformBlock :: AdmonitionConfig -> Block -> Block
transformBlock config (Div (identifier, classes, attributes) content)
  | (typeName:rest) <- classes
  , Just typeConfig <- lookupAdmonition (Text.toLower typeName) config =
      let customTitle = if null rest then Nothing else Just (Text.unwords rest)
          title = resolveTitle customTitle attributes typeConfig
          -- Title with optional icon
          titleInlines = case admonitionIcon typeConfig of
            "none" -> [Str title]
            icon   -> [ Image ("", ["admonition-icon"], [("alt", "")]) [] ("/images/icons/" <> icon, "")
                       , Str title ]
          titleBlock = Plain [Span ("", ["admonition-title"], []) titleInlines]
          contentDiv = Div ("", ["admonition-content"], []) content
          -- CSS custom properties for per-type colors
          styleValue = "--adm-bg: " <> admonitionBackground typeConfig
                    <> "; --adm-border: " <> admonitionBorder typeConfig
      in Div (identifier, ["admonition"], [("style", styleValue), ("role", "note")])
             [titleBlock, contentDiv]
transformBlock _ x = x