# =============================================================
# _setup-gpg.ps1
# One-time setup: generate a GPG key for signing Nexus release
# tags, configure git to use it, and print the public key to
# paste into GitHub Actions secrets (GPG_PUBLIC_KEY).
#
# Run once from the repo root:
#   .\_setup-gpg.ps1
# =============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Nexus GPG Signing Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- Check gpg is installed ---
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    Write-Host "  GPG not found. Install it first:" -ForegroundColor Red
    Write-Host "  winget install GnuPG.GnuPG" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- Check for an existing Nexus signing key ---
$existingKey = gpg --list-secret-keys --with-colons 2>$null |
               Where-Object { $_ -match "Nexus Release" } |
               Select-Object -First 1

if ($existingKey) {
    Write-Host "  An existing 'Nexus Release' key was found." -ForegroundColor Yellow
    $reuse = Read-Host "  Re-use it? (Y/n)"
    if ($reuse -eq "" -or $reuse -match "^[Yy]") {
        $keyId = (gpg --list-secret-keys --with-colons |
                  Where-Object { $_ -match "^sec" } |
                  Select-Object -First 1).Split(":")[4]
        Write-Host "  Using key: $keyId" -ForegroundColor Green
    } else {
        $existingKey = $null
    }
}

# --- Generate a new key if needed ---
if (-not $existingKey) {
    Write-Host "  Generating a new GPG key for Nexus release signing..." -ForegroundColor Cyan
    Write-Host "  You will be prompted to set a passphrase - store it safely." -ForegroundColor Yellow
    Write-Host ""

    $name  = $null
    $email = $null

    # --- Try SOPS-encrypted secrets/identity.yaml first (preferred) ---
    $sopsIdentity = Join-Path $PSScriptRoot "secrets\identity.yaml"
    if ((Get-Command sops -ErrorAction SilentlyContinue) -and (Test-Path $sopsIdentity)) {
        try {
            $ageKeyFile = Join-Path $env:APPDATA "sops\age\keys.txt"
            if (Test-Path $ageKeyFile) { $env:SOPS_AGE_KEY_FILE = $ageKeyFile }
            $jsonOut = sops decrypt --output-type json $sopsIdentity 2>$null
            if ($jsonOut) {
                $id     = $jsonOut | ConvertFrom-Json
                $name   = $id.name
                $email  = $id.email
                Write-Host "  Loaded identity from secrets\identity.yaml (SOPS)" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  Could not decrypt secrets\identity.yaml - will fall back." -ForegroundColor DarkGray
        }
    }

    # --- Fall back to legacy .gpg-identity ---
    $legacyIdentity = Join-Path $PSScriptRoot ".gpg-identity"
    if ((-not $name -or -not $email) -and (Test-Path $legacyIdentity)) {
        Get-Content $legacyIdentity | ForEach-Object {
            if ($_ -match "^Name=(.+)$")  { $name  = $Matches[1].Trim() }
            if ($_ -match "^Email=(.+)$") { $email = $Matches[1].Trim() }
        }
        Write-Host "  Loaded identity from .gpg-identity (legacy)" -ForegroundColor DarkGray
    }

    if (-not $name)  { $name  = Read-Host "Your full name" }
    if (-not $email) { $email = Read-Host "Your email" }

    $batchInput = "%no-protection`nKey-Type: RSA`nKey-Length: 4096`nSubkey-Type: RSA`nSubkey-Length: 4096`nName-Real: $name`nName-Comment: Nexus Release`nName-Email: $email`nExpire-Date: 2y`n%commit"

    $batchFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $batchFile -Value $batchInput -Encoding UTF8

    gpg --batch --gen-key $batchFile
    Remove-Item $batchFile -Force

    $keyId = (gpg --list-secret-keys --with-colons |
              Where-Object { $_ -match "^sec" } |
              Select-Object -Last 1).Split(":")[4]

    Write-Host ""
    Write-Host "  Key generated: $keyId" -ForegroundColor Green
}

# --- Configure git to use the key ---
Write-Host ""
Write-Host "  Configuring git to use key $keyId ..." -ForegroundColor Cyan
git config user.signingkey $keyId
git config commit.gpgsign false
git config tag.gpgsign true

Write-Host "  git is now configured to sign all tags with this key." -ForegroundColor Green

# --- Export public key for GitHub secret ---
Write-Host ""
Write-Host "================================================================"
Write-Host "  NEXT STEP: add the public key as a GitHub Actions secret."
Write-Host "  Secret name : GPG_PUBLIC_KEY"
Write-Host "  Secret value: (copied to clipboard and printed below)"
Write-Host "================================================================"
Write-Host ""

$pubKey = gpg --armor --export $keyId
$pubKey | Set-Clipboard
Write-Host $pubKey -ForegroundColor DarkGray

Write-Host ""
Write-Host "  The public key has been copied to your clipboard." -ForegroundColor Green
Write-Host ""
Write-Host "  Go to: https://github.com/RobertoTorino/Nexus/settings/secrets/actions"
Write-Host "  Click 'New repository secret', name it GPG_PUBLIC_KEY, paste the key."
Write-Host ""
Write-Host "  To also publish it to the public keyserver so users can verify tags:"
$sendCmd = "  gpg --keyserver keyserver.ubuntu.com --send-keys " + $keyId
Write-Host $sendCmd
Write-Host ""
pause
