# OpenClaw Installer

One-click installer for [OpenClaw](https://openclaw.ai).

## Prerequisites

**macOS:**
```bash
xcode-select --install                    # Xcode Command Line Tools
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"  # Homebrew
brew install node@24                      # Node.js
```

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # allow npm/openclaw scripts (one-time)
winget install OpenJS.NodeJS.LTS                      # Node.js
```

> The CLI installer below will install Node.js automatically if missing — these are only needed if you prefer to install manually or want to use `openclaw` commands directly.

## Quick Install (CLI)

**macOS / Linux:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.sh)
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
```

Safe to re-run — preserves your gateway token and existing API keys.

## Uninstall (CLI)

**macOS / Linux:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/uninstall.sh)
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/uninstall.ps1 -OutFile $env:TEMP\uninstall.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\uninstall.ps1
```

## GUI Installer

Go to the [Releases](https://github.com/boonkgim/openclaw-installer/releases/latest) page and download:

- **macOS** — `OpenClaw Installer-x.x.x-universal.dmg`
- **Windows** — `OpenClaw Installer Setup x.x.x.exe`

> **Note:** Windows exe is unsigned. If Smart App Control blocks it, right-click → Properties → Unblock, or use the CLI install above instead.

## Features

- **One-click setup** — Installs Node.js, OpenClaw, and starts the gateway automatically
- **Multi-provider support** — Configure API keys for Anthropic, OpenAI, Google Gemini, xAI, OpenRouter, and Vercel AI Gateway
- **OAuth authentication** — OpenAI Codex OAuth 2.0 + PKCE browser login with auto-refresh
- **Anthropic auth options** — API key, setup token, or Claude CLI backend credential reuse
- **Auto-register models** — Discovers and registers all available models from each configured provider (including catalog lookup for OAuth providers)
- **Built-in management** — Update, repair, restart, or uninstall OpenClaw from the app
- **Environment editor** — View and edit `.env` configuration directly in the app
- **Exec approval defaults** — New installs skip repetitive permission prompts automatically
- **Provider persistence** — Configured providers (including Claude CLI backend) persist across app restarts
