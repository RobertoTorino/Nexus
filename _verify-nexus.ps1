# =============================================================
# _verify-nexus.ps1
# Run this script in the same folder as Nexus.exe to confirm
# the executable is genuine and has not been modified.
# =============================================================

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Locate the hash file
$hashFile = Get-ChildItem -Path $scriptDir -Filter "Nexus.sha256" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $hashFile) {
    Write-Host ""
    Write-Host "  ERROR: Nexus.sha256 not found in this folder." -ForegroundColor Red
    Write-Host "  The hash file must be present alongside Nexus.exe." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

# Parse "<HASH>  <filename>" (sha256sum standard format)
$content  = (Get-Content $hashFile.FullName).Trim()
$parts    = $content -split '\s+', 2
if ($parts.Count -lt 2) {
    Write-Host ""
    Write-Host "  ERROR: Nexus.sha256 has an unexpected format." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

$expectedHash = $parts[0].ToUpper()
$exeName      = $parts[1].Trim()
$exePath      = Join-Path $scriptDir $exeName

if (-not (Test-Path $exePath)) {
    Write-Host ""
    Write-Host "  ERROR: '$exeName' not found in this folder." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "  Verifying $exeName ..." -ForegroundColor Cyan

$actualHash = (Get-FileHash $exePath -Algorithm SHA256).Hash.ToUpper()

Write-Host ""
Write-Host "  Expected : $expectedHash"
Write-Host "  Actual   : $actualHash"
Write-Host ""

if ($actualHash -eq $expectedHash) {
    Write-Host "  VERIFIED - the file is genuine and unmodified." -ForegroundColor Green
} else {
    Write-Host "  MISMATCH - the file may have been tampered with!" -ForegroundColor Red
    Write-Host "  Do NOT run this executable." -ForegroundColor Red
}

Write-Host ""
pause
