#!/bin/zsh

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
typeset -A INSTALLED_FORMULAE
typeset -A INSTALLED_CASKS

# Populate hash with installed formulae
while IFS= read -r formula; do
    INSTALLED_FORMULAE[$formula]=1
done < <(brew list --formula 2>/dev/null)

# Populate hash with installed casks
while IFS= read -r cask; do
    INSTALLED_CASKS[$cask]=1
done < <(brew list --cask 2>/dev/null)

# Function to install packages
# Arguments:
#   $1: package type ("formula" or "cask")
#   $2: installed packages hash name (associative array name)
#   Rest: package list
install_packages() {
    local pkg_type="$1"
    local installed_hash_name="$2"
    shift 2
    local packages=("$@")
    local type_label=""
    
    # Set appropriate label based on package type
    if [[ "$pkg_type" == "cask" ]]; then
        type_label="Cask"
    else
        type_label="Formula"
    fi
    
    echo "--- Installing ${type_label}s ---"
    
    for package in "${packages[@]}"; do
        # Extract the package name (handle tap prefixes for formulae)
        local package_name="${package##*/}"
        
        # Check if package is installed using eval for indirect reference
        local is_installed=""
        eval "is_installed=\${${installed_hash_name}[$package_name]}"
        
        if [[ -n "$is_installed" ]]; then
            echo "$type_label '$package' is already installed."
        else
            echo "Installing $type_label '$package'..."
            if [[ "$pkg_type" == "cask" ]]; then
                brew install --cask "$package"
            else
                brew install "$package"
            fi
        fi
    done
}

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Read package lists from files
FORMULAE=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    FORMULAE+=("$line")
done < "$SCRIPT_DIR/formulae.txt"

CASKS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    CASKS+=("$line")
done < "$SCRIPT_DIR/casks.txt"

# Install formulae and casks
install_packages "formula" INSTALLED_FORMULAE "${FORMULAE[@]}"
install_packages "cask" INSTALLED_CASKS "${CASKS[@]}"

echo "Done!"
