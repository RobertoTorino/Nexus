# =============================================================
# _setup-sops.ps1
# One-time setup: install age + SOPS, generate an age key,
# configure .sops.yaml, and create initial encrypted secret
# stubs for identity, backend tokens, and GPG private key.
#
# Encrypted files in secrets/ are SAFE TO COMMIT - they can
# only be decrypted with your age private key.
#
# Run once from the repo root:
#   .\_setup-sops.ps1
# =============================================================

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step([string]$text) {
    Write-Host ""
    Write-Host "  ==> $text" -ForegroundColor Cyan
}

function Refresh-EnvPath {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

Write-Host ""
Write-Host "=== Nexus SOPS / age Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- Install age ---
Write-Step "Checking age"
if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing age via winget..." -ForegroundColor Yellow
    winget install FiloSottile.age --accept-source-agreements --accept-package-agreements
    Refresh-EnvPath
}
if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
    Write-Host "  age still not found. Restart this terminal and re-run." -ForegroundColor Red
    exit 1
}
Write-Host "  age $(age --version)" -ForegroundColor Green

# --- Install SOPS ---
Write-Step "Checking SOPS"
if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing SOPS via winget..." -ForegroundColor Yellow
    winget install mozilla.sops --accept-source-agreements --accept-package-agreements
    Refresh-EnvPath
}
if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
    Write-Host "  SOPS still not found. Restart this terminal and re-run." -ForegroundColor Red
    exit 1
}
Write-Host "  sops $(sops --version)" -ForegroundColor Green

# --- Age key ---
Write-Step "Age key"
$ageKeyDir  = Join-Path $env:APPDATA "sops\age"
$ageKeyFile = Join-Path $ageKeyDir "keys.txt"
$pubKey     = $null

if (Test-Path $ageKeyFile) {
    Write-Host "  Key file found: $ageKeyFile" -ForegroundColor DarkGray
    $pubKey = (Get-Content $ageKeyFile |
               Where-Object { $_ -match "^# public key:" } |
               Select-Object -First 1) -replace "^# public key:\s*", ""
    Write-Host "  Reusing existing key." -ForegroundColor Green
} else {
    Write-Host "  Generating new age key..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $ageKeyDir | Out-Null
    age-keygen -o $ageKeyFile
    $pubKey = (Get-Content $ageKeyFile |
               Where-Object { $_ -match "^# public key:" } |
               Select-Object -First 1) -replace "^# public key:\s*", ""
    Write-Host "  Key generated." -ForegroundColor Green
}

if (-not $pubKey) {
    Write-Host "  Could not read public key from $ageKeyFile" -ForegroundColor Red
    exit 1
}

Write-Host "  Public key: $pubKey" -ForegroundColor DarkGray

# --- Write .sops.yaml ---
Write-Step "Writing .sops.yaml"
$sopsConfig = Join-Path $repoRoot ".sops.yaml"

# Using single-quoted here-string then replacing the placeholder to avoid $ escaping issues
$sopsTemplate = @'
# SOPS configuration - managed by _setup-sops.ps1
# Encrypted files in secrets/*.yaml are safe to commit.
# Your age PRIVATE key lives at: AGE_KEY_FILE_PLACEHOLDER
# Back it up to your password manager - without it nothing can be decrypted.

creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: >-
      AGE_PUBKEY_PLACEHOLDER
'@

$sopsYaml = $sopsTemplate `
    -replace "AGE_KEY_FILE_PLACEHOLDER", $ageKeyFile.Replace("\", "/") `
    -replace "AGE_PUBKEY_PLACEHOLDER",   $pubKey

Set-Content -Path $sopsConfig -Value $sopsYaml -Encoding UTF8
Write-Host "  .sops.yaml written." -ForegroundColor Green

# --- Create secrets directory ---
$secretsDir = Join-Path $repoRoot "secrets"
New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null

# --- Helper: encrypt a YAML string into a secrets file ---
function New-SopsSecret([string]$destPath, [string]$yamlContent) {
    $fileName = Split-Path $destPath -Leaf
    if (Test-Path $destPath) {
        Write-Host "  $fileName already exists - skipping." -ForegroundColor DarkGray
        Write-Host "    Edit with:  sops edit secrets\$fileName" -ForegroundColor DarkGray
        return
    }
    $tmp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".yaml")
    Set-Content -Path $tmp -Value $yamlContent -Encoding UTF8
    try {
        # Set SOPS_AGE_KEY_FILE so sops can find the key without env setup.
        # --filename-override tells SOPS to match creation rules against the
        # destination path (secrets/xxx.yaml) rather than the temp file path.
        $env:SOPS_AGE_KEY_FILE = $ageKeyFile
        sops encrypt --filename-override "secrets/$fileName" --output $destPath $tmp
        Write-Host "  Created: $fileName" -ForegroundColor Green
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# --- Create encrypted secret stubs ---
Write-Step "Creating encrypted secret files"

New-SopsSecret (Join-Path $secretsDir "identity.yaml") @'
# GPG signing identity - used by _setup-gpg.ps1
name: Your Name
email: your@email.com
'@

New-SopsSecret (Join-Path $secretsDir "backend.yaml") @'
# Cloudflare Worker secrets - deploy with: wrangler secret put <KEY>
ACCESS_JWT_SECRET: replace-with-strong-random-secret
REFRESH_HASH_SECRET: replace-with-strong-random-secret
CF_ACCOUNT_ID: ""
CF_API_TOKEN: ""
# Beta invite tokens (comma-separated or listed below)
invite_tokens: []
'@

New-SopsSecret (Join-Path $secretsDir "gpg.yaml") @'
# Export with: gpg --armor --export-secret-keys <keyid>
# Then paste the block as the value of private_key below.
private_key: |
  -----BEGIN PGP PRIVATE KEY BLOCK-----
  PASTE_HERE
  -----END PGP PRIVATE KEY BLOCK-----
gpg_passphrase: ""
'@

# --- Print the age key so the user can copy it to a password manager ---
Write-Host ""
Write-Host "  Your age PRIVATE key (store this in Bitwarden / 1Password NOW):" -ForegroundColor Yellow
Write-Host ""
Get-Content $ageKeyFile | Where-Object { $_ -match "^AGE-SECRET-KEY-" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor DarkYellow
}
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  ACTION REQUIRED: back up the private key shown above." -ForegroundColor Yellow
Write-Host "  File location  : $ageKeyFile" -ForegroundColor Yellow
Write-Host "  Lose that key  = lose all encrypted secrets permanently." -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1.  Save age key to password manager (shown above)." -ForegroundColor White
Write-Host "  2.  Fill in identity:  sops edit secrets\identity.yaml" -ForegroundColor White
Write-Host "  3.  Fill in backend:   sops edit secrets\backend.yaml" -ForegroundColor White
Write-Host "  4.  Export GPG key and store in secrets\gpg.yaml:" -ForegroundColor White
Write-Host "        gpg --armor --export-secret-keys <keyid>" -ForegroundColor DarkGray
Write-Host "        sops edit secrets\gpg.yaml" -ForegroundColor DarkGray
Write-Host "  5.  Commit:  git add .sops.yaml secrets\ && git commit -m 'Add encrypted secrets'" -ForegroundColor White
Write-Host ""
pause
