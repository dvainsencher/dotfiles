#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

LINKED=()
SKIPPED=()
DONE=()

link() {
    local src="$1" dst="$2"
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [dry-run] symlink $src -> $dst"
        return
    fi
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        SKIPPED+=("$dst (already linked)")
        return
    fi
    if [[ -e "$dst" ]]; then
        mv "$dst" "${dst}.bak"
        echo "  backed up: $dst -> ${dst}.bak"
    fi
    ln -sf "$src" "$dst"
    LINKED+=("$dst -> $src")
}

maybe_run() {
    local desc="$1"; shift
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [dry-run] $desc"
        return
    fi
    "$@"
    DONE+=("$desc")
}

echo "==> Linking dotfiles..."
link "$DOTFILES_DIR/gitconfig"     "$HOME/.gitconfig"
link "$DOTFILES_DIR/bashrc"        "$HOME/.bashrc"
link "$DOTFILES_DIR/vimrc"         "$HOME/.vimrc"
link "$DOTFILES_DIR/inputrc"       "$HOME/.inputrc"
link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"

echo "==> Linking Claude config..."
mkdir -p "$HOME/.claude"
link "$DOTFILES_DIR/.claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"
link "$DOTFILES_DIR/.claude/settings.json"         "$HOME/.claude/settings.json"
link "$DOTFILES_DIR/.claude/settings.local.json"   "$HOME/.claude/settings.local.json"
link "$DOTFILES_DIR/.claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link "$DOTFILES_DIR/.claude/commands"              "$HOME/.claude/commands"
link "$DOTFILES_DIR/.claude/hooks"                 "$HOME/.claude/hooks"
link "$DOTFILES_DIR/.claude/agents"                "$HOME/.claude/agents"
link "$DOTFILES_DIR/.claude/RTK.md"               "$HOME/.claude/RTK.md"

echo "==> Registering GitHub MCP..."
[ -f "$HOME/.env.local" ] && source "$HOME/.env.local"
if [[ -n "${GITHUB_PAT:-}" ]]; then
    if claude mcp list 2>/dev/null | grep -q '^github\b'; then
        SKIPPED+=("GitHub MCP (already registered)")
    else
        maybe_run "register GitHub MCP (github -> api.githubcopilot.com)" \
            claude mcp add --transport http --scope user github \
            "https://api.githubcopilot.com/mcp/" \
            --header "Authorization: Bearer ${GITHUB_PAT}"
    fi
else
    SKIPPED+=("GitHub MCP (GITHUB_PAT not set — add it to ~/.env.local and re-run)")
fi

echo "==> Setting up claude-coworker-model..."
COWORKER_DIR="$HOME/.local/share/claude-coworker-model"
if [[ -f "$HOME/.local/bin/ask-kimi" ]]; then
    SKIPPED+=("claude-coworker-model (ask-kimi already installed)")
else
    if [[ ! -d "$COWORKER_DIR" ]]; then
        maybe_run "clone claude-coworker-model -> $COWORKER_DIR" \
            git clone https://github.com/imkunal007219/claude-coworker-model.git "$COWORKER_DIR"
        maybe_run "pin claude-coworker-model to 364df1f" \
            git -C "$COWORKER_DIR" checkout 364df1f28d4f455a588c35158f85d50f18f2d4af
    fi
    maybe_run "install claude-coworker-model tools" \
        bash "$COWORKER_DIR/setup.sh"
fi

echo "==> Setting up cclsp (LSP-over-MCP semantic code navigation)..."
if [[ -f "$HOME/.config/claude/cclsp.json" ]] && claude mcp list 2>/dev/null | grep -q '^cclsp\b'; then
    SKIPPED+=("cclsp (already installed and registered)")
else
    maybe_run "install cclsp LSP servers and register MCP" \
        bash "$DOTFILES_DIR/.claude/cclsp/setup-cclsp.sh"
fi

echo "==> Setting up git-hooks..."
if [[ ! -d "$HOME/.config/git-hooks" ]]; then
    maybe_run "clone dvainsencher/git-hooks -> ~/.config/git-hooks" \
        git clone https://github.com/dvainsencher/git-hooks "$HOME/.config/git-hooks"
else
    SKIPPED+=("~/.config/git-hooks (already exists)")
fi

echo "==> Setting up gitconfig.local..."
if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    maybe_run "copy gitconfig.local.example -> ~/.gitconfig.local" \
        cp "$DOTFILES_DIR/gitconfig.local.example" "$HOME/.gitconfig.local"
else
    SKIPPED+=("~/.gitconfig.local (already exists)")
fi

echo "==> Setting up gdrive-bisync..."
maybe_run "set up gdrive-bisync (see output above for details)" \
    bash "$DOTFILES_DIR/setup-gdrive-bisync.sh"

echo "==> Installing/updating rtk (token-saving CLI proxy)..."
maybe_run "install/update rtk (see output above for details)" \
    bash "$DOTFILES_DIR/setup-rtk.sh"

echo ""
echo "==> Summary"
if [[ ${#LINKED[@]} -gt 0 ]];  then printf '  linked:   %s\n'  "${LINKED[@]}";  fi
if [[ ${#DONE[@]} -gt 0 ]];    then printf '  done:     %s\n'  "${DONE[@]}";    fi
if [[ ${#SKIPPED[@]} -gt 0 ]]; then printf '  skipped:  %s\n'  "${SKIPPED[@]}"; fi
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "  (dry-run — no changes made)"
fi
