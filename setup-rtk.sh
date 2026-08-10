#!/usr/bin/env bash
# =============================================================================
# setup-rtk.sh — Install/update rtk (Rust Token Killer, token-saving CLI proxy)
#
# Called by install.sh, or run directly:
#   bash ~/dotfiles/setup-rtk.sh [--dry-run]
#
# What this does:
#   1. Runs rtk's official installer — idempotent and safe to re-run any
#      time; it always fetches and installs the latest release to
#      ~/.local/bin/rtk. Re-running this script IS how you update rtk.
#   2. Removes any stray `cargo install`-built copy from ~/.cargo/bin/rtk.
#      ~/.local/bin comes first on PATH, so a cargo-built copy is silently
#      shadowed rather than actually used — it just causes confusion about
#      which binary is running and which one `--version` is reporting.
#
# Both steps are non-fatal: a network hiccup or a failed `cargo uninstall`
# warns and moves on rather than aborting, so this script always exits 0 —
# same contract as setup-gdrive-bisync.sh. `install.sh` runs under `set -e`,
# so a hard failure here would otherwise kill every step after it.
#
# rtk itself is not vendored into this repo (upstream: github.com/rtk-ai/rtk).
# =============================================================================

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

log()  { echo "  → $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }

echo ""
echo "=== rtk setup ==="
echo ""

# ── 1. Install/update the active binary (~/.local/bin/rtk) ─────────────────

echo "[ rtk binary ]"

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
else
    BEFORE="$(rtk --version 2>/dev/null || echo 'not installed')"
    if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh; then
        hash -r
        AFTER="$(rtk --version 2>/dev/null || echo 'unknown')"
        ok "rtk: $AFTER (was: $BEFORE)"
    else
        warn "rtk installer failed (network issue?) — leaving rtk as-is: $BEFORE"
    fi
fi

echo ""

# ── 2. Clean up the shadowed `cargo install` copy, if present ──────────────

echo "[ stray cargo install copy ]"

if command -v cargo &>/dev/null && cargo install --list 2>/dev/null | grep -q '^rtk '; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] cargo uninstall rtk"
    else
        if cargo uninstall rtk; then
            ok "removed duplicate ~/.cargo/bin/rtk (was shadowed by ~/.local/bin anyway)"
        else
            warn "cargo uninstall rtk failed — leaving the duplicate in place (harmless, shadowed by PATH)"
        fi
    fi
else
    ok "no stray cargo install copy found"
fi

echo ""
echo "=== rtk setup done ==="
echo ""
echo "Verify: rtk --version"
echo ""
