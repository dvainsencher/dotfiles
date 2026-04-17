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
