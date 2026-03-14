# Génère le setup Windows (Offibox-Setup-X.Y.Z.exe) dans website\download\
# Utilise la version actuelle de pubspec.yaml (sans l'incrémenter).
# Prérequis : Flutter, Inno Setup 6 (https://jrsoftware.org/isinfo.php)
#
# Usage :
#   .\build_setup.ps1           # Build Flutter + Inno Setup
#   .\build_setup.ps1 -SkipFlutter   # Inno Setup seulement (build Release déjà fait)

param(
    [switch]$SkipFlutter
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

if (-not $SkipFlutter) {
    Write-Host "Build Flutter Windows..." -ForegroundColor Cyan
    Set-Location $ProjectRoot
    flutter build windows
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows a échoué." }
} else {
    Write-Host "Skip Flutter build (dossier Release doit déjà exister)." -ForegroundColor Yellow
}

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Le dossier Release n'existe pas : $ReleaseDir. Lancez d'abord : flutter build windows"
}

$iscc = $null
foreach ($p in @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)) {
    if (Test-Path $p) { $iscc = $p; break }
}
if (-not $iscc) {
    Write-Error "Inno Setup 6 (ISCC.exe) introuvable. Installez-le depuis https://jrsoftware.org/isinfo.php"
}

$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml introuvable : $pubspecPath"
}

$pubspecContent = Get-Content $pubspecPath -Raw
$versionMatch = [regex]::Match(
    $pubspecContent,
    '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+[^\s#]*)',
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)
if (-not $versionMatch.Success) {
    Write-Error "Impossible de lire la version dans pubspec.yaml (ligne 'version: X.Y.Z')."
}
$AppVersion = $versionMatch.Groups[1].Value.Trim()

Write-Host "Version : $AppVersion" -ForegroundColor Cyan

$outDir = Join-Path $ProjectRoot "website\download"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

Write-Host "Compilation Inno Setup : installer\Offibox.iss" -ForegroundColor Cyan
$installerDir = Join-Path $ProjectRoot "installer"
Set-Location $installerDir
try {
    & $iscc "/DMyAppVersion=$AppVersion" "Offibox.iss"
    if ($LASTEXITCODE -ne 0) { throw "ISCC a échoué." }
    $exePath = Join-Path $ProjectRoot "website\download\Offibox-Setup-$AppVersion.exe"
    if (Test-Path $exePath) {
        Write-Host "OK : $exePath" -ForegroundColor Green
        Write-Host "Vous pouvez copier ce fichier sur un autre PC pour l'installation." -ForegroundColor Gray
    }
} finally {
    Set-Location $ProjectRoot
}
