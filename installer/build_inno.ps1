# Build Inno Setup - Offibox
# 1) Optionnel : flutter build windows
# 2) Compile Offibox.iss avec ISCC (Inno Setup 6)
# Sortie : ..\website\download\Offibox-Setup-<version>.exe

param(
    [switch]$SkipFlutter   # Ne pas lancer flutter build windows
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

if (-not $SkipFlutter) {
    Write-Host "Build Flutter Windows..." -ForegroundColor Cyan
    Push-Location $ProjectRoot
    try {
        flutter build windows
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows a échoué." }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Skip Flutter build (dossier Release doit déjà exister)." -ForegroundColor Yellow
}

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Le dossier Release n'existe pas : $ReleaseDir. Lancez d'abord : flutter build windows"
}

$iscc = $null
$paths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)
foreach ($p in $paths) {
    if (Test-Path $p) { $iscc = $p; break }
}
if (-not $iscc) {
    Write-Error "Inno Setup 6 (ISCC.exe) introuvable. Installez-le depuis https://jrsoftware.org/isinfo.php"
}

# Lire la version depuis pubspec.yaml (source unique)
$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$versionLine = Get-Content $pubspecPath -Raw | Select-String -Pattern '^\s*version:\s*([^\s#]+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
if (-not $versionLine) {
    Write-Error "Impossible de lire la version dans pubspec.yaml"
}
$AppVersion = $versionLine
Write-Host "Version (pubspec.yaml) : $AppVersion" -ForegroundColor Cyan

Write-Host "Compilation Inno Setup : Offibox.iss" -ForegroundColor Cyan
Push-Location $PSScriptRoot
try {
    & $iscc "/DMyAppVersion=$AppVersion" "Offibox.iss"
    if ($LASTEXITCODE -ne 0) { throw "ISCC a échoué." }
    $outDir = Join-Path $ProjectRoot "website\download"
    $exe = Get-ChildItem -Path $outDir -Filter "Offibox-Setup-*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($exe) {
        Write-Host "OK : $($exe.FullName)" -ForegroundColor Green
    }
} finally {
    Pop-Location
}
