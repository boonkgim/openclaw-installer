#!/usr/bin/env bash
# OpenClaw interactive CLI installer for macOS/Linux
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.sh)
set -euo pipefail

echo ""
echo "  OpenClaw Installer"
echo "  ==================="
echo ""

log() { echo "[openclaw] $*"; }

# -- 1. Check / install Node.js >= 22 --------------------------------
log "Checking for Node.js >= 22..."
NEED_NODE=true
if command -v node &>/dev/null; then
  NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
  if (( NODE_MAJOR >= 22 )); then
    NEED_NODE=false
  fi
fi
if $NEED_NODE; then
  if ! command -v brew &>/dev/null; then
    log "Installing Homebrew (will also install Xcode Command Line Tools)..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
  log "Installing Node.js 22 via Homebrew..."
  brew install node@22
  brew link --overwrite node@22 2>/dev/null || true
fi
log "Node.js $(node -v) OK"

# -- 2. Collect API keys interactively --------------------------------
echo ""
echo "  Configure AI Providers (press Enter to skip any)"
echo "  -------------------------------------------------"
echo ""

read -rp "  Anthropic API Key: " ANTHROPIC_KEY
read -rp "  Google Gemini API Key: " GEMINI_KEY
read -rp "  OpenAI API Key: " OPENAI_KEY
read -rp "  xAI API Key: " XAI_KEY
read -rp "  OpenRouter API Key: " OPENROUTER_KEY

if [[ -z "$ANTHROPIC_KEY" && -z "$GEMINI_KEY" && -z "$OPENAI_KEY" && -z "$XAI_KEY" && -z "$OPENROUTER_KEY" ]]; then
  echo ""
  log "WARNING: No API keys provided. You can add them later in ~/.openclaw/.env"
fi

# -- 3. Generate gateway token & create state directory ---------------
GATEWAY_TOKEN=$(openssl rand -hex 32)
STATE_DIR="$HOME/.openclaw"
mkdir -p "$STATE_DIR/workspace"

ENV_FILE="$STATE_DIR/.env"
cat > "$ENV_FILE" <<EOF
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
EOF
[[ -n "$ANTHROPIC_KEY" ]]  && echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY"   >> "$ENV_FILE"
[[ -n "$GEMINI_KEY" ]]     && echo "GEMINI_API_KEY=$GEMINI_KEY"         >> "$ENV_FILE"
[[ -n "$OPENAI_KEY" ]]     && echo "OPENAI_API_KEY=$OPENAI_KEY"         >> "$ENV_FILE"
[[ -n "$XAI_KEY" ]]        && echo "XAI_API_KEY=$XAI_KEY"               >> "$ENV_FILE"
[[ -n "$OPENROUTER_KEY" ]] && echo "OPENROUTER_API_KEY=$OPENROUTER_KEY" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"

# -- 4. Install OpenClaw via npm --------------------------------------
echo ""
log "Installing OpenClaw globally via npm..."
npm install -g openclaw@latest
log "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'ok')"

# -- 5. Run onboarding ------------------------------------------------
log "Running onboard..."
openclaw onboard --install-daemon --non-interactive --accept-risk 2>&1 || true

# -- 6. Configure settings --------------------------------------------
log "Configuring settings..."
openclaw config set tools.web.search.provider gemini 2>&1 || true
openclaw config set tools.web.search.gemini.model gemini-2.5-flash 2>&1 || true
openclaw config set agents.defaults.heartbeat.every 0m 2>&1 || true
openclaw config set gateway.mode local 2>&1 || true

# -- 7. Set default model based on available providers ----------------
DEFAULT_MODEL=""
[[ -n "$ANTHROPIC_KEY" ]]  && DEFAULT_MODEL="anthropic/claude-sonnet-4-6"
[[ -z "$DEFAULT_MODEL" && -n "$GEMINI_KEY" ]]     && DEFAULT_MODEL="google/gemini-3.1-flash-lite"
[[ -z "$DEFAULT_MODEL" && -n "$OPENAI_KEY" ]]      && DEFAULT_MODEL="openai/gpt-4.1"
[[ -z "$DEFAULT_MODEL" && -n "$XAI_KEY" ]]         && DEFAULT_MODEL="xai/grok-3"
[[ -z "$DEFAULT_MODEL" && -n "$OPENROUTER_KEY" ]]  && DEFAULT_MODEL="openrouter/anthropic/claude-opus-4-6"
if [[ -n "$DEFAULT_MODEL" ]]; then
  log "Setting default model to $DEFAULT_MODEL..."
  openclaw models set "$DEFAULT_MODEL" 2>&1 || true
fi

# -- 8. Install shell completion --------------------------------------
openclaw completion --install --yes 2>&1 || true

# -- 9. Start the gateway --------------------------------------------
log "Installing gateway service..."
openclaw gateway install 2>&1 || true
log "Starting gateway..."
openclaw gateway start 2>&1 || true

# -- 10. Wait for gateway ---------------------------------------------
log "Waiting for gateway to be ready..."
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:18789/healthz" &>/dev/null; then
    echo ""
    log "Gateway is ready!"
    echo ""
    echo "  Dashboard: http://127.0.0.1:18789/"
    echo "  Gateway Token: $GATEWAY_TOKEN"
    echo "  Config: $ENV_FILE"
    echo ""
    exit 0
  fi
  sleep 1
done

echo ""
log "Gateway may still be starting. Check http://127.0.0.1:18789/"
echo ""
echo "  Gateway Token: $GATEWAY_TOKEN"
echo "  Config: $ENV_FILE"
echo ""
exit 0
