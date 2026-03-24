# =================================================
# Local Build Script - Nexus.ahk
# =================================================

# --- CONFIGURATION ---
$ErrorActionPreference = "Stop"

$appName        = "Nexus"
$inputScript    = "Nexus.ahk"
$compilerPath   = "ahk_v2\Compiler\Ahk2Exe.exe"
$baseFile       = "ahk_v2\v2\AutoHotkey64.exe"
$iconPath       = "game-configs\artwork\nexus.ico"
$distFolder     = "dist"

$includeFolders = @("core", "game-configs", "data", "tools", "music", "media")
$includeFiles   = @("LICENSE", "README.md", "readme.txt", "nexus.json", "nexus.db", "sqlite3.dll", "_verify-nexus.ps1")
$templateIni    = "nexus.template.ini"
$mediaCleanDirs = @("media\captures", "media\snapshots", "game-configs\artwork")


# --- SETUP ---
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$version   = "local-$timestamp"
$exeName   = "$appName.exe"
$zipName   = "$appName-$version.zip"

Write-Host ":: Starting Build for $appName ($version)..." -ForegroundColor Cyan

# 1. CLEANUP
if (Test-Path $distFolder) { Remove-Item $distFolder -Recurse -Force }
New-Item -ItemType Directory -Path "$distFolder\temp" | Out-Null

# 2. COMPILE
Write-Host ":: Compiling $inputScript..." -ForegroundColor Yellow
if (-not (Test-Path $inputScript)) { Write-Error "Source file $inputScript not found!"; exit 1 }

$argus = "/in `"$inputScript`" /out `"$distFolder\temp\$exeName`" /icon `"$iconPath`" /base `"$baseFile`""
$proc = Start-Process -FilePath $compilerPath -ArgumentList $argus -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0) {
    Write-Error "Compilation Failed!"
    exit 1
}

# HASH
Write-Host ":: Generating SHA256 hash..." -ForegroundColor Yellow
$hash     = (Get-FileHash "$distFolder\temp\$exeName" -Algorithm SHA256).Hash.ToUpper()
$hashLine = "$hash  $exeName"
Set-Content -Path "$distFolder\temp\Nexus.sha256" -Value $hashLine -Encoding UTF8
Write-Host ":: SHA256: $hash" -ForegroundColor DarkGray

# 3. PACKAGING
Write-Host ":: Copying Dependencies..." -ForegroundColor Yellow

foreach ($folder in $includeFolders) {
    if (Test-Path $folder) { Copy-Item $folder -Destination "$distFolder\temp" -Recurse -Force }
}

# Strip user-specific media folders and blank the game library
foreach ($dir in $mediaCleanDirs) {
    $target = "$distFolder\temp\$dir"
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
}

foreach ($file in $includeFiles) {
    if (Test-Path $file) { Copy-Item $file -Destination "$distFolder\temp" -Force }
}
Set-Content -Path "$distFolder\temp\nexus.json" -Value "{}" -Encoding UTF8
Copy-Item $templateIni -Destination "$distFolder\temp\nexus.ini" -Force

# 4. ZIP
Write-Host ":: Zipping..." -ForegroundColor Yellow
$zipSource = "$distFolder\temp\*"
$zipDest   = "$distFolder\$zipName"
Compress-Archive -Path $zipSource -DestinationPath $zipDest -Force

# 5. FINALIZE
Move-Item "$distFolder\temp\$exeName" "$distFolder\$appName-$version.exe"
Remove-Item "$distFolder\temp" -Recurse -Force

# Save hash alongside the standalone EXE
Set-Content -Path "$distFolder\Nexus.sha256" -Value $hashLine -Encoding UTF8

# Copy dependencies alongside the standalone EXE so it runs in-place
Write-Host ":: Copying Dependencies alongside EXE..." -ForegroundColor Yellow

foreach ($folder in $includeFolders) {
    if (Test-Path $folder) { Copy-Item $folder -Destination $distFolder -Recurse -Force }
}

# Strip user-specific media folders and blank the game library
foreach ($dir in $mediaCleanDirs) {
    $target = "$distFolder\$dir"
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
}

foreach ($file in $includeFiles) {
    if (Test-Path $file) { Copy-Item $file -Destination $distFolder -Force }
}
Set-Content -Path "$distFolder\nexus.json" -Value "{}" -Encoding UTF8
Copy-Item $templateIni -Destination "$distFolder\nexus.ini" -Force
Copy-Item "$distFolder\Nexus.sha256" -Destination "$distFolder" -Force

Write-Host ":: BUILD SUCCESS!" -ForegroundColor Green
Write-Host "   EXE: $distFolder\$appName-$version.exe"
Write-Host "   SHA: $distFolder\Nexus.sha256"
Write-Host "   ZIP: $zipDest"
Invoke-Item $distFolder