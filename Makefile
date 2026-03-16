# nyuu.page build system
.PHONY: all build watch clean prebuild

all: build

# Pre-Hakyll steps: font subsetting, SCSS
# (Emoji SVGs are copied by Hakyll's preprocess step in site.hs)
prebuild:
	uv run --project config config/font-subset.py
	sass scss/main.scss css/main.css --style compressed
	sass scss/smooth.scss css/smooth.css --style compressed

build: prebuild
	cabal run site -- build

# watch only needs prebuild, not build — Hakyll's watch builds on startup
watch: prebuild
	sass --watch scss/main.scss:css/main.css --style compressed & sass --watch scss/smooth.scss:css/smooth.css --style compressed & cabal run site -- watch

clean:
	cabal run site -- clean
	rm -f css/main.css css/main.css.map css/smooth.css css/smooth.css.map
