param(
    [string]$DatabaseName = "nexus-beta",
    [string]$InviteCode = "ABC-123",
    [int]$MaxUses = 100
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

Write-Step "Checking prerequisites"
Assert-Command "node"
Assert-Command "npm"
Assert-Command "wrangler"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Step "Installing npm dependencies"
npm install

Write-Step "Creating D1 database '$DatabaseName'"
$dbCreateOutput = wrangler d1 create $DatabaseName | Out-String
Write-Host $dbCreateOutput

$databaseId = ""
if ($dbCreateOutput -match "database_id\s*=\s*([a-f0-9\-]+)") {
    $databaseId = $Matches[1]
} elseif ($dbCreateOutput -match 'database_id"\s*:\s*"([a-f0-9\-]+)"') {
    $databaseId = $Matches[1]
}

if ([string]::IsNullOrWhiteSpace($databaseId)) {
    Write-Warning "Could not parse database_id automatically. Update wrangler.toml manually."
} else {
    Write-Step "Updating wrangler.toml database_id"
    $wranglerPath = Join-Path $root "wrangler.toml"
    $wranglerText = Get-Content $wranglerPath -Raw
    $wranglerText = $wranglerText -replace 'database_id\s*=\s*"[^"]*"', ('database_id = "' + $databaseId + '"')
    Set-Content -Path $wranglerPath -Value $wranglerText -NoNewline
    Write-Host "Updated database_id: $databaseId" -ForegroundColor Green
}

Write-Step "Applying schema"
wrangler d1 execute $DatabaseName --file=./schema.sql

Write-Step "Seeding invite code '$InviteCode'"
$safeInviteCode = $InviteCode.Replace("'", "''")
$seedSql = "INSERT OR IGNORE INTO beta_invites(code,max_uses,use_count,expires_at,revoked,created_at) VALUES('$safeInviteCode',$MaxUses,0,NULL,0,strftime('%s','now'));"
wrangler d1 execute $DatabaseName --command $seedSql

Write-Step "Backend setup complete"
Write-Host "Next manual steps:" -ForegroundColor Yellow
Write-Host "  1) wrangler secret put ACCESS_JWT_SECRET"
Write-Host "  2) wrangler secret put REFRESH_HASH_SECRET"
Write-Host "  3) wrangler deploy"
Write-Host "  4) Put your deployed URL into nexus.ini -> BetaAuthBaseUrl"
