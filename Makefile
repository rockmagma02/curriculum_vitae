print-%: ; @echo $* = $($*)
PROJECT_NAME   = "Curriculum Vitae"
COPYRIGHT      = "Ruiyang Sun. All Rights Reserved."
SHELL          = /bin/bash

HOME		   = $(shell echo $$HOME)
OUTPUT_PATH    = out

ALL_ROOT_TEX_FILES = cv.tex

export TEXINPUTS = .:$(shell pwd)/style:$(shell pwd)/assets:

# Check MacOS
check-mac-os:
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "This script is intended to run on macOS"; \
		exit 1; \
	fi

# Brew Installation
install-brew:
	$(SHELL) -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Check if Homebrew is installed
check-brew:
	@if ! command -v brew >/dev/null; then \
		echo "Homebrew not found"; \
		echo "Installing Homebrew..."; \
		make install-brew; \
	fi

# Rust Installation
install-rust: check-brew
	brew install rust

# Check if Rust is installed
check-rust:
	@if ! command -v rustc >/dev/null; then \
		echo "Rust not found"; \
		echo "Installing Rust..."; \
		make install-rust; \
	fi

# MacTex Installation
install-mactex: check-mac-os check-brew
	brew install --cask mactex

# Reinstall MacTex
reinstall-mactex: check-mac-os check-brew
	brew uninstall --cask mactex
	make install-mactex

# Check if Tex is installed
check-tex:
	@if ! command -v tlmgr >/dev/null; then \
		echo "Tex not found"; \
		if [ "$$(uname)" = "Darwin" ]; then \
			echo "Installing MacTex in MacOS..."; \
			echo "Try install MacTex by Homebrew..."; \
			make reinstall-mactex; \
		else \
			echo "Please install Tex manually."; \
			exit 1; \
		fi \
	fi

install-tex-package: check-tex
	tlmgr update --self
	while read -r package; do \
		tlmgr install "$$package"; \
	done < requirements.txt
	tlmgr repository list
	tlmgr update --reinstall-forcibly-removed --all --self

# Install Font

install-font: check-mac-os check-brew
	brew install --cask font-times-newer-roman
	brew install --cask font-inconsolata
	brew install --cask font-arial

install-font-linux: check-brew
	brew install cabextract
	mkdir -p font
	wget -O font/TimesNewerRoman.zip https://timesnewerroman.com/assets/TimesNewerRoman.zip
	unzip -d font/TimesNewerRoman/ font/TimesNewerRoman.zip
	mv font/TimesNewerRoman/ /usr/share/fonts/
	wget -O "font/Inconsolata[wdth,wght].ttf" https://github.com/google/fonts/raw/main/ofl/inconsolata/Inconsolata%5Bwdth%2Cwght%5D.ttf
	mv "font/Inconsolata[wdth,wght].ttf" /usr/share/fonts/
	wget -O font/arial32.exe https://downloads.sourceforge.net/corefonts/arial32.exe
	cabextract -L -F '*.TTF' font/arial32.exe
	mkdir -p font/arial
	mv *.ttf font/arial/
	mv font/arial /usr/share/fonts/
	fc-cache -fv

## Begin of LaTeX Compilation
compile-lualatex: check-tex
	mkdir -p $(OUTPUT_PATH)
	lualatex --recorder --synctex=1 -halt-on-error --output-directory=$(OUTPUT_PATH) $(FILE_PATH)

compile-biber: check-tex
	mkdir -p $(OUTPUT_PATH)
	biber $(OUTPUT_PATH)/$$(basename $(FILE_PATH:.tex=.bcf))

compile: check-tex
	mkdir -p $(OUTPUT_PATH)
	make compile-lualatex FILE_PATH=$(FILE_PATH)
	@if [ -f $(OUTPUT_PATH)/$$(basename $(FILE_PATH:.tex=.bcf)) ]; then \
		make compile-biber FILE_PATH=$(FILE_PATH); \
	fi
	make compile-lualatex FILE_PATH=$(FILE_PATH)
	make compile-lualatex FILE_PATH=$(FILE_PATH)
	make clean-without-pdf

clean:
	rm -rf $(OUTPUT_PATH)

clean-without-pdf:
	find $(OUTPUT_PATH) -type f ! -name "*.pdf" -delete

compile-all:
	@for file in $(ALL_ROOT_TEX_FILES); do \
		make compile FILE_PATH=$$file; \
	done

## End of LaTeX Compilation

# Linting Tool ChkTeX

check-chktex:
	@if ! command -v chktex >/dev/null; then \
		echo "ChkTeX not found"; \
		echo "Installing ChkTeX..."; \
		make reinstall-mactex; \
	fi

lint-chktex: check-chktex
	chktex -l .chktexrc $$(find . -name "*.tex") $$(find . -name "*.sty")

# Linting Tool Lacheck

check-lacheck:
	@if ! command -v lacheck >/dev/null; then \
		echo "Lacheck not found"; \
		echo "Installing Lacheck..."; \
		make reinstall-mactex; \
	fi

lint-lacheck: check-lacheck
	@for file in $$(find . -name "*.tex"); do \
		lacheck $$file; \
	done
	@for file in $$(find . -name "*.sty"); do \
		lacheck $$file; \
	done

# Formatting Tool latexindent

install-latexindent: check-brew
	brew install latexindent

check-latexindent:
	@if ! command -v latexindent >/dev/null; then \
		echo "Latexindent not found"; \
		echo "Installing Latexindent..."; \
		make install-latexindent; \
	fi

format-latexindent: check-latexindent
	@for file in $$(find . -name "*.tex"); do \
		latexindent -m -l ./latexindent.yaml -wd $$file > /dev/null 2>&1; \
	done
	@for file in $$(find . -name "*.sty"); do \
		latexindent -m -l ./latexindent.yaml -wd $$file > /dev/null 2>&1; \
	done
	@for file in $$(find . -name "*.bak*"); do \
		rm -f $$file; \
	done
	@find . -name "indent.log" -exec rm -f {} +

# Formatting Tool texfmt

install-texfmt: check-rust
	cargo install tex-fmt

check-texfmt:
	@if ! command -v tex-fmt >/dev/null; then \
		echo "Texfmt not found"; \
		echo "Installing Texfmt..."; \
		make install-texfmt; \
	fi

format-texfmt: check-texfmt
	@for file in $$(find . -name "*.tex"); do \
		tex-fmt $$file; \
	done

# Lint and Format

lint: lint-chktex lint-lacheck
	@echo "Linting completed"

# format: format-latexindent format-texfmt
format: format-latexindent
	@echo "Formatting completed"

format-and-lint: format lint
	@echo "Formatting and linting completed"
