# Brewfile for claude-code-starter
#
# Run: brew bundle
#
# This installs the toolchain assumed by the rules and skills in this starter:
# GitHub CLI, Node, Cloud SQL Proxy, Firebase CLI, gcloud, plus the WeasyPrint
# system deps needed if you generate PDFs in your backend.
#
# Also includes GUI app casks for a new-machine setup (VS Code, Chrome). If
# you only want the CLI toolchain, comment out the "GUI apps" section below
# before running `brew bundle`.

# Core dev tools
brew "git"
brew "gh"
brew "node"
brew "node@20"
brew "openssl@3"
brew "ca-certificates"
brew "jq"

# Cloud / infra (GCP-flavored — drop if you're on AWS/Azure)
brew "cloud-sql-proxy"
brew "firebase-cli"
cask "gcloud-cli"

# GUI apps (case C — new computer setup). Comment out if you already have
# these installed or want to manage them outside Homebrew.
cask "visual-studio-code"
cask "google-chrome"

# Docs / reporting
brew "pandoc"
brew "cloc"

# WeasyPrint system deps (only if your backend renders PDFs with WeasyPrint).
# Safe to install regardless — they're small and don't conflict with anything.
brew "cairo"
brew "pango"
brew "gdk-pixbuf"
brew "librsvg"
brew "harfbuzz"
brew "fontconfig"
brew "freetype"
brew "fribidi"
brew "glib"
brew "graphite2"
brew "jpeg-turbo"
brew "libpng"
brew "libthai"
brew "libtiff"
