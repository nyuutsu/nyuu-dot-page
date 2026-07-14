# nyuu.page build system
.PHONY: all build watch watch-smooth clean prebuild rusty-site precompress deploy

RUSTY_LIB := $(CURDIR)/rusty-site/target/release
RUSTY_A   := $(RUSTY_LIB)/librusty_site.a

RUSTFLAGS += -C target-cpu=native
export RUSTFLAGS

all: build

# Rust static library
rusty-site:
	cargo build --release --manifest-path rusty-site/Cargo.toml

# Pre-Hakyll steps: Rust library, font subsetting, SCSS
# (Emoji SVGs are copied by Hakyll's preprocess step in site.hs)
prebuild: rusty-site
	@if [ $(RUSTY_A) -nt .rusty-stamp ] 2>/dev/null; then \
		echo "Rust library changed, cleaning cabal cache..."; \
		cabal clean; \
		touch .rusty-stamp; \
	fi
	uv run --project config config/font-subset.py
	sass scss/main.scss css/main.css --style compressed
	sass scss/smooth.scss css/smooth.css --style compressed
	sass scss/files.scss css/files.css --style compressed
	sass scss/files-smooth.scss css/files-smooth.css --style compressed

# Both flavor trees: _site (textured) and _site-smooth (smooth)
build: prebuild
	cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- build
	FLAVOR=smooth cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- build

# Precompress both trees for Caddy's precompressed file_server.
# Brotli q11 (max), zstd q19 (max), gzip q9 (max).
# Only compresses text-like files; images are already compressed.
COMPRESS_EXTS := -name '*.html' -o -name '*.css' -o -name '*.js' \
                 -o -name '*.svg' -o -name '*.xml' -o -name '*.json' \
                 -o -name '*.txt' -o -name '*.map' -o -name '*.pattern'

precompress: build
	@echo "Precompressing _site/ and _site-smooth/ ..."
	@find _site/ _site-smooth/ -type f \( $(COMPRESS_EXTS) \) | while read f; do \
		brotli -q 11 -f -o "$$f.br" "$$f"; \
		zstd -q -19 -f -o "$$f.zst" "$$f"; \
		gzip -9 -k -f -n "$$f"; \
	done
	@echo "Done."

deploy: precompress
	rsync -a --delete _site/ droplet:/var/dist/
	rsync -a --delete _site-smooth/ droplet:/var/dist-smooth/

# watch only needs prebuild, not build — Hakyll's watch builds on startup
watch: prebuild
	sass --watch scss/main.scss:css/main.css --style compressed & sass --watch scss/smooth.scss:css/smooth.css --style compressed & sass --watch scss/files.scss:css/files.css --style compressed & sass --watch scss/files-smooth.scss:css/files-smooth.css --style compressed & cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- watch

# Preview the smooth flavor at localhost:8001 (own port + _cache-smooth, so it can run alongside `make watch`)
watch-smooth: prebuild
	sass --watch scss/smooth.scss:css/smooth.css --style compressed & FLAVOR=smooth cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- watch -p 8001

clean:
	cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- clean
	FLAVOR=smooth cabal run site --extra-lib-dirs=$(RUSTY_LIB) -- clean
	rm -f css/main.css css/main.css.map css/smooth.css css/smooth.css.map css/files.css css/files.css.map css/files-smooth.css css/files-smooth.css.map
	cd rusty-site && cargo clean
	rm -f .rusty-stamp
