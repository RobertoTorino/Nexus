param(
    [string]$DatabaseName = "nexus-beta",
    [string]$OutputPath,
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
            throw "Wrangler is not authenticated. Run 'wrangler login' in backend/nexus-auth-worker, then rerun export-active-invites.ps1."
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

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$script:WranglerCmd = Resolve-WranglerCommand -scriptRoot $root

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path $root "exports/active-invites-$timestamp.csv"
}

$outDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$sql = "SELECT code, max_uses, use_count, CASE WHEN max_uses > 0 THEN (max_uses - use_count) ELSE -1 END AS remaining_uses, CASE WHEN expires_at IS NULL OR expires_at = 0 THEN NULL ELSE datetime(expires_at, 'unixepoch') END AS expires_utc, datetime(created_at, 'unixepoch') AS created_utc, revoked FROM beta_invites WHERE revoked = 0 AND (expires_at IS NULL OR expires_at = 0 OR expires_at > strftime('%s','now')) AND (max_uses <= 0 OR use_count < max_uses) ORDER BY created_at DESC;"

Write-Step "Querying active invites from '$DatabaseName'"
$d1Args = @("d1", "execute", $DatabaseName, "--command", $sql, "--json")
if ($Remote) {
    $d1Args += "--remote"
}

$raw = Invoke-Wrangler -CommandArgs $d1Args | Out-String
$rows = Get-JsonResults -rawJson $raw

$records = @()
foreach ($row in $rows) {
    $remainingRaw = [int]$row.remaining_uses
    $remainingDisplay = if ($remainingRaw -lt 0) { "unlimited" } else { "$remainingRaw" }

    $records += [PSCustomObject]@{
        code = "$($row.code)"
        max_uses = [int]$row.max_uses
        use_count = [int]$row.use_count
        remaining_uses = $remainingDisplay
        expires_utc = if ($null -eq $row.expires_utc) { "" } else { "$($row.expires_utc)" }
        created_utc = "$($row.created_utc)"
    }
}

$records | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Step "Active invites"
if ($records.Count -eq 0) {
    Write-Host "No active invites found." -ForegroundColor Yellow
} else {
    $records | Format-Table -AutoSize
}

Write-Step "CSV exported"
Write-Host "Path: $OutputPath" -ForegroundColor Green
Write-Host "Count: $($records.Count)"
