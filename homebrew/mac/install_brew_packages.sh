#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Get all installed packages once at the beginning
echo "Checking installed packages..."
declare -A INSTALLED_FORMULAE
declare -A INSTALLED_CASKS

# Populate hash with installed formulae
while IFS= read -r formula; do
    INSTALLED_FORMULAE["$formula"]=1
done < <(brew list --formula 2>/dev/null)

# Populate hash with installed casks
while IFS= read -r cask; do
    INSTALLED_CASKS["$cask"]=1
done < <(brew list --cask 2>/dev/null)

# Define Lists
# Leaves: Top-level command line tools (dependencies will be installed automatically)
FORMULAE=(
    "antoniorodr/memo/memo"
    "aria2"
    "bat"
    "binutils"
    "blueutil"
    "cmake"
    "container"
    "coreutils"
    "create-dmg"
    "daipeihust/tap/im-select"
    "etcd"
    "fastfetch"
    "fd"
    "fzf"
    "gcc"
    "gemini-cli"
    "geoip"
    "gh"
    "git"
    "git-filter-repo"
    "gnuplot"
    "go"
    "graphviz"
    "helix"
    "http-server-rs"
    "httpie"
    "hugo"
    "jansson"
    "jbang"
    "lazygit"
    "libgccjit"
    "luarocks"
    "macvim"
    "maven"
    "mkcert"
    "ncdu"
    "neovim-qt"
    "node@22"
    "nvm"
    "opencode"
    "openresty/brew/geoip2-nginx-module"
    "openresty/brew/openresty-openssl3"
    "pandoc"
    "pipx"
    "pngpaste"
    "poetry"
    "ranger"
    "redis"
    "rsync"
    "shellcheck"
    "steipete/tap/remindctl"
    "swiftformat"
    "swiftlint"
    "texinfo"
    "thefuck"
    "thrift"
    "trojan-go"
    "tw93/tap/mole"
    "vapor"
    "volta"
    "wget"
    "woff2"
    "xcbeautify"
    "xcode-build-server"
    "yakitrak/yakitrak/obsidian-cli"
)

# Casks: GUI/Desktop Applications
CASKS=(
    "alacritty"
    "anaconda"
    "anytype"
    "apifox"
    "applite"
    "claude-code"
    "codex"
    "container"
    "copilot-cli"
    "dash"
    "dbeaver-community"
    "double-commander"
    "drawio"
    "emacs"
    "emacs-app"
    "excalidrawz"
    "finalshell"
    "firefox@developer-edition"
    "font-blex-mono-nerd-font"
    "font-fira-mono-nerd-font"
    "font-hack-nerd-font"
    "font-jetbrains-mono"
    "font-jetbrains-mono-nerd-font"
    "font-sarasa-gothic"
    "foobar2000"
    "gimp"
    "github"
    "github-copilot-for-xcode"
    "google-drive"
    "graalvm-jdk@21"
    "hammerspoon"
    "hiddenbar"
    "httpie-desktop"
    "intellij-idea-ce"
    "iterm2"
    "itsycal"
    "jd-gui"
    "karabiner-elements"
    "kitty"
    "lepton"
    "localsend"
    "logitech-g-hub"
    "logseq"
    "macvim"
    "macvim-app"
    "masscode"
    "miaoyan"
    "mysqlworkbench"
    "neovide"
    "neovide-app"
    "netnewswire"
    "obsidian"
    "ollama-app"
    "omnidisksweeper"
    "opencode-desktop"
    "openemu"
    "picgo"
    "qq"
    "raven-reader"
    "raycast"
    "redis-insight"
    "sourcetree"
    "squirrel"
    "squirrel-app"
    "stats"
    "steam"
    "swiftbar"
    "tabby"
    "tmpdisk"
    "typora"
    "v2rayx"
    "visual-studio-code"
    "vlc"
    "warp"
    "wireshark"
    "zed"
)

echo "--- Installing Formulae (CLI Tools) ---"
for formula in "${FORMULAE[@]}"; do
    # Extract the package name (handle tap prefixes)
    package_name="${formula##*/}"
    
    if [[ -n "${INSTALLED_FORMULAE[$package_name]}" ]]; then
        echo "Formula '$formula' is already installed."
    else
        echo "Installing formula '$formula'..."
        brew install "$formula"
    fi
done

echo "--- Installing Casks (GUI Apps) ---"
for cask in "${CASKS[@]}"; do
    if [[ -n "${INSTALLED_CASKS[$cask]}" ]]; then
        echo "Cask '$cask' is already installed."
    else
        echo "Installing cask '$cask'..."
        brew install --cask "$cask"
    fi
done

echo "Done!"
