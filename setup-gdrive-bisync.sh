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
#   5. Optionally sets a custom folder icon on each synced folder (GNOME only,
#      see GDRIVE_FOLDER_ICON in the private config — skipped if unset)
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
            log  "  1. See the error above for why the automatic install failed"
            log  "  2. Install manually: https://rclone.org/install/"
            log  "  3. Then re-run: bash $0"
            ;;
        2)
            warn "rclone remote 'gdrive' isn't configured yet."
            log  "Background: 'rclone config' below grants rclone access to your"
            log  "whole Google Drive account — it does NOT ask you to pick a specific"
            log  "folder (see the note after these steps for where 'work' is chosen)."
            log  "Full docs: https://rclone.org/drive/"
            log  ""
            log  "Run 'rclone config' yourself and answer exactly:"
            log  "  1.  n                    New remote"
            log  "  2.  name: gdrive         must match exactly"
            log  "  3.  Storage: enter the number next to \"Google Drive\", or type drive"
            log  "  4.  client_id: <Enter>   leave blank"
            log  "  5.  client_secret: <Enter>   leave blank"
            log  "      (blank uses rclone's own shared app — fine for personal use;"
            log  "      for your own dedicated OAuth client instead, see"
            log  "      https://rclone.org/drive/#making-your-own-client-id)"
            log  "  6.  scope: choose drive — \"Full access all files, excluding"
            log  "      Application Data Folder.\" Do NOT choose drive.appfolder —"
            log  "      that restricts rclone to a hidden area and won't see real"
            log  "      folders like work."
            log  "  7.  root_folder_id / service_account_file: <Enter>   leave blank"
            log  "  8.  Edit advanced config?: n"
            log  "      (if you're ever asked for root_folder_id anyway, leave it"
            log  "      BLANK — never enter appDataFolder or anything else there)"
            log  "  9.  Use auto config?: y if this machine has a browser you're using"
            log  "      right now (opens Google's login page automatically at"
            log  "      http://127.0.0.1:53682/); n only if this is a headless/remote"
            log  "      machine with no browser — it prints a URL to open elsewhere,"
            log  "      then asks you to paste back a verification code"
            log  "  10. Log in with the Google account that owns the Drive folder,"
            log  "      and grant access"
            log  "  11. Back in the terminal: confirm the remote's settings look"
            log  "      right, y to keep it, q to quit the config menu"
            log  ""
            log  "Where the folder to sync actually comes from: NOT from 'rclone"
            log  "config' above. It's the third field of the GDRIVE_PAIRS entry in"
            log  "$GDRIVE_BISYNC_PRIVATE_CONFIG"
            log  "(already set to 'work' for this setup — edit that file, not"
            log  "'rclone config', to change which folder syncs)."
            log  ""
            log  "Verify before assuming this worked: run 'rclone lsd gdrive:'"
            log  "yourself and confirm it lists your real Drive folders. If it"
            log  "errors (e.g. insufficientScopes), redo 'rclone config' rather"
            log  "than assuming it's fine."
            warn "Then re-run: bash $0"
            ;;
        3) warn "config invalid/missing at $GDRIVE_BISYNC_PRIVATE_CONFIG" ;;
        *) warn "install.sh exited $gdrive_exit — unexpected, check output above" ;;
    esac
fi
echo ""

# ── 5. optional: custom folder icon (GNOME/Nautilus only) ────────────────
echo "[ folder icon ]"
if [[ -f "$GDRIVE_BISYNC_PRIVATE_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$GDRIVE_BISYNC_PRIVATE_CONFIG"
fi
if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] would set folder icon (if configured) for: ${GDRIVE_PAIRS[*]:-<none>}"
elif [[ -z "${GDRIVE_FOLDER_ICON:-}" ]]; then
    log "GDRIVE_FOLDER_ICON not set in config — skipping (cosmetic, optional)"
elif ! command -v gio &>/dev/null; then
    log "gio not found (not a GNOME/Nautilus desktop?) — skipping folder icon"
elif [[ ! -f "$GDRIVE_FOLDER_ICON" ]]; then
    log "icon file not found at $GDRIVE_FOLDER_ICON — skipping"
else
    for pair in "${GDRIVE_PAIRS[@]}"; do
        IFS=':' read -r name local_path remote_path <<< "$pair"
        if [[ ! -d "$local_path" ]]; then
            log "$name: local folder $local_path doesn't exist yet — skipping icon"
        elif gio set "$local_path" metadata::custom-icon "file://$GDRIVE_FOLDER_ICON"; then
            ok "icon set on $local_path"
        else
            warn "failed to set icon on $local_path — non-fatal, continuing"
        fi
    done
fi

echo ""
echo "=== gdrive-bisync setup done ==="
echo ""
echo "Verify: bash $GDRIVE_BISYNC_DIR/status.sh"
echo ""
echo "Safety note: rclone bisync already refuses to sync (rather than wiping"
echo "everything) if either side is completely empty, and aborts if more than"
echo "half the files would be deleted in one run. Google Drive also trashes"
echo "deletions instead of purging them immediately. Still: don't delete a"
echo "synced local folder while its cron entry is still active — remove the"
echo "cron entry first. See gdrive-bisync's README for details."
echo ""
