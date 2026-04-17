#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/dvainsencher/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

INSTALLED=()
SKIPPED=()

apt_install() {
    local pkg="$1"
    if command -v "$pkg" &>/dev/null; then
        SKIPPED+=("$pkg (already installed)")
    else
        echo "==> Installing $pkg..."
        sudo apt-get install -y "$pkg"
        INSTALLED+=("$pkg")
    fi
}

echo "==> Updating apt..."
sudo apt-get update -q

echo "==> Installing system packages..."
apt_install git
apt_install vim
apt_install curl

echo "==> Installing Starship..."
if command -v starship &>/dev/null; then
    SKIPPED+=("starship (already installed)")
else
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    INSTALLED+=("starship")
fi

echo "==> Cloning dotfiles..."
if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    INSTALLED+=("dotfiles -> $DOTFILES_DIR")
else
    SKIPPED+=("$DOTFILES_DIR (already exists)")
fi

echo "==> Running install.sh..."
bash "$DOTFILES_DIR/install.sh"

echo ""
echo "==> Bootstrap summary"
if [[ ${#INSTALLED[@]} -gt 0 ]]; then printf '  installed: %s\n' "${INSTALLED[@]}"; fi
if [[ ${#SKIPPED[@]} -gt 0 ]];   then printf '  skipped:   %s\n' "${SKIPPED[@]}";   fi
echo ""
echo "Done. Open a new shell or run: source ~/.bashrc"
