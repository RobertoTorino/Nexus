param(
    [string]$DatabaseName = "nexus-beta",
    [int]$Count = 1,
    [int]$MaxUses = 1,
    [int]$ExpiresInDays = 30,
    [string]$Prefix = "BETA",
    [switch]$DryRun,
    [switch]$Remote
)

$ErrorActionPreference = "Stop"

function Write-Step($text) {
    Write-Host "`n==> $text" -ForegroundColor Cyan
}

function Assert-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command '$name' not found. Install it first."
    }
}

function Resolve-WranglerCommand([string]$scriptRoot) {
    $localWrangler = Join-Path $scriptRoot "node_modules/.bin/wrangler.cmd"
    if (Test-Path $localWrangler) {
        return $localWrangler
    }

    $globalCmd = Get-Command "wrangler" -ErrorAction SilentlyContinue
    if ($null -ne $globalCmd) {
        return $globalCmd.Source
    }

    throw "Wrangler not found. Install dependencies with npm install in backend/nexus-auth-worker or add wrangler to PATH."
}

function Invoke-Wrangler([string[]]$CommandArgs) {
    & $script:WranglerCmd @CommandArgs
}

function New-InviteCode([string]$prefix) {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    $rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 8
    $rand.GetBytes($bytes)

    $part1 = ""
    $part2 = ""
    for ($i = 0; $i -lt 4; $i++) {
        $part1 += $chars[$bytes[$i] % $chars.Length]
    }
    for ($i = 4; $i -lt 8; $i++) {
        $part2 += $chars[$bytes[$i] % $chars.Length]
    }

    return "$prefix-$part1$part2"
}

if ($Count -lt 1 -or $Count -gt 1000) {
    throw "Count must be between 1 and 1000."
}

if ($MaxUses -lt 1) {
    throw "MaxUses must be >= 1."
}

if ($ExpiresInDays -lt 1 -or $ExpiresInDays -gt 3650) {
    throw "ExpiresInDays must be between 1 and 3650."
}

if ([string]::IsNullOrWhiteSpace($Prefix)) {
    throw "Prefix cannot be empty."
}

$safePrefix = ($Prefix.Trim().ToUpperInvariant() -replace "[^A-Z0-9]", "")
if ([string]::IsNullOrWhiteSpace($safePrefix)) {
    throw "Prefix must contain at least one alphanumeric character."
}

Write-Step "Checking prerequisites"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$script:WranglerCmd = Resolve-WranglerCommand -scriptRoot $root

$expiresAtSql = "strftime('%s','now','+$ExpiresInDays days')"
$codes = New-Object System.Collections.Generic.List[string]

Write-Step "Seeding $Count invite code(s) into '$DatabaseName'"
if ($Remote) {
    Write-Host "D1 target: remote" -ForegroundColor DarkCyan
} else {
    Write-Host "D1 target: local" -ForegroundColor DarkCyan
}

for ($i = 0; $i -lt $Count; $i++) {
    $attempt = 0
    while ($true) {
        $attempt++
        if ($attempt -gt 10) {
            throw "Failed to generate a unique invite code after multiple attempts."
        }

        $code = New-InviteCode -prefix $safePrefix
        $safeCode = $code.Replace("'", "''")
        $sql = "INSERT OR IGNORE INTO beta_invites(code,max_uses,use_count,expires_at,revoked,created_at) VALUES('$safeCode',$MaxUses,0,$expiresAtSql,0,strftime('%s','now'));"

        if ($DryRun) {
            Write-Host "[DryRun] $sql" -ForegroundColor Yellow
            $codes.Add($code)
            break
        }

        $insertArgs = @("d1", "execute", $DatabaseName, "--command", $sql)
        if ($Remote) {
            $insertArgs += "--remote"
        }
        Invoke-Wrangler -CommandArgs $insertArgs | Out-Null

        $verifySql = "SELECT code FROM beta_invites WHERE code = '$safeCode' LIMIT 1;"
        $verifyArgs = @("d1", "execute", $DatabaseName, "--command", $verifySql)
        if ($Remote) {
            $verifyArgs += "--remote"
        }
        $verifyOut = Invoke-Wrangler -CommandArgs $verifyArgs | Out-String
        if ($verifyOut -match [Regex]::Escape($code)) {
            $codes.Add($code)
            break
        }
    }
}

Write-Step "Invite generation complete"
Write-Host "Created invite codes:" -ForegroundColor Green
$codes | ForEach-Object { Write-Host "  $_" }

Write-Host "`nSettings:" -ForegroundColor Yellow
Write-Host "  - Max uses per code: $MaxUses"
Write-Host "  - Expires in days: $ExpiresInDays"
Write-Host "  - Prefix: $safePrefix"
