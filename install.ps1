# OpenClaw interactive CLI installer for Windows
# Idempotent -- safe to re-run to add/change providers without breaking existing setup
# Usage: irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
$ErrorActionPreference = "Stop"

# Allow .ps1 wrappers (npm.ps1, openclaw.ps1, etc.) to run in this session.
# Without this, default Restricted policy blocks npm/openclaw commands even
# though the installer itself was launched with -ExecutionPolicy Bypass.
Set-ExecutionPolicy -Scope Process Bypass -Force

Write-Host ""
Write-Host "  OpenClaw Installer"
Write-Host "  ==================="
Write-Host ""

$StateDir = "$env:USERPROFILE\.openclaw"
$EnvFile = "$StateDir\.env"

function Log($msg) { Write-Host "[openclaw] $msg" }

# Load existing .env values (if any)
$existingKeys = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
            $parts = $line -split '=', 2
            $existingKeys[$parts[0].Trim()] = $parts[1]
        }
    }
}

# -- 1. Check / install Node.js >= 22 --------------------------------
Log "Checking for Node.js >= 22..."
$needNode = $true
try {
    $nodeVersion = (node -v) -replace 'v', ''
    $major = [int]($nodeVersion.Split('.')[0])
    if ($major -ge 22) { $needNode = $false }
} catch { }

if ($needNode) {
    # Check if nvm-windows is managing Node.js
    $hasNvm = (Get-Command nvm -ErrorAction SilentlyContinue) -ne $null
    if ($hasNvm) {
        Log "nvm detected. Installing Node.js 22 via nvm..."
        nvm install 22
        nvm use 22
    } else {
        Log "Installing Node.js 22 via winget..."
        $wingetOk = $false
        try {
            winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent --force
            if ($LASTEXITCODE -eq 0) { $wingetOk = $true }
        } catch { }

        if (-not $wingetOk) {
            Log "winget failed, trying direct download..."
            $nodeUrl = "https://nodejs.org/dist/v22.16.0/node-v22.16.0-x64.msi"
            $installer = "$env:TEMP\node-installer.msi"
            Invoke-WebRequest -Uri $nodeUrl -OutFile $installer
            Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn" -Verb RunAs -Wait
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
        }
    }

    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

    try {
        $null = node -v
    } catch {
        Log "ERROR: Node.js installation failed. Please install Node.js 22+ manually:"
        if ($hasNvm) { Log "  nvm install 22 && nvm use 22" }
        else { Log "  Download from https://nodejs.org/" }
        Log "Then re-run this installer."
        exit 1
    }
}
Log "Node.js $(node -v) OK"

# -- 2. Collect API keys interactively --------------------------------
Write-Host ""
Write-Host "  Configure AI Providers"
Write-Host "  Press Enter to keep existing value, or type new key to replace"
Write-Host "  -------------------------------------------------"
Write-Host ""

function Prompt-Key {
    param([string]$Label, [string]$EnvKey)
    $existing = $existingKeys[$EnvKey]
    $hint = ""
    if ($existing) {
        $masked = $existing.Substring([Math]::Max(0, $existing.Length - 4))
        $hint = " [current: ...$masked]"
    }
    $input = Read-Host "  $Label$hint"
    if ($input) { return $input }
    return $existing
}

$anthropicKey  = Prompt-Key -Label "Anthropic API Key" -EnvKey "ANTHROPIC_API_KEY"
$geminiKey     = Prompt-Key -Label "Google Gemini API Key" -EnvKey "GEMINI_API_KEY"
$openaiKey     = Prompt-Key -Label "OpenAI API Key" -EnvKey "OPENAI_API_KEY"
$xaiKey        = Prompt-Key -Label "xAI API Key" -EnvKey "XAI_API_KEY"
$openrouterKey = Prompt-Key -Label "OpenRouter API Key" -EnvKey "OPENROUTER_API_KEY"

# -- 3. Preserve or generate gateway token ----------------------------
$gatewayToken = $existingKeys["OPENCLAW_GATEWAY_TOKEN"]
if (-not $gatewayToken) {
    $gatewayToken = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
    Log "Generated new gateway token"
} else {
    Log "Using existing gateway token"
}

New-Item -ItemType Directory -Force -Path "$StateDir\workspace" | Out-Null

# Write .env (preserves gateway token, updates only changed keys)
$envContent = "OPENCLAW_GATEWAY_TOKEN=$gatewayToken`n"
if ($anthropicKey)  { $envContent += "ANTHROPIC_API_KEY=$anthropicKey`n" }
if ($geminiKey)     { $envContent += "GEMINI_API_KEY=$geminiKey`n" }
if ($openaiKey)     { $envContent += "OPENAI_API_KEY=$openaiKey`n" }
if ($xaiKey)        { $envContent += "XAI_API_KEY=$xaiKey`n" }
if ($openrouterKey) { $envContent += "OPENROUTER_API_KEY=$openrouterKey`n" }
Set-Content -Path $EnvFile -Value $envContent -Encoding UTF8

# -- 4. Install / update OpenClaw via npm -----------------------------
Write-Host ""
Log "Installing OpenClaw globally via npm..."
npm install -g openclaw@latest
Log "OpenClaw installed"

# -- 5. Run onboarding (skips if already onboarded) -------------------
Log "Running onboard..."
try { & openclaw onboard --install-daemon --non-interactive --accept-risk 2>&1 } catch { }

# -- 6. Configure settings --------------------------------------------
Log "Configuring settings..."
try { & openclaw config set tools.web.search.provider gemini 2>&1 } catch { }
try { & openclaw config set tools.web.search.gemini.model gemini-2.5-flash 2>&1 } catch { }
try { & openclaw config set agents.defaults.heartbeat.every 0m 2>&1 } catch { }
try { & openclaw config set gateway.mode local 2>&1 } catch { }

# -- 7. Set default model based on available providers ----------------
$defaultModel = ""
if ($anthropicKey)                          { $defaultModel = "anthropic/claude-sonnet-4-6" }
if (-not $defaultModel -and $geminiKey)     { $defaultModel = "google/gemini-3.1-flash-lite" }
if (-not $defaultModel -and $openaiKey)     { $defaultModel = "openai/gpt-4.1" }
if (-not $defaultModel -and $xaiKey)        { $defaultModel = "xai/grok-3" }
if (-not $defaultModel -and $openrouterKey) { $defaultModel = "openrouter/anthropic/claude-opus-4-6" }
if ($defaultModel) {
    Log "Setting default model to $defaultModel..."
    try { & openclaw models set $defaultModel 2>&1 } catch { }
}

# -- 8. Install shell completion --------------------------------------
try { & openclaw completion --install --yes 2>&1 } catch { }

# -- 9. Start the gateway (hidden — no visible console window) --------
Log "Installing gateway service..."
try { & openclaw gateway install 2>&1 } catch { }

# Fix startup entry: replace "start /min" with fully-hidden VBS launcher
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$startupCmd = "$startupDir\OpenClaw Gateway.cmd"
$gatewayCmd = "$StateDir\gateway.cmd"
$launcherVbs = "$StateDir\gateway-launcher.vbs"

if (Test-Path $gatewayCmd) {
    # VBS launcher runs gateway.cmd with window style 0 (hidden)
    Set-Content -Path $launcherVbs -Value @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$gatewayCmd""", 0, False
"@ -Encoding ASCII

    if (Test-Path $startupCmd) {
        Set-Content -Path $startupCmd -Value @"
@echo off
wscript.exe "$launcherVbs"
"@ -Encoding ASCII
    }
}

# Stop existing gateway, then start hidden via gateway.cmd
Log "Restarting gateway..."
try { & openclaw gateway stop 2>&1 } catch { }
Start-Sleep -Seconds 1

if (Test-Path $gatewayCmd) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c `"$gatewayCmd`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $StateDir
    [System.Diagnostics.Process]::Start($psi) | Out-Null
} else {
    # Fallback if gateway.cmd doesn't exist yet
    try { & openclaw gateway start 2>&1 } catch { }
}

# -- 10. Wait for gateway ---------------------------------------------
Log "Waiting for gateway to be ready..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:18789/healthz" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch { }
    Start-Sleep -Seconds 1
}

Write-Host ""
if ($ready) {
    Log "Gateway is ready!"
} else {
    Log "Gateway may still be starting."
}
Write-Host ""
Write-Host "  Dashboard: http://127.0.0.1:18789/"
Write-Host "  Config: $EnvFile"
Write-Host ""
