# =================================================
# Local Build Script - Nexus.ahk
# =================================================

# --- CONFIGURATION ---
$appName        = "GameManagerLite"
$inputScript    = "Nexus.ahk"  # <--- CHANGED
$compilerPath   = "ahk\Compiler\Ahk2Exe.exe"
$baseFile       = "ahk\Compiler\Unicode-64-bit.bin"
$iconPath       = "media\nexus.ico"
$distFolder     = "dist"

$includeFolders = @("media", "core")
$includeFiles   = @("README.txt", "LICENSE", "nexus.ini")

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

$args = "/in `"$inputScript`" /out `"$distFolder\temp\$exeName`" /icon `"$iconPath`" /base `"$baseFile`""
$proc = Start-Process -FilePath $compilerPath -ArgumentList $args -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0) {
    Write-Error "Compilation Failed!"
    exit 1
}

# 3. PACKAGING
Write-Host ":: Copying Dependencies..." -ForegroundColor Yellow

foreach ($folder in $includeFolders) {
    if (Test-Path $folder) { Copy-Item $folder -Destination "$distFolder\temp" -Recurse -Force }
}

foreach ($file in $includeFiles) {
    if (Test-Path $file) { Copy-Item $file -Destination "$distFolder\temp" -Force }
}

# 4. ZIP
Write-Host ":: Zipping..." -ForegroundColor Yellow
$zipSource = "$distFolder\temp\*"
$zipDest   = "$distFolder\$zipName"
Compress-Archive -Path $zipSource -DestinationPath $zipDest -Force

# 5. FINALIZE
Move-Item "$distFolder\temp\$exeName" "$distFolder\$appName-$version.exe"
Remove-Item "$distFolder\temp" -Recurse -Force

Write-Host ":: BUILD SUCCESS!" -ForegroundColor Green
Write-Host "   EXE: $distFolder\$appName-$version.exe"
Write-Host "   ZIP: $zipDest"
Invoke-Item $distFolder