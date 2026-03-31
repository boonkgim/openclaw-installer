# OpenClaw Installer

One-click installer for [OpenClaw](https://openclaw.ai).

## Quick Install (CLI)

**macOS / Linux:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.sh)
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1; & $env:TEMP\install.ps1
```

## GUI Installer

Go to the [Releases](https://github.com/boonkgim/openclaw-installer/releases/latest) page and download:

- **macOS** — `OpenClaw Installer-x.x.x-universal.dmg`
- **Windows** — `OpenClaw Installer Setup x.x.x.exe`

### macOS
1. Download the `.dmg` file
2. Open it and drag the app to your Applications folder
3. Launch OpenClaw Installer from Applications

### Windows
1. Download the `.exe` file
2. Run the installer and follow the prompts
3. Launch OpenClaw Installer from the Start menu

> **Note:** If upgrading, close the OpenClaw Installer app before running the new setup exe.

## Features

- **One-click setup** — Installs Node.js, OpenClaw, and starts the gateway automatically
- **Multi-provider support** — Configure API keys for Anthropic, OpenAI, Google Gemini, xAI, OpenRouter, and Vercel AI Gateway
- **OAuth authentication** — OpenAI Codex OAuth 2.0 + PKCE browser login with auto-refresh
- **Anthropic auth options** — API key, setup token, or Claude CLI backend credential reuse
- **Auto-register models** — Discovers and registers all available models from each configured provider
- **Built-in management** — Update, repair, restart, or uninstall OpenClaw from the app
- **Environment editor** — View and edit `.env` configuration directly in the app
