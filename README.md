# [nyuu.page](https://nyuu.page)

Source for nyuu.page. See the [project page](https://nyuu.page/projects/nyuu-page/) for a walkthrough.

A personal website and blog built with Hakyll. Posts are markdown; nine Pandoc AST transforms turn terse shorthand (::: chat, [Charizard]{.card}, {漢|かん}) into semantic HTML with full accessibility markup. Fonts are self-hosted and subsetted at build time. No JavaScript.

## Building

### Prerequisites

- GHC and Cabal (via [ghcup](https://www.haskell.org/ghcup/))
- [Sass](https://sass-lang.com/install/) (`sass` CLI)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- Make

### Setup

```bash
cabal build
cd config && uv sync && cd ..
cd config/blobmoji && uv sync && cd ../..
```

### Build

```bash
make build
```

### Dev server

```bash
make watch
# -> http://127.0.0.1:8000
```

## Pandoc transforms

Each transform is a `Pandoc -> Pandoc` function in its own module under `src/Transforms/`.

| Transform | Markdown syntax | Output |
|-----------|----------------|--------|
| Admonitions | `::: warning` | Callout box with icon, colors from TOML config |
| Anchors | `## Heading` | Clickable heading anchors |
| Cards | `[Charizard]{.card}` | Hoverable card preview (Pokemon/Yu-Gi-Oh/MTG) |
| Chat | `@Alice[alice]: hi` inside `::: chat` | Chat bubbles |
| Forum | `::: {.forum-post name="..." avatar="..."}` | Forum post layout |
| Japanese | `{漢\|かん}{字\|じ}` | Ruby annotations, `lang="ja"` grouping |
| ImageDimensions | (automatic) | `width`/`height` on images |
| FigureLink | `![alt](img){.clickable}` | Image linked to full size |

## Directory structure

```
nyuu-dot-page/
├── site.hs                  # Hakyll generator
├── src/
│   ├── Transforms.hs        # Composes all transforms
│   ├── Transforms/           # One module per transform
│   ├── Config.hs             # TOML config loading
│   ├── CardCache.hs          # Card data + image pipeline
│   └── ImageDimensions.hs    # Image dimension scanning
│
├── config/
│   ├── admonitions.toml      # Admonition types: icon, colors
│   ├── avatars.toml          # Avatar key -> filename
│   ├── font-subset.py        # Subsets fonts to used characters
│   ├── fonts-src/            # Full font files (input to subsetter)
│   ├── blobmoji/             # Emoji font builder
│   └── {pokemon,yugioh,mtg}/ # Card data + images
│
├── content/                  # Markdown source
├── scss/                     # Modular SCSS
├── templates/                # Hakyll templates
└── static/                   # Fonts (subsetted), images, icons
```

## License

Code (Haskell, SCSS, Python, templates): MIT

Content (posts, writing): CC BY-NC-SA 4.0

Fonts and card data have their own licenses; see [CREDITS.md](CREDITS.md).
