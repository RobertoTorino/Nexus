param(
    [string]$DatabaseName = "nexus-beta",
    [switch]$RotateAccessJwtSecret = $true,
    [switch]$RotateRefreshHashSecret = $true,
    [switch]$RevokeAllRefreshTokens = $true,
    [switch]$RevokeAllDevices,
    [switch]$RevokeAllInvites,
    [switch]$DeployAfter,
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

function New-SecretValue([int]$bytes = 48) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    return [Convert]::ToBase64String($buffer).TrimEnd('=') -replace '\+', '-' -replace '/', '_'
}

function Set-WranglerSecret([string]$secretName, [string]$secretValue) {
    if ($DryRun) {
        Write-Host "[DryRun] wrangler secret put $secretName" -ForegroundColor Yellow
        return
    }

    $secretValue | Invoke-Wrangler -CommandArgs @("secret", "put", $secretName) | Out-Null
    Write-Host "Rotated secret: $secretName" -ForegroundColor Green
}

function Execute-D1([string]$sql, [string]$label) {
    if ($DryRun) {
        Write-Host "[DryRun] $label" -ForegroundColor Yellow
        Write-Host "[DryRun] SQL: $sql" -ForegroundColor DarkYellow
        return
    }

    Write-Step $label
    $d1Args = @("d1", "execute", $DatabaseName, "--command", $sql)
    if ($Remote) {
        $d1Args += "--remote"
    }
    Invoke-Wrangler -CommandArgs $d1Args | Out-Null
}

Write-Step "Checking prerequisites"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$script:WranglerCmd = Resolve-WranglerCommand -scriptRoot $root

$incidentTag = "incident-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Step "Emergency lockout started ($incidentTag)"
if ($Remote) {
    Write-Host "D1 target: remote" -ForegroundColor DarkCyan
} else {
    Write-Host "D1 target: local" -ForegroundColor DarkCyan
}

if ($RotateAccessJwtSecret) {
    $accessSecret = New-SecretValue
    Set-WranglerSecret -secretName "ACCESS_JWT_SECRET" -secretValue $accessSecret
}

if ($RotateRefreshHashSecret) {
    $refreshSecret = New-SecretValue
    Set-WranglerSecret -secretName "REFRESH_HASH_SECRET" -secretValue $refreshSecret
}

if ($RevokeAllRefreshTokens) {
    Execute-D1 -label "Revoking all refresh tokens" -sql "UPDATE refresh_tokens SET revoked = 1, replaced_by = CASE WHEN replaced_by IS NULL OR replaced_by = '' THEN '$incidentTag' ELSE replaced_by END WHERE revoked = 0;"
}

if ($RevokeAllDevices) {
    Execute-D1 -label "Revoking all registered devices" -sql "UPDATE beta_devices SET revoked = 1 WHERE revoked = 0;"
}

if ($RevokeAllInvites) {
    Execute-D1 -label "Revoking all invite codes" -sql "UPDATE beta_invites SET revoked = 1 WHERE revoked = 0;"
}

if ($DeployAfter) {
    if ($DryRun) {
        Write-Host "[DryRun] wrangler deploy" -ForegroundColor Yellow
    } else {
        Write-Step "Deploying Worker"
        Invoke-Wrangler -CommandArgs @("deploy")
    }
}

Write-Step "Emergency lockout complete"
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - Database: $DatabaseName"
Write-Host "  - Incident tag: $incidentTag"
Write-Host "  - ACCESS_JWT_SECRET rotated: $RotateAccessJwtSecret"
Write-Host "  - REFRESH_HASH_SECRET rotated: $RotateRefreshHashSecret"
Write-Host "  - Refresh tokens revoked: $RevokeAllRefreshTokens"
Write-Host "  - Devices revoked: $RevokeAllDevices"
Write-Host "  - Invites revoked: $RevokeAllInvites"

if (-not $DryRun) {
    Write-Host "Next recommended actions:" -ForegroundColor Yellow
    Write-Host "  1) If not deployed above, run: wrangler deploy"
    Write-Host "  2) Invalidate/rotate any leaked invite codes"
    Write-Host "  3) Re-issue access by creating new invite(s)"
}
