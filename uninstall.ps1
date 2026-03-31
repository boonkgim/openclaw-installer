# OpenClaw CLI uninstaller for Windows
# Usage: irm https://raw.githubusercontent.com/boonkgim/openclaw-installer/main/uninstall.ps1 -OutFile $env:TEMP\uninstall.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\uninstall.ps1
$ErrorActionPreference = "SilentlyContinue"
$StateDir = "$env:USERPROFILE\.openclaw"

function Log($msg) { Write-Host "[openclaw] $msg" }

Write-Host ""
Write-Host "  OpenClaw Uninstaller"
Write-Host "  ====================="
Write-Host ""

$confirm = Read-Host "  This will remove OpenClaw and all its data. Continue? [y/N]"
if ($confirm -notmatch '^[yY]') {
    Write-Host "  Cancelled."
    exit 0
}

Write-Host ""

# -- 1. Stop the gateway ----------------------------------------------
Log "Stopping gateway..."
try { & openclaw gateway stop 2>&1 } catch { }
try { & openclaw gateway uninstall 2>&1 } catch { }

# -- 2. Remove scheduled task -----------------------------------------
Log "Removing scheduled task..."
try {
    Unregister-ScheduledTask -TaskName "OpenClaw Gateway" -Confirm:$false
} catch { }

# -- 3. Kill remaining processes --------------------------------------
Log "Killing remaining processes..."
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like "*openclaw*" -and $_.ProcessName -notlike "*Installer*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

# -- 4. Remove npm package --------------------------------------------
Log "Removing openclaw npm package..."
try { npm rm -g openclaw 2>&1 } catch { }

# -- 5. Remove state directory ----------------------------------------
if (Test-Path $StateDir) {
    Log "Removing state directory: $StateDir"
    Remove-Item -Recurse -Force $StateDir
}

# -- 6. Remove git-based install if present ---------------------------
$gitDir = "$env:USERPROFILE\openclaw"
if (Test-Path $gitDir) {
    Log "Removing $gitDir (git install)"
    Remove-Item -Recurse -Force $gitDir
}

Write-Host ""
Log "Uninstall complete."
Write-Host ""
