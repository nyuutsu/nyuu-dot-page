# nyuu.page build system
.PHONY: all build watch clean prebuild

all: build

# Pre-Hakyll steps: emoji font, font subsetting, SCSS
prebuild:
	uv run --project config/blobmoji config/blobmoji/build-subset.py
	uv run --project config config/font-subset.py
	sass scss/main.scss css/main.css --style compressed

build: prebuild
	cabal run site -- build

# watch only needs prebuild, not build — Hakyll's watch builds on startup
watch: prebuild
	sass --poll --watch scss/main.scss:css/main.css --style compressed & cabal run site -- watch

clean:
	cabal run site -- clean
	rm -f css/main.css
