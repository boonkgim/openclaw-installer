#!/usr/bin/env bash
# OpenClaw CLI uninstaller for macOS/Linux
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/uninstall.sh)
set -euo pipefail

STATE_DIR="$HOME/.openclaw"

log() { echo "[openclaw] $*"; }

echo ""
echo "  OpenClaw Uninstaller"
echo "  ====================="
echo ""

read -rp "  This will remove OpenClaw and all its data. Continue? [y/N] " confirm
if [[ "$confirm" != [yY]* ]]; then
  echo "  Cancelled."
  exit 0
fi

echo ""

# -- 1. Stop the gateway ----------------------------------------------
log "Stopping gateway..."
openclaw gateway stop 2>&1 || true
openclaw gateway uninstall 2>&1 || true

# -- 2. Kill remaining processes --------------------------------------
log "Killing remaining processes..."
pkill -f "openclaw" 2>/dev/null || true

# -- 3. Remove npm package --------------------------------------------
log "Removing openclaw npm package..."
npm rm -g openclaw 2>&1 || true

# -- 4. Remove state directory ----------------------------------------
if [[ -d "$STATE_DIR" ]]; then
  log "Removing state directory: $STATE_DIR"
  rm -rf "$STATE_DIR"
fi

# -- 5. Remove git-based install if present ---------------------------
if [[ -d "$HOME/openclaw" ]]; then
  log "Removing $HOME/openclaw (git install)"
  rm -rf "$HOME/openclaw"
fi

echo ""
log "Uninstall complete."
echo ""
