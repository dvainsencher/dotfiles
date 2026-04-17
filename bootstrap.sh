#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/dvainsencher/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

INSTALLED=()
SKIPPED=()

apt_install() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
        SKIPPED+=("$pkg (already installed)")
    else
        echo "  installing $pkg..."
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
apt_install wget
apt_install build-essential
apt_install ca-certificates
apt_install gnupg
apt_install lsb-release
apt_install tmux
apt_install jq
apt_install fzf
apt_install ripgrep
apt_install direnv
apt_install fontconfig

echo "==> Installing Python dev tools..."
apt_install python3
apt_install python3-pip
apt_install python3-venv
apt_install python3-dev

echo "==> Installing uv (Python package manager)..."
if command -v uv &>/dev/null; then
    SKIPPED+=("uv (already installed)")
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    INSTALLED+=("uv")
fi

echo "==> Installing Node.js (via NodeSource)..."
if command -v node &>/dev/null; then
    SKIPPED+=("node (already installed)")
else
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    INSTALLED+=("node $(node --version 2>/dev/null || true)")
fi

echo "==> Installing gh (GitHub CLI)..."
if command -v gh &>/dev/null; then
    SKIPPED+=("gh (already installed)")
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -q
    sudo apt-get install -y gh
    INSTALLED+=("gh")
fi

echo "==> Installing VS Code..."
if command -v code &>/dev/null; then
    SKIPPED+=("vscode (already installed)")
else
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -q
    sudo apt-get install -y code
    INSTALLED+=("vscode")
fi

echo "==> Installing Google Chrome..."
if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
    SKIPPED+=("google-chrome (already installed)")
else
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt-get install -y /tmp/google-chrome.deb
    rm /tmp/google-chrome.deb
    INSTALLED+=("google-chrome")
fi

echo "==> Installing Claude Code..."
if command -v claude &>/dev/null; then
    SKIPPED+=("claude-code (already installed)")
else
    npm install -g @anthropic-ai/claude-code
    INSTALLED+=("claude-code")
fi

echo "==> Installing Starship..."
if command -v starship &>/dev/null; then
    SKIPPED+=("starship (already installed)")
else
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir ~/.local/bin
    INSTALLED+=("starship")
fi

echo "==> Installing Claude Desktop..."
if command -v claude-desktop &>/dev/null; then
    SKIPPED+=("claude-desktop (already installed)")
else
    curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg
    echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] https://aaddrick.github.io/claude-desktop-debian stable main" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null
    sudo apt-get update -q
    sudo apt-get install -y claude-desktop
    INSTALLED+=("claude-desktop")
fi

echo "==> Installing JetBrainsMono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
FONT_FILE="$FONT_DIR/JetBrainsMonoNLNerdFont-Regular.ttf"
if [[ -f "$FONT_FILE" ]]; then
    SKIPPED+=("JetBrainsMono Nerd Font (already installed)")
else
    mkdir -p "$FONT_DIR"
    curl -fLo "$FONT_FILE" \
        https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/NoLigatures/Regular/JetBrainsMonoNLNerdFont-Regular.ttf
    fc-cache -f "$FONT_DIR"
    INSTALLED+=("JetBrainsMono Nerd Font")
fi

echo "==> Setting up SSH key..."
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    SKIPPED+=("ssh key (already exists)")
else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "dvainsencher@gmail.com" -f "$HOME/.ssh/id_ed25519" -N ""
    INSTALLED+=("ssh key (~/.ssh/id_ed25519)")
    echo ""
    echo "  Your public key (add to GitHub → https://github.com/settings/keys):"
    echo ""
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
fi

echo "==> Cloning dotfiles..."
if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    INSTALLED+=("dotfiles -> $DOTFILES_DIR")
else
    SKIPPED+=("$DOTFILES_DIR (already exists)")
fi

echo "==> Setting up claude-commands..."
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
if [[ -d "$CLAUDE_COMMANDS_DIR" && "$(git -C "$CLAUDE_COMMANDS_DIR" remote get-url origin 2>/dev/null)" == *"claude-commands"* ]]; then
    SKIPPED+=("claude-commands (already installed)")
else
    mkdir -p "$HOME/.claude"
    git clone https://github.com/dvainsencher/claude-commands "$CLAUDE_COMMANDS_DIR"
    INSTALLED+=("claude-commands -> $CLAUDE_COMMANDS_DIR")
fi

echo "==> Running install.sh..."
bash "$DOTFILES_DIR/install.sh"

echo ""
echo "==> Bootstrap summary"
if [[ ${#INSTALLED[@]} -gt 0 ]]; then printf '  installed: %s\n' "${INSTALLED[@]}"; fi
if [[ ${#SKIPPED[@]} -gt 0 ]];   then printf '  skipped:   %s\n' "${SKIPPED[@]}";   fi
echo ""
echo "Done. Open a new shell or run: source ~/.bashrc"
