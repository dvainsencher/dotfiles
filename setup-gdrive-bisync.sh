#!/usr/bin/env bash
# =============================================================================
# setup-gdrive-bisync.sh — Set up periodic Google Drive sync via gdrive-bisync
#
# Called by install.sh, or run directly:
#   bash ~/dotfiles/setup-gdrive-bisync.sh [--dry-run]
#
# What this does:
#   1. Clones gdrive-bisync (public tool) to ~/prj/git/gdrive-bisync
#   2. Clones dotfiles-private (private config) to ~/prj/git/dotfiles-private
#   3. Installs rclone via its official install script, if not already present
#   4. Runs gdrive-bisync's own install.sh against the private config
#
# Steps 2 and 4 depend on manual one-time setup (SSH key added to GitHub;
# `rclone config` run interactively) that a fresh machine won't have done
# yet — this script warns and exits 0 in those cases rather than failing,
# so it's always safe to re-run after clearing a blocker.
#
# rclone via the official installer, not apt: apt's rclone lags behind
# upstream (e.g. 1.60.1 on Ubuntu 24.04 vs current stable), and `bisync`
# reliability depends on running a recent release — same reasoning already
# applied to starship/uv/node in bootstrap.sh.
# =============================================================================

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

GDRIVE_BISYNC_DIR="$HOME/prj/git/gdrive-bisync"
DOTFILES_PRIVATE_DIR="$HOME/prj/git/dotfiles-private"
GDRIVE_BISYNC_PRIVATE_CONFIG="$DOTFILES_PRIVATE_DIR/config/gdrive-bisync.sh"

log()  { echo "  → $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }

echo ""
echo "=== gdrive-bisync setup ==="
echo ""

# ── 1. gdrive-bisync tool ────────────────────────────────────────────────
echo "[ gdrive-bisync clone ]"
if [[ -d "$GDRIVE_BISYNC_DIR/.git" ]]; then
    ok "already cloned: $GDRIVE_BISYNC_DIR"
elif [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would clone gdrive-bisync -> $GDRIVE_BISYNC_DIR"
else
    mkdir -p "$(dirname "$GDRIVE_BISYNC_DIR")"
    git clone https://github.com/dvainsencher/gdrive-bisync.git "$GDRIVE_BISYNC_DIR"
    ok "cloned -> $GDRIVE_BISYNC_DIR"
fi
echo ""

# ── 2. dotfiles-private (private config), non-fatal on failure ──────────
echo "[ dotfiles-private clone ]"
if [[ -d "$DOTFILES_PRIVATE_DIR/.git" ]]; then
    ok "already cloned: $DOTFILES_PRIVATE_DIR"
elif [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would clone dotfiles-private -> $DOTFILES_PRIVATE_DIR"
else
    mkdir -p "$(dirname "$DOTFILES_PRIVATE_DIR")"
    if git clone git@github.com:dvainsencher/dotfiles-private.git "$DOTFILES_PRIVATE_DIR" 2>/dev/null; then
        ok "cloned -> $DOTFILES_PRIVATE_DIR"
    else
        warn "clone failed — add your SSH pubkey at https://github.com/settings/keys"
        warn "then re-run: bash $0"
    fi
fi
echo ""

# ── 3. rclone itself, via the official installer ─────────────────────────
echo "[ rclone install ]"
if command -v rclone &>/dev/null; then
    ok "already installed: $(rclone version | head -1)"
elif [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would install rclone via https://rclone.org/install.sh"
else
    if curl -fsSL https://rclone.org/install.sh | sudo bash; then
        ok "installed: $(rclone version | head -1)"
    else
        warn "rclone install failed — install manually (https://rclone.org/install/), then re-run"
    fi
fi
echo ""

# ── 4. gdrive-bisync's own installer against the private config ─────────
echo "[ gdrive-bisync install ]"
if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would run: $GDRIVE_BISYNC_DIR/install.sh --config $GDRIVE_BISYNC_PRIVATE_CONFIG"
elif [[ ! -x "$GDRIVE_BISYNC_DIR/install.sh" || ! -f "$GDRIVE_BISYNC_PRIVATE_CONFIG" ]]; then
    warn "waiting on the clones above to complete — re-run once both succeed"
else
    set +e
    "$GDRIVE_BISYNC_DIR/install.sh" --config "$GDRIVE_BISYNC_PRIVATE_CONFIG"
    gdrive_exit=$?
    set -e
    case $gdrive_exit in
        0) ok "install complete (resync + cron entry)" ;;
        1)
            warn "rclone not installed — see [ rclone install ] output above, then re-run"
            log  "manual install: https://rclone.org/install/"
            ;;
        2)
            warn "rclone remote 'gdrive' isn't configured yet. Run 'rclone config' and:"
            log  "  1. Choose 'n' (New remote)"
            log  "  2. name: gdrive   (must match exactly)"
            log  "  3. Storage: Google Drive (enter its number, or type 'drive')"
            log  "  4. client_id / client_secret: leave blank (press Enter)"
            log  "  5. scope: 1 (full access), unless you want read-only"
            log  "  6. root_folder_id / service_account_file: leave blank"
            log  "  7. Edit advanced config?: n"
            log  "  8. Use auto config?: y if you have a browser on this machine"
            log  "     (opens Google login automatically); n if headless — it"
            log  "     prints a URL to open on any device, then paste back a code"
            log  "  9. Log in with the Google account that owns the Drive folder"
            log  "  10. Confirm the remote, y to keep it, q to quit the menu"
            warn "Then re-run: bash $0"
            ;;
        3) warn "config invalid/missing at $GDRIVE_BISYNC_PRIVATE_CONFIG" ;;
        *) warn "install.sh exited $gdrive_exit — unexpected, check output above" ;;
    esac
fi

echo ""
echo "=== gdrive-bisync setup done ==="
echo ""
echo "Verify: bash $GDRIVE_BISYNC_DIR/status.sh"
echo ""
