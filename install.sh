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

echo "==> Generating RTK.md..."
RTK_MD="$HOME/.claude/RTK.md"
if command -v rtk &>/dev/null; then
    if [[ ! -f "$RTK_MD" ]]; then
        cat > "$RTK_MD" << 'EOF'
# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

Refer to CLAUDE.md for full command reference.
EOF
        DONE+=("generated ~/.claude/RTK.md")
    else
        SKIPPED+=("~/.claude/RTK.md (already exists)")
    fi
else
    SKIPPED+=("~/.claude/RTK.md (rtk not installed)")
fi

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

echo ""
echo "==> Summary"
if [[ ${#LINKED[@]} -gt 0 ]];  then printf '  linked:   %s\n'  "${LINKED[@]}";  fi
if [[ ${#DONE[@]} -gt 0 ]];    then printf '  done:     %s\n'  "${DONE[@]}";    fi
if [[ ${#SKIPPED[@]} -gt 0 ]]; then printf '  skipped:  %s\n'  "${SKIPPED[@]}"; fi
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "  (dry-run — no changes made)"
fi
