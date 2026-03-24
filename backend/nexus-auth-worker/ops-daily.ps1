param(
    [string]$DatabaseName = "nexus-beta",
    [string]$ExportPath,
    [string]$SummaryPath,
    [switch]$SkipExport,
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

function Get-JsonResults($rawJson) {
    try {
        $parsed = $rawJson | ConvertFrom-Json
    } catch {
        if ($rawJson -match "not authenticated|wrangler login") {
            throw "Wrangler is not authenticated. Run 'wrangler login' in backend/nexus-auth-worker, then rerun ops-daily.ps1."
        }

        throw "Unable to parse wrangler JSON response. Raw output: $rawJson"
    }

    if ($parsed -is [System.Array]) {
        if ($parsed.Count -gt 0 -and $parsed[0].PSObject.Properties.Name -contains "results") {
            return @($parsed[0].results)
        }
    }

    if ($parsed.PSObject.Properties.Name -contains "results") {
        return @($parsed.results)
    }

    if ($parsed.PSObject.Properties.Name -contains "result") {
        if ($parsed.result -is [System.Array] -and $parsed.result.Count -gt 0) {
            $first = $parsed.result[0]
            if ($first.PSObject.Properties.Name -contains "results") {
                return @($first.results)
            }
        }
    }

    throw "Unable to parse wrangler JSON response."
}

function Get-ScalarCount([string]$sql) {
    $args = @("d1", "execute", $DatabaseName, "--command", $sql, "--json")
    if ($Remote) {
        $args += "--remote"
    }

    $raw = Invoke-Wrangler -CommandArgs $args | Out-String
    $rows = Get-JsonResults -rawJson $raw
    if ($rows.Count -eq 0) { return 0 }

    $row = $rows[0]
    if ($row.PSObject.Properties.Name -contains "value") {
        return [int]$row.value
    }

    $firstProp = $row.PSObject.Properties | Select-Object -First 1
    if ($null -eq $firstProp) { return 0 }
    return [int]$firstProp.Value
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$script:WranglerCmd = Resolve-WranglerCommand -scriptRoot $root

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($ExportPath)) {
    $ExportPath = Join-Path $root "exports/active-invites-daily-$timestamp.csv"
}
if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
    $SummaryPath = Join-Path $root "exports/ops-summary-$timestamp.json"
}

$summaryDir = Split-Path -Parent $SummaryPath
if (-not [string]::IsNullOrWhiteSpace($summaryDir) -and -not (Test-Path $summaryDir)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

$exportDir = Split-Path -Parent $ExportPath
if (-not [string]::IsNullOrWhiteSpace($exportDir) -and -not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

Write-Step "Collecting lockout status counts from '$DatabaseName'"
if ($Remote) {
    Write-Host "D1 target: remote" -ForegroundColor DarkCyan
} else {
    Write-Host "D1 target: local" -ForegroundColor DarkCyan
}

$activeInvites = Get-ScalarCount "SELECT COUNT(1) AS value FROM beta_invites WHERE revoked = 0 AND (expires_at IS NULL OR expires_at = 0 OR expires_at > strftime('%s','now')) AND (max_uses <= 0 OR use_count < max_uses);"
$revokedInvites = Get-ScalarCount "SELECT COUNT(1) AS value FROM beta_invites WHERE revoked = 1;"
$activeDevices = Get-ScalarCount "SELECT COUNT(1) AS value FROM beta_devices WHERE revoked = 0;"
$revokedDevices = Get-ScalarCount "SELECT COUNT(1) AS value FROM beta_devices WHERE revoked = 1;"
$activeRefreshTokens = Get-ScalarCount "SELECT COUNT(1) AS value FROM refresh_tokens WHERE revoked = 0 AND expires_at > strftime('%s','now');"
$revokedRefreshTokens = Get-ScalarCount "SELECT COUNT(1) AS value FROM refresh_tokens WHERE revoked = 1;"

$lockoutStatus = [PSCustomObject]@{
    invites_active = $activeInvites
    devices_active = $activeDevices
    refresh_tokens_active = $activeRefreshTokens
    fully_locked_down = (($activeInvites -eq 0) -and ($activeDevices -eq 0) -and ($activeRefreshTokens -eq 0))
}

Write-Step "Daily ops summary"
$table = @(
    [PSCustomObject]@{ metric = "active_invites"; value = $activeInvites }
    [PSCustomObject]@{ metric = "revoked_invites"; value = $revokedInvites }
    [PSCustomObject]@{ metric = "active_devices"; value = $activeDevices }
    [PSCustomObject]@{ metric = "revoked_devices"; value = $revokedDevices }
    [PSCustomObject]@{ metric = "active_refresh_tokens"; value = $activeRefreshTokens }
    [PSCustomObject]@{ metric = "revoked_refresh_tokens"; value = $revokedRefreshTokens }
    [PSCustomObject]@{ metric = "fully_locked_down"; value = $lockoutStatus.fully_locked_down }
)
$table | Format-Table -AutoSize

$inviteExportWritten = $false
if (-not $SkipExport) {
    Write-Step "Exporting active invites"
    $exportScript = Join-Path $root "export-active-invites.ps1"
    if (-not (Test-Path $exportScript)) {
        throw "Required script not found: $exportScript"
    }

    & $exportScript -DatabaseName $DatabaseName -OutputPath $ExportPath -Remote:$Remote
    $inviteExportWritten = $true
}

$summary = [PSCustomObject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    database = $DatabaseName
    d1_target = $(if ($Remote) { "remote" } else { "local" })
    lockout_status = $lockoutStatus
    counters = [PSCustomObject]@{
        active_invites = $activeInvites
        revoked_invites = $revokedInvites
        active_devices = $activeDevices
        revoked_devices = $revokedDevices
        active_refresh_tokens = $activeRefreshTokens
        revoked_refresh_tokens = $revokedRefreshTokens
    }
    active_invites_exported = $inviteExportWritten
    active_invites_export_path = $(if ($inviteExportWritten) { $ExportPath } else { "" })
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryPath -Encoding UTF8

Write-Step "Artifacts"
Write-Host "Summary JSON: $SummaryPath" -ForegroundColor Green
if ($inviteExportWritten) {
    Write-Host "Active invites CSV: $ExportPath" -ForegroundColor Green
} else {
    Write-Host "Active invites CSV: skipped" -ForegroundColor Yellow
}
