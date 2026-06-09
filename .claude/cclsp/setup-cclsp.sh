#!/usr/bin/env bash
# =============================================================================
# setup-cclsp.sh — Install cclsp MCP server and required LSP servers
#
# Called by install.sh, or run directly:
#   bash ~/dotfiles/.claude/cclsp/setup-cclsp.sh
#
# What this does:
#   1. Installs LSP servers (pylsp, typescript-language-server, bash-language-server)
#   2. Copies cclsp.json to ~/.config/claude/cclsp.json  (global fallback config)
#   3. Registers cclsp as a user-scoped Claude Code MCP server
#
# Per-project use: add a .claude/.mcp.json that sets CCLSP_CONFIG_PATH to the
# project-local cclsp.json (relative to project root).  The user-scoped MCP
# registration done here serves as the fallback for repos without a project config.
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CCLSP_CONFIG_SRC="$DOTFILES_DIR/.claude/cclsp/cclsp.json"
CCLSP_CONFIG_DEST="$HOME/.config/claude/cclsp.json"

log()  { echo "  → $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }

echo ""
echo "=== cclsp setup ==="
echo ""

# ── 1. LSP servers ──────────────────────────────────────────────────────────

echo "[ LSP servers ]"

# Python
if command -v pylsp &>/dev/null; then
  ok "pylsp already installed ($(pylsp --version 2>&1 | head -1))"
else
  log "Installing python-lsp-server..."
  pip install "python-lsp-server[all]" --break-system-packages --quiet
  ok "pylsp installed"
fi

# TypeScript / JavaScript
if command -v typescript-language-server &>/dev/null; then
  ok "typescript-language-server already installed"
else
  log "Installing typescript-language-server..."
  npm install -g typescript-language-server typescript --silent
  ok "typescript-language-server installed"
fi

# Bash
if command -v bash-language-server &>/dev/null; then
  ok "bash-language-server already installed"
else
  log "Installing bash-language-server..."
  npm install -g bash-language-server --silent
  ok "bash-language-server installed"
fi

echo ""

# ── 2. cclsp global config ─────────────────────────────────────────────────

echo "[ cclsp global config ]"

mkdir -p "$(dirname "$CCLSP_CONFIG_DEST")"

if [[ ! -f "$CCLSP_CONFIG_SRC" ]]; then
  warn "Config source not found: $CCLSP_CONFIG_SRC"
  exit 1
fi

if [[ -f "$CCLSP_CONFIG_DEST" ]]; then
  ok "Global config already exists: $CCLSP_CONFIG_DEST (skipping)"
else
  cp "$CCLSP_CONFIG_SRC" "$CCLSP_CONFIG_DEST"
  ok "Config copied to $CCLSP_CONFIG_DEST"
fi

echo ""

# ── 3. Register MCP server ──────────────────────────────────────────────────

echo "[ Claude Code MCP registration ]"

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — skipping MCP registration."
  warn "Run manually after installing Claude Code:"
  warn "  claude mcp add --scope user cclsp npx cclsp@latest --env CCLSP_CONFIG_PATH=$CCLSP_CONFIG_DEST"
else
  if claude mcp list 2>/dev/null | grep -q '^cclsp\b'; then
    ok "cclsp already registered as user-scoped MCP server (skipping)"
  else
    claude mcp add --scope user cclsp \
      npx cclsp@latest \
      --env "CCLSP_CONFIG_PATH=$CCLSP_CONFIG_DEST"
    ok "cclsp registered as user-scoped MCP server"
  fi
fi

echo ""
echo "=== cclsp setup done ==="
echo ""
echo "Verify: claude mcp list | grep cclsp"
echo "Note:   after editing cclsp.json reconnect via /mcp (restart_server only cycles LSPs)"
echo ""
