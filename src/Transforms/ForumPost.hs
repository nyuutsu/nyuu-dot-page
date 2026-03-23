-- =============================================================================
-- Forum Post Transform
-- Converts ::: forum-post / ::: forum-reply divs into old.reddit.com-style
-- post layout with avatar sidebar and content area.
--
-- Syntax:
--   ::: {.forum-post name="Display Name" avatar="avatar-key" title="Member" posts="1234"}
--   Post content here.
--   :::
--
--   ::: {.forum-reply name="Other Person" avatar="other-key" title="Newbie" posts="5"}
--   Reply content.
--   :::
--
-- Required: name (display name), avatar (key in config/avatars.toml)
-- Optional: title, posts
-- If omitted: name defaults to "Anonymous" + warning, avatar uses default + warning.
--
-- Output:
--   <div class="forum-post|forum-reply">
--     <div class="forum-sidebar">
--       <img class="forum-avatar" src="/images/avatars/..." alt="Name">
--       <span class="forum-author">Name</span>
--       <span class="forum-title">Title</span>
--       <span class="forum-posts">Posts: 1234</span>
--     </div>
--     <div class="forum-content">...</div>
--   </div>
-- =============================================================================

module Transforms.ForumPost (forumPostTransform) where

import Text.Pandoc.Walk (walk)
import Text.Pandoc.Definition
import qualified Data.Text as Text
import Data.Maybe (catMaybes)
import Config (AvatarConfig, resolveAvatar)
import Debug.Trace (trace)

-- | Transform forum divs into post layout
transformForum :: AvatarConfig -> Block -> Block
transformForum config (Div (identifier, classes, attributes) content)
  | "forum-post" `elem` classes || "forum-reply" `elem` classes =
      let divClass = if "forum-reply" `elem` classes then "forum-reply" else "forum-post"
          -- name = display name, avatar = avatar lookup key (warn if missing)
          displayName = case lookup "name" attributes of
            Just found -> found
            Nothing -> trace (Text.unpack $ "[WARN] " <> divClass <> " missing name attribute, using Anonymous")
                             "Anonymous"
          avatarKey = case lookup "avatar" attributes of
            Just found -> found
            Nothing -> trace (Text.unpack $ "[WARN] " <> divClass <> " missing avatar attribute, using default")
                             "default"

          avatarPath = resolveAvatar divClass avatarKey config
          avatarImg = Image ("", ["forum-avatar"], []) [Str displayName] (avatarPath, "")

          -- Sidebar: required elements are Just, optional ones use fmap
          sidebar = Div ("", ["forum-sidebar"], []) $ catMaybes
            [ Just $ Plain [avatarImg]
            , Just $ Plain [Span ("", ["forum-author"], []) [Str displayName]]
            , fmap (\t -> Plain [Span ("", ["forum-title"], []) [Str t]]) (lookup "title" attributes)
            , fmap (\p -> Plain [Span ("", ["forum-posts"], []) [Str ("Posts: " <> p)]]) (lookup "posts" attributes)
            ]
          contentBlock = Div ("", ["forum-content"], []) content

      in Div (identifier, [divClass], []) [sidebar, contentBlock]
transformForum _ x = x

-- | Apply to document
forumPostTransform :: AvatarConfig -> Pandoc -> Pandoc
forumPostTransform config = walk (transformForum config)