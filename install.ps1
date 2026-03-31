# OpenClaw interactive CLI installer for Windows
# Usage: irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1; & $env:TEMP\install.ps1
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  OpenClaw Installer"
Write-Host "  ==================="
Write-Host ""

function Log($msg) { Write-Host "[openclaw] $msg" }

# -- 1. Check / install Node.js >= 22 --------------------------------
Log "Checking for Node.js >= 22..."
$needNode = $true
try {
    $nodeVersion = (node -v) -replace 'v', ''
    $major = [int]($nodeVersion.Split('.')[0])
    if ($major -ge 22) { $needNode = $false }
} catch { }

if ($needNode) {
    Log "Installing Node.js 22 via winget..."
    try {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent
    } catch {
        Log "winget failed, trying direct download..."
        $nodeUrl = "https://nodejs.org/dist/v22.16.0/node-v22.16.0-x64.msi"
        $installer = "$env:TEMP\node-installer.msi"
        Invoke-WebRequest -Uri $nodeUrl -OutFile $installer
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn" -Wait
        Remove-Item $installer -Force
    }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}
Log "Node.js $(node -v) OK"

# -- 2. Collect API keys interactively --------------------------------
Write-Host ""
Write-Host "  Configure AI Providers (press Enter to skip any)"
Write-Host "  -------------------------------------------------"
Write-Host ""

$anthropicKey  = Read-Host "  Anthropic API Key"
$geminiKey     = Read-Host "  Google Gemini API Key"
$openaiKey     = Read-Host "  OpenAI API Key"
$xaiKey        = Read-Host "  xAI API Key"
$openrouterKey = Read-Host "  OpenRouter API Key"

if (-not $anthropicKey -and -not $geminiKey -and -not $openaiKey -and -not $xaiKey -and -not $openrouterKey) {
    Write-Host ""
    Log "WARNING: No API keys provided. You can add them later in ~/.openclaw/.env"
}

# -- 3. Generate gateway token & create state directory ---------------
$gatewayToken = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
$stateDir = "$env:USERPROFILE\.openclaw"
New-Item -ItemType Directory -Force -Path "$stateDir\workspace" | Out-Null

$envContent = "OPENCLAW_GATEWAY_TOKEN=$gatewayToken`n"
if ($anthropicKey)  { $envContent += "ANTHROPIC_API_KEY=$anthropicKey`n" }
if ($geminiKey)     { $envContent += "GEMINI_API_KEY=$geminiKey`n" }
if ($openaiKey)     { $envContent += "OPENAI_API_KEY=$openaiKey`n" }
if ($xaiKey)        { $envContent += "XAI_API_KEY=$xaiKey`n" }
if ($openrouterKey) { $envContent += "OPENROUTER_API_KEY=$openrouterKey`n" }
Set-Content -Path "$stateDir\.env" -Value $envContent -Encoding UTF8

# -- 4. Install OpenClaw via npm --------------------------------------
Write-Host ""
Log "Installing OpenClaw globally via npm..."
npm install -g openclaw@latest
Log "OpenClaw installed"

# -- 5. Run onboarding ------------------------------------------------
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

# -- 9. Start the gateway --------------------------------------------
Log "Installing gateway service..."
try { & openclaw gateway install 2>&1 } catch { }
Log "Starting gateway..."
try { & openclaw gateway start 2>&1 } catch { }

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
Write-Host "  Gateway Token: $gatewayToken"
Write-Host "  Config: $stateDir\.env"
Write-Host ""
