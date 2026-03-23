# CLAUDE.md

Hakyll static site. Haskell transforms on the Pandoc AST, SCSS
styling, config in TOML/JSON.

## Project constraints

- **No JavaScript.** All interactivity via CSS. If it genuinely
  can't be done without JS, say so rather than silently adding
  a script.
- **Self-hosted assets.** Local fonts, no CDNs, no external
  dependencies at runtime.
- **Bilingual.** English and Japanese content; font stacks must
  handle both.
- **Accessible by default.** Semantic HTML, meaningful alt text,
  `lang` attributes, CLS prevention. Do it right even when nobody
  checks.
- **Pandoc-native syntax.** Fenced divs, bracketed spans. Transforms
  are pure `Pandoc -> Pandoc`. Config lives in TOML/JSON, not code.
- **Respect settled patterns.** Don't propose alternatives to the
  above without explicitly flagging the departure and explaining why.

## Layout & Responsive Behavior

### How the layout works

The site is a content column (`$max-width-page: max(85ch, 50vw)`) centered on a granite-textured background. The granite gutters are the design — they're visible on any screen wider than the column. The column width is `85ch` (~75 characters) with a `50vw` floor that prevents the column from shrinking when the user zooms out. On ultrawides (21:9+), the vw floor is dropped and the column uses pure `85ch`.

### Breakpoint rules

**All breakpoints must bake in ~15-20% horizontal buffer for vertical-tab users.** A breakpoint targeting 1920px screens should be set at ~1500px so that a 1920px user with a vertical tab sidebar (~1536px effective viewport) is captured by the breakpoint. Breakpoints are named by device class, not resolution.

### Testing responsive changes

Verify at real sizes: phone (~375px), tablet (~768px), laptop (1366px), desktop (1920px with and without vertical tabs), 1440p (2560px), and 4K (3840px). Breakpoints are in `_variables.scss`.

## Build System (site.hs)

### Current Structure

`site.hs` is orchestration: config loading, route rules, clean URLs. All transform logic lives in `src/Transforms/*.hs`.

### Extending the Build

1. **New transforms** go in `src/Transforms/NewThing.hs`, re-exported via `Transforms.hs`
2. **New config** goes in `config/`, loaded via `preprocess` in `site.hs`, threaded through `allTransforms`
3. **Keep site.hs as orchestration** — it should read like a table of contents
4. **Update `nyuu-dot-page.cabal`** to include new modules in `other-modules`

### Pandoc Extensions in Use

Currently enabled:
- `fenced_divs` - For admonitions (`::: note`)
- `bracketed_spans` - For inline class application (`[text]{.class}`)
- `implicit_figures` - Images with alt text become `<figure>` with `<figcaption>`

These allow widget markup without raw HTML in markdown.

## File Organization

```
nyuu-dot-page/
├── CLAUDE.md               # This file
├── site.hs                 # Hakyll generator
├── nyuu-dot-page.cabal     # Project config
├── Makefile                # Build orchestration (make build)
│
├── config/                 # Configuration files (single source of truth)
│   ├── admonitions.toml    # Admonition types: name, icon, colors
│   ├── avatars.toml        # Avatar key → filename mappings
│   ├── font-subset.py      # Subsets Latin/JP fonts to used chars
│   ├── pyproject.toml      # Python deps for font-subset.py (uv)
│   ├── fonts-src/          # Pool fonts (input to font-subset.py)
│   │   ├── IMFell{English,GreatPrimer,DoublePica,DWPica}-*.woff2  # ~90-113KB → ~41-51KB after subsetting
│   │   ├── OradanoGSRR.woff2             # 5.4MB → ~38KB after subsetting (Japanese body)
│   │   └── SarasaMonoJ-{Regular,Bold}.woff2  # ~9MB → ~50KB after subsetting (monospace)
│   ├── blobmoji/           # Emoji font builder
│   │   ├── pyproject.toml  # Heavier deps (nanoemoji), own venv
│   │   ├── svg-fixed/      # Source SVGs (1686 emoji)
│   │   └── build-subset.py # Builds font with only used emoji
│   ├── syntax/             # Custom Kate XML syntax definitions
│   ├── pokemon/            # Pokemon card data + images
│   ├── yugioh/             # Yu-Gi-Oh card data + images
│   └── mtg/                # MTG card data + images
│
├── src/                    # Haskell modules
│   ├── Transforms.hs       # Re-exports all transforms, documents ordering
│   ├── Config.hs           # TOML config loading (admonitions, avatars)
│   ├── CardCache.hs        # Builds card cache from franchise JSONs, copies images
│   ├── ImageDimensions.hs  # Scans images for dimensions (Rust imagesize via FFI)
│   ├── SyntaxMap.hs        # Custom Kate XML syntax definitions
│   └── Transforms/
│       ├── Admonitions.hs  # ::: note/warning/etc
│       ├── Anchors.hs      # Heading → clickable anchors
│       ├── Cards.hs        # [Name]{.card} → preview
│       ├── CardNotice.hs   # ::: cards → explanatory notice
│       ├── Chat.hs         # @user: message → bubbles
│       ├── FigureLink.hs   # .clickable images → linked to full size
│       ├── ForumPost.hs    # Forum post layout
│       ├── ImageDimensions.hs # Auto-inject width/height for CLS prevention
│       └── Japanese.hs     # CJK text → lang="ja", {kanji|reading} → ruby
│
├── content/                # Markdown source
│   ├── index.md            # Home (project showcase)
│   ├── posts/              # Blog posts (YYYY-MM-DD-slug.md)
│   └── *.md                # Static pages
│
├── scss/                   # Styles (modular)
│   ├── main.scss           # Entry point: textured main site
│   ├── smooth.scss         # Entry point: smooth main site (Source Serif 4)
│   ├── files.scss          # Entry point: files.nyuu.page (textured)
│   ├── files-smooth.scss   # Entry point: files.nyuu.page (smooth)
│   ├── _variables.scss     # Design tokens, mixins, !default font config
│   ├── _reset.scss         # CSS reset
│   ├── _typography.scss    # Font faces (via mixin), text styles, syntax colors
│   ├── _layout.scss        # Page structure (header, footer, nav, skip link)
│   ├── _components.scss    # UI elements (widgets)
│   ├── _smooth-overrides.scss  # Smooth font faces + SC→bold behavior
│   └── _files-base.scss    # File listing (table, grid, filter, breadcrumbs)
│
├── static/
│   ├── fonts/              # Output fonts (subsetted Latin/JP + Blobmoji full)
│   └── images/
│       ├── avatars/        # Chat/forum avatars
│       ├── cards/          # Card preview images (copied at build time by CardCache.hs)
│       └── icons/          # Admonition icons, social icons
│
├── templates/              # Hakyll templates
└── css/                    # Compiled CSS (gitignored, regenerate with sass)
```

## SCSS conventions

- `@use` not `@import` (modern module system)
- BEM-lite naming: `.component`, `.component-element`, `.component--modifier`
- New UI elements go in `_components.scss`; use existing variables from `_variables.scss`
- Max 3 levels of SCSS nesting; flatten if deeper
- No `!important`, no IDs for styling (only for anchor targets)
- Section separators use the `// ----` style
- Font stacks and root font sizes use `!default` in `_variables.scss`;
  entry points configure them via `@use 'variables' with (...)`
- `$asset-origin` (`!default`, empty for main site) prefixes all
  `url()` paths; files page sets it to `'https://nyuu.page'`
- New `@font-face` declarations use the `font-face()` mixin from
  `_variables.scss`, not hand-written blocks

## Haskell style

GHC2024 language edition. `OverloadedStrings` where Text literals
are needed. Strict fields on data types by default. `-Wall` clean,
zero warnings. No orphan instances.

**Be idiomatic.** Use the right combinator when it fits (`fromMaybe`,
`mapMaybe`, `concatMap`, `guard`, `groupBy`, `partition`, `on`).
Don't reimplement what the standard library provides.

**Descriptive names.** `pokemonName` not `pkName`, `yugiohAttack`
not `ygAtk`, `attackDamage` not `dmg`. Domain abbreviations that
ARE the standard term stay abbreviated: CJK, CLS, DFC, MTG.
When in doubt, spell it out.

**No shadowing, no prime-naming.** Don't reuse a binding name in
an inner scope. Don't use `x'` or `xs''` — if two things need
names, find two real names.

**Pattern matching** over if-chains. Guards over nested cases.

**Sugar is good when it's free.** `where` clauses, operator
sections, `<$>`, `<*>` — use them when they make code read better
without hiding meaning.

**Composability.** Small functions that combine well. When a real
pattern emerges, make a clean abstraction — three duplicated blocks
are worse than one clear function.

**New code follows the same rules.** Every naming convention here
applies equally to new code, refactors, and helpers introduced during
changes. If a rename pass cleaned something up, the same patterns
shouldn't come back in through new helpers or variables.
This includes test code.

**Qualified imports** for containers (`Map`, `Text`, `ByteString`).

**Comments explain WHY, not WHAT.** If a comment restates the code,
delete it.

**Proposals should be elegant** — but we discuss fit with the
project's direction before committing.

**Upgrade existing code** when touching it. Better names, better
combinators, clearer structure.

**Heavy IO goes to Rust** when needed — Rust via FFI for
performance-critical work, pure domain logic stays in Haskell.
This project doesn't use Rust currently but the preference applies
if it ever needs systems-level work.

Derive what's natural for the type. Closed enumerations should
have `Enum, Bounded`.

### Project-specific

- All external data loaded via `preprocess` in `site.hs` and
  threaded through transforms — no `unsafePerformIO`.
- `Debug.Trace` for build warnings in pure transforms (pragmatic
  choice — the alternatives add more ceremony than they're worth).
- Each transform is its own module with a single exported function.
- `Transforms.hs` composes all transforms via `.`; ordering
  constraints documented there.

## Working together

The user is learning Haskell alongside building. Teaching is part
of the work — not separate from it.

- Explain new concepts before using them — combinators, type
  signatures, patterns. Say what they mean and why they work.
  Lecture freely.
- Teach the user to write Haskell, not just watch it appear.
  Explain what to write and why, then have them write it.
- Go slow on structural changes and new abstractions. Discuss
  before committing. No bulk code drops.
- When upgrading code to better patterns, show before and after,
  explain what improved.
- If something isn't clear, stop and explain. Understanding
  matters more than progress.
- Commit messages describe what changed and why, in imperative mood
  ("Add X" rather than "Added X"). Keep subject lines under 72
  characters and put detail in the body when it's needed. Avoid
  em dashes in commit messages.

## Widget System

All widgets use Pandoc transforms to convert lean markdown syntax into semantic HTML. No raw HTML needed in content files.

### Card Previews

Hoverable card links with image preview on desktop. Supports Pokemon, Yu-Gi-Oh, and Magic: The Gathering.

**Syntax:**
```markdown
[Card Name]{.card}
[Card Name]{.card set="base1"}      (Pokemon set disambiguation)
[Card Name]{.card source="mtg"}     (franchise disambiguation)
[Card Name]{.card source="yugioh"}
```

**Attributes:**
- `set` - Pokemon set code (e.g., "base1", "basep") for reprints
- `source` - Franchise ("pokemon", "yugioh", "mtg") when card names collide

**Output:** `🎴Card Name` with hidden image that shows on hover.

**Alt text:** Built at startup from `config/{pokemon,yugioh,mtg}/*.json` by `CardCache.buildCardCache`. Includes full card data (type, abilities, stats).

**Card data locations:**
- `config/pokemon/*.json` + `config/pokemon/images/`
- `config/yugioh/*.json` + `config/yugioh/images/`
- `config/mtg/*.json` + `config/mtg/images/`

**Double-Faced Cards (DFC):** MTG cards with two faces (like "Delver of Secrets // Insectile Aberration") are supported. Each face becomes its own entry in the cache. To show both faces, reference them adjacently:
```markdown
[Delver of Secrets]{.card} [Insectile Aberration]{.card}
```

DFC JSON format in `config/mtg/*.json`:
```json
{
  "name": "Delver of Secrets // Insectile Aberration",
  "card_faces": [
    {"name": "Delver of Secrets", "mana_cost": "{U}", "type_line": "...", "oracle_text": "...", "image": "mtg/images/delver-front.jpg"},
    {"name": "Insectile Aberration", "mana_cost": "", "type_line": "...", "oracle_text": "...", "image": "mtg/images/delver-back.jpg"}
  ]
}
```

### Card Notice

Explanatory notice for posts with card previews. Insert at the start of posts that use cards.

**Syntax:**
```markdown
::: cards
:::
```

**Output:** A styled box explaining the hover feature with a Thalia example card.

### Admonitions

Callout boxes with floating label and icon.

**Types and colors are defined in `config/admonitions.toml` (single source of truth).**

**Syntax:**
```markdown
::: note
Content here.
:::

::: warning
Important warning.
:::

::: {.tip title="Custom Title"}
Custom title requires attribute syntax.
:::
```

**Types:** Defined in config. Default: `note`, `info`, `warning`, `caution`, `tip`, `danger`

**Unknown types:** Ignored (left as plain divs). Fenced divs are shared syntax across widgets, so unrecognized types are assumed to belong to another transform.

**To add a new type:**
1. Add entry to `config/admonitions.toml`
2. Drop icon in `static/images/icons/`
3. Rebuild

### Chat

Discord-style message bubbles.

**Syntax:**
```markdown
::: chat
@DisplayName[avatar-key]: Message text here.
@Alice[alice]: Hey, what's up?
@Bob[robot]: Not much!
:::
```

**Required:** Both display name AND avatar key in brackets.
- `DisplayName` → what shows in the chat bubble
- `avatar-key` → looked up in `config/avatars.toml`

**If avatar key is omitted or not in config:** Uses default avatar + build warning.

### Forum Posts

old.reddit.com-style post layout with sidebar.

**Syntax:**
```markdown
::: {.forum-post name="Display Name" avatar="avatar-key" title="Member" posts="1234"}
Post content here.
:::

::: {.forum-reply name="Other Person" avatar="other-key" title="Newbie" posts="5"}
Reply content.
:::
```

**Required attributes:**
- `name` → what displays as the username
- `avatar` → key looked up in `config/avatars.toml`

**Optional attributes:** `title`, `posts`

**If omitted:** `name` defaults to "Anonymous" + warning, `avatar` uses default + warning.

### Other Inline Widgets

**Greentext:**
```markdown
[implying something]{.greentext}
```

**Game text** (preserved spacing, dashed underline):
```markdown
[ゲームテキスト　　]{.game}
```

**Ruby/Furigana** (reading annotations for kanji):
```markdown
{漢|かん}{字|じ}
```
Output: `<ruby>漢<rt>かん</rt></ruby><ruby>字<rt>じ</rt></ruby>`

Ruby patterns and plain CJK are automatically grouped into a single `lang="ja"` span:
```markdown
{日|に}{本|ほん}{語|ご}を勉強する
```
Output: `<span lang="ja"><ruby>日<rt>に</rt></ruby><ruby>本<rt>ほん</rt></ruby><ruby>語<rt>ご</rt></ruby>を勉強する</span>`

**Keyboard keys:** Use raw HTML
```html
Press <kbd>Ctrl</kbd>+<kbd>C</kbd>
```

**Pixel art / GBC screenshots:** For retro game images with crisp integer scaling
```markdown
![Screenshot](gbc-screenshot.png){.gbc}
```
Uses integer zoom (2x → 3x → 4x) based on viewport width to keep pixels crisp. Works for any pixel art, not just GBC.

### Code Blocks

Pandoc handles syntax highlighting at build time. No client-side JavaScript.
Line numbers always display.

**Basic:**
````markdown
```haskell
main :: IO ()
main = putStrLn "Hello"
```
````

**Custom starting line number:**
````markdown
```{.c startFrom="42"}
int main(void) {
    return 0;
}
```
````

**Supported languages:** 155+ via Pandoc (haskell, python, rust, javascript, c, etc.).
For unsupported languages (e.g., Solidity), use `javascript` or omit the language tag.

**Long lines:** Horizontal scroll via `overflow-x: auto`.

## Config System

Widget behavior is driven by TOML files in `config/`. The Haskell transforms (`src/Transforms/*.hs`) read these at build time via `src/Config.hs`. This keeps styling/content data out of code.

### How It Works

1. **Markdown** uses a widget syntax (`::: warning`, `@Alice[alice]:`)
2. **Pandoc transform** parses the syntax and looks up the key in the TOML config
3. **Config data** (colors, icon paths, etc.) gets baked into the HTML output
4. **CSS** styles the output using the inline styles/classes from the transform

### `config/admonitions.toml`

Defines admonition types. When you write `::: warning`, `Transforms/Admonitions.hs` looks up "warning" here.

```toml
[[type]]
key = "warning"        # Matches ::: warning in markdown
name = "Warning"       # Display label in the rendered box
icon = "warning.png"   # Looked up in static/images/icons/ (use "none" for no icon)
bg = "#66512c"         # Background color (injected as inline style)
border = "#ffcc00"     # Border color (injected as inline style)
```

Set `icon = "none"` to omit the icon entirely. Unknown types pass through as plain divs (fenced divs are shared syntax across widgets).

### `config/avatars.toml`

Maps avatar keys to filenames. Used by `Transforms/Chat.hs` and `Transforms/ForumPost.hs`.

```toml
[avatars]
default = "robot.webp"           # Fallback for unknown keys
alice = "alice-avatar.webp"      # @Name[alice]: → /images/avatars/alice-avatar.webp
snoo = "snoo.webp"
```

Unknown keys use "default" with a build warning.

## Build Tools

**Python dependencies** are managed by uv via `pyproject.toml`:
- `config/pyproject.toml` — fonttools, brotli (for font-subset.py)
- `config/blobmoji/pyproject.toml` — nanoemoji, fonttools, brotli, resvg-cli (heavier deps, own venv)

First-time setup: `cd config && uv sync` and `cd config/blobmoji && uv sync`.
The Makefile calls font-subset.py via `uv run --project config`; blobmoji manages its own venv internally.

### Card Cache (Haskell)

`CardCache.buildCardCache` runs in Hakyll's `preprocess` step. No separate script or JSON cache file.

**What it does:**
1. Loads card data from `config/{pokemon,yugioh,mtg}/*.json`
2. Generates alt text for each card (name, type, abilities, stats)
3. Scans `content/` for `[Name]{.card}` references
4. Copies only referenced images from `config/*/images/` to `static/images/cards/`
5. Returns `CardCache` directly (no intermediate JSON)

**Card data structure:** Each franchise has its own directory:
- `config/pokemon/` - Set JSONs (base1.json, base2.json...) + images/
- `config/yugioh/` - Card JSONs + images/
- `config/mtg/` - Card JSONs + images/

**Lookup keys:** bare name (MTG > Pokemon > Yu-Gi-Oh for collisions), `source:name`, and `set:name` (Pokemon only).

Image copying skips files that already exist in the destination to avoid retriggering Hakyll's file watcher during `make watch`.

### Image Dimensions (Haskell)

`ImageDimensions.scanImageDimensions` runs in Hakyll's `preprocess` step. No separate script or JSON cache file.

**What it does:**
1. Recursively scans `static/images/` for PNG, JPEG, GIF, WebP (SVG excluded)
2. Reads dimensions via Rust `imagesize` crate through FFI
3. Returns `ImageDimensions` map directly

The transform (`Transforms/ImageDimensions.hs`) injects `width` and `height` attributes into `<img>` tags for CLS prevention.

### Font Subsetter (Python)

Located at `config/font-subset.py`. Creates minimal font files containing only characters actually used in content.

**Run via Makefile:**
```bash
make build  # Runs font-subset.py automatically
```

**What it does:**
1. Scans `content/**/*.md` and `src/**/*.hs` for characters in target Unicode ranges
2. For each font in `config/fonts-src/`, creates a subset containing only used characters
3. Outputs subsetted fonts to `static/fonts/`

**Fonts subsetted (via font-subset.py):**
- `IMFell{English,GreatPrimer,DoublePica,DWPica}-*.woff2` — IM Fell Types family (4 optical sizes, each with Regular/Italic/SC)
- `OradanoGSRR.woff2` — Japanese body font (1909 Tsukiji revival; only used characters kept)
- `SarasaMonoJ-{Regular,Bold}.woff2` — Monospace (Iosevka + Source Han Sans; Latin + CJK for code)

**Fonts subsetted (via blobmoji/build-subset.py):**
- `Blobmoji.woff2` — Emoji (built from scratch with nanoemoji, includes only emoji used in content)

**Pool vs Output:**
- `config/fonts-src/` contains full "pool" fonts with all glyphs
- `static/fonts/` contains subsetted output (deployed to site)
- Re-run `make build` when adding content with new characters

## Common Tasks

### Adding a new admonition type

1. Add entry to `config/admonitions.toml`:
   ```toml
   [[type]]
   key = "custom"
   name = "Custom"
   icon = "custom.png"
   bg = "#2d4a3e"
   border = "#27ae60"
   ```

2. Drop icon in `static/images/icons/custom.png`

3. Rebuild

### Adding a new avatar

1. Add entry to `config/avatars.toml`:
   ```toml
   my-avatar = "my-avatar.webp"
   ```

2. Drop image in `static/images/avatars/my-avatar.webp`

3. Use in markdown: `avatar="my-avatar"`

### Adding a new font

Every font ships subsetted — only glyphs actually used in content.
The mechanism varies by font type:

**Text fonts** (Latin, CJK, monospace) — subsetted via `font-subset.py`:
1. Add full `.woff2` file to `config/fonts-src/`
2. Add font config to `FONTS` dict in `config/font-subset.py`
3. Add `@font-face` in `_typography.scss` (pointing to `static/fonts/`)
4. Run `make build` to generate subsetted output

**Emoji fonts** — built from scratch via `config/blobmoji/build-subset.py`:
1. Add SVG artwork to `config/blobmoji/svg-fixed/`
2. The build script scans content for used emoji and compiles only those
3. Output lands in `static/fonts/`

### Adding a Pandoc transform

1. Create `src/Transforms/NewThing.hs` with a single exported function `newThingTransform :: Pandoc -> Pandoc` (or taking config if needed)
2. Add to `other-modules` in `nyuu-dot-page.cabal`
3. Re-export from `Transforms.hs` and add to the `allTransforms` composition chain (respect ordering constraints — document why if position matters)
4. If the transform needs external config, load it via `preprocess` in `site.hs` and thread through `allTransforms`
5. Document syntax and output in the module header comment

## Glyph Coverage

**When adding Unicode characters to content or Haskell transforms, check that they actually render.** The site self-hosts all fonts; there is no system font fallback guarantee for visitors. If a glyph shows as a box in the browser, it needs to be either:
1. Covered by one of the shipped fonts (IM Fell Types, Oradano Mincho, Sarasa Mono J, Blobmoji)
2. Replaced with a better-supported codepoint
3. Shipped via a new font added to the pipeline

The Blobmoji build script logs "not in Blobmoji" warnings — pay attention to these. Not all of them are problems (e.g. ★ U+2605 and ❯ U+276F are rendered by IM Fell/serif fallback, not Blobmoji), but any glyph that no shipped font covers will be a box for visitors. **Flag missing glyphs to the user rather than silently using them.**

## Intentional Choices

- The site uses `old.reddit.com` intentionally for the Reddit link
- Wikipedia link goes to Special:Contributions, not user page