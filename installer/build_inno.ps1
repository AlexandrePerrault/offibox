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

# Lire et incrémenter la version depuis pubspec.yaml (source unique)
$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml introuvable à la racine du projet : $pubspecPath"
}

$pubspecContent = Get-Content $pubspecPath -Raw
$versionRegex = '^\s*version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)([^\s#]*)'
$versionMatch = [regex]::Match(
    $pubspecContent,
    $versionRegex,
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)
if (-not $versionMatch.Success) {
    Write-Error "Impossible de lire la version dans pubspec.yaml (ligne 'version: X.Y.Z')."
}

$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value
$suffix = $versionMatch.Groups[4].Value

$oldVersion = "$major.$minor.$patch$suffix"
$newPatch = $patch + 1
$AppVersion = "$major.$minor.$newPatch$suffix"

Write-Host "Ancienne version (pubspec.yaml) : $oldVersion" -ForegroundColor Yellow
Write-Host "Nouvelle version (pubspec.yaml) : $AppVersion" -ForegroundColor Cyan

# Mettre à jour pubspec.yaml avec la nouvelle version
$newContent = [regex]::Replace(
    $pubspecContent,
    $versionRegex,
    "version: $AppVersion",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)
Set-Content -Path $pubspecPath -Value $newContent -Encoding UTF8

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
