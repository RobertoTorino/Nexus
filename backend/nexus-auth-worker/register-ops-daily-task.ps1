param(
    [string]$TaskName = "NexusAuthDailyOps",
    [string]$DailyTime = "09:00",
    [string]$DatabaseName = "nexus-beta",
    [string]$ExportPath,
    [string]$SummaryPath,
    [switch]$SkipExport,
    [switch]$Local,
    [switch]$Remove,
    [switch]$RunNow
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

function Build-QuotedArg([string]$value) {
    $escaped = $value.Replace('"', '""')
    return '"' + $escaped + '"'
}

function Remove-TaskIfExists([string]$name) {
    $existing = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "Removed task: $name" -ForegroundColor Yellow
    } else {
        Write-Host "Task not found: $name" -ForegroundColor Yellow
    }
}

Assert-Command "powershell"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$opsScript = Join-Path $root "ops-daily.ps1"
if (-not (Test-Path $opsScript)) {
    throw "Required script not found: $opsScript"
}

if ($Remove) {
    Write-Step "Removing scheduled task if present"
    Remove-TaskIfExists -name $TaskName
    return
}

$null = [DateTime]::ParseExact($DailyTime, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)

Write-Step "Building scheduled task action"
$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Build-QuotedArg $opsScript),
    "-DatabaseName", (Build-QuotedArg $DatabaseName)
)

if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
    $argList += @("-ExportPath", (Build-QuotedArg $ExportPath))
}

if (-not [string]::IsNullOrWhiteSpace($SummaryPath)) {
    $argList += @("-SummaryPath", (Build-QuotedArg $SummaryPath))
}

if ($SkipExport) {
    $argList += "-SkipExport"
}

if (-not $Local) {
    $argList += "-Remote"
}

$arguments = $argList -join " "

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Daily -At $DailyTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Write-Step "Registering scheduled task '$TaskName'"
Remove-TaskIfExists -name $TaskName
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

Write-Host "Registered task: $TaskName" -ForegroundColor Green
Write-Host "Daily time: $DailyTime"
Write-Host "D1 target: $(if ($Local) { 'local' } else { 'remote' })"
Write-Host "Command: powershell.exe $arguments"

if ($RunNow) {
    Write-Step "Starting task now"
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task started: $TaskName" -ForegroundColor Green
}

Write-Step "Done"
Write-Host "Use this to remove later:" -ForegroundColor Yellow
Write-Host "  ./register-ops-daily-task.ps1 -TaskName $TaskName -Remove"
