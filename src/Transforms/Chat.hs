-- =============================================================================
-- Chat Component Transform
--
-- Syntax:
--   ::: chat
--   @DisplayName[avatar-key]: Message text here.
--   @Alice[alice]: Hey, what's up?
--   @Bob[bob]: Not much!
--   :::
--
-- - DisplayName: What shows in the chat bubble
-- - avatar-key: Looked up in config/avatars.toml
-- - If avatar-key is missing or not in config, uses default + warning.
--
-- Output:
--   <div class="chat">
--     <div class="chat-message">
--       <img class="chat-avatar" src="/images/avatars/alice.webp" alt="Alice">
--       <div class="chat-bubble">
--         <span class="chat-name">Alice</span>
--         <div class="chat-content">Hey, what's up?</div>
--       </div>
--     </div>
--   </div>
-- =============================================================================

module Transforms.Chat (chatTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import Data.Text (Text)
import qualified Data.Text as T
import Config (AvatarConfig, resolveAvatar)
import Debug.Trace (trace)

-- | A parsed chat message
data ChatMessage = ChatMessage
  { messageName   :: !Text   -- ^ Display name
  , messageAvatar :: !Text   -- ^ Avatar key (looked up in config)
  , messageBlocks :: ![Block]  -- ^ Message content blocks
  }

-- | Build a rendered chat message block
buildMessage :: AvatarConfig -> ChatMessage -> Block
buildMessage config message =
  let avatarPath = resolveAvatar "Chat" (messageAvatar message) config
      displayName = messageName message
      avatarImg = Image ("", ["chat-avatar"], []) [Str displayName] (avatarPath, "")
      nameSpan = Span ("", ["chat-name"], []) [Str displayName]
  in Div ("", ["chat-message"], [])
       [ Plain [avatarImg]
       , Div ("", ["chat-bubble"], [])
           (Plain [nameSpan] : [Div ("", ["chat-content"], []) (messageBlocks message)])
       ]

-- | Extract avatar key from a Pandoc Citation node.
--
-- Why Citation? We're hijacking Pandoc's academic citation syntax.
-- @Alice[avatar-key] in markdown is parsed by Pandoc as a citation where
-- citationId = "Alice" and citationSuffix = [Str "avatar-key"] (Pandoc
-- thinks the bracket part is a page locator like @Smith[p. 42]).
-- This gives us structured parsing of "display name + avatar key" for free.
-- Citation syntax has been stable since Pandoc 1.x.
avatarKeyFrom :: Citation -> Text
avatarKeyFrom citation =
  case citationSuffix citation of
    (Str key : _) -> key
    _ -> trace (T.unpack $ "[WARN] Chat @" <> citationId citation <> " has no avatar key, using default")
               "default"

-- | Parse a chat div's content into messages
-- Groups blocks by speaker: each @Name[avatar]: starts a new message,
-- subsequent blocks (including code blocks) belong to that message.
parseChat :: AvatarConfig -> [Block] -> [Block]
parseChat config blocks = map (buildMessage config) (groupByMessage blocks)
  where
    -- foldr processes blocks right-to-left: when we hit a speaker, we
    -- prepend it to groups (preserving document order) and attach any
    -- accumulated content blocks that followed it.
    groupByMessage :: [Block] -> [ChatMessage]
    groupByMessage [] = []
    groupByMessage inputBlocks =
      let (groups, orphans) = foldr collectBlock ([], []) inputBlocks
      in case orphans of
           (_:_) -> trace "[WARN] Chat div has content before first @Speaker[key]: line" groups
           []    -> groups

    -- Accumulator is (completed messages, content blocks waiting for a speaker)
    collectBlock :: Block -> ([ChatMessage], [Block])
                 -> ([ChatMessage], [Block])
    collectBlock block (groups, pending) =
      case extractSpeaker block of
        Just speaker ->
          let combined = speaker { messageBlocks = messageBlocks speaker ++ pending }
          in (combined : groups, [])
        Nothing -> (groups, block : pending)

    -- Extract speaker info from a block if it starts with @Name[avatar]:
    extractSpeaker :: Block -> Maybe ChatMessage
    extractSpeaker (Para inlines) = extractFromInlines Para inlines
    extractSpeaker (Plain inlines) = extractFromInlines Plain inlines
    extractSpeaker _ = Nothing

    extractFromInlines :: ([Inline] -> Block) -> [Inline] -> Maybe ChatMessage
    extractFromInlines toBlock (Cite (citation:_) _ : rest) =
      -- Cite node = Pandoc parsed @Name[key] as a citation (see avatarKeyFrom).
      -- Strip colon+space after it: "@Name[key]: message"
      -- Pandoc tokenizes the colon inconsistently: sometimes Str ":" : Space,
      -- sometimes Str ":message" with colon glued to text
      case stripColon rest of
        Just contentInlines ->
          Just $ ChatMessage (citationId citation) (avatarKeyFrom citation)
            (if null contentInlines then [] else [toBlock contentInlines])
        Nothing -> Nothing
    extractFromInlines _ _ = Nothing

    stripColon :: [Inline] -> Maybe [Inline]
    stripColon (Str ":" : Space : rest) = Just rest
    stripColon (Str t : rest)
      | ":" `T.isPrefixOf` t =
          let after = T.drop 1 t
          in Just $ if T.null after then rest else Str after : rest
    stripColon _ = Nothing

-- | Transform chat divs into message bubbles
transformChat :: AvatarConfig -> Block -> Block
transformChat config (Div (_ident, classes, _) content)
  | "chat" `elem` classes =
      Div ("", ["chat"], []) (parseChat config content)
transformChat _ x = x

-- | Apply to document
chatTransform :: AvatarConfig -> Pandoc -> Pandoc
chatTransform config = walk (transformChat config)