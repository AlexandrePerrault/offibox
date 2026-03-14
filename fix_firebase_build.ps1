# Script pour corriger l'erreur "ZIP decompression failed (-5)" et firebase_firestore.lib manquant
# Le SDK Firebase C++ n'a pas ete correctement extrait par CMake (bug connu sur Windows)

$ErrorActionPreference = "Stop"
$projectRoot = (Get-Item $PSScriptRoot).FullName
# Version et URL officielles (GitHub Releases) : pas de "_windows" dans le nom du zip
$firebaseSdkVersion = "12.7.0"
$firebaseZipUrl = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_$firebaseSdkVersion.zip"

# S'assure que extracted contient un dossier nomme exactement "firebase_cpp_sdk_windows" (attendu par le plugin Flutter)
function _EnsureFirebaseSdkFolderName {
    param([string]$extractedDir, [string]$sdkTargetDir)
    $sdkCmakePath = Join-Path $sdkTargetDir "CMakeLists.txt"
    if (Test-Path $sdkCmakePath) { return }
    $dirs = Get-ChildItem -Path $extractedDir -Directory -ErrorAction SilentlyContinue
    if (-not $dirs) { return }
    $toRename = $null
    foreach ($d in $dirs) {
        if ($d.Name -eq "firebase_cpp_sdk_windows") { return }
        $cmakeInDir = Join-Path $d.FullName "CMakeLists.txt"
        if (Test-Path $cmakeInDir) { $toRename = $d; break }
        if ($d.Name -like "*firebase*" -and -not $toRename) { $toRename = $d }
    }
    if ($toRename) {
        Rename-Item -Path $toRename.FullName -NewName "firebase_cpp_sdk_windows"
        Write-Host "Dossier renomme en firebase_cpp_sdk_windows : $($toRename.Name)" -ForegroundColor Green
    }
}

Write-Host "=== Correction build Firebase Windows ===" -ForegroundColor Cyan
Write-Host "Astuce: fermez Cursor/VS Code et tout 'flutter build' en cours pour eviter 'fichier en cours d''utilisation'." -ForegroundColor DarkGray
Write-Host ""

# 1. Chemins
$buildDir = Join-Path $projectRoot "build\windows\x64"
$extractedDir = Join-Path $buildDir "extracted"
$sdkTargetDir = Join-Path $extractedDir "firebase_cpp_sdk_windows"

# 1b. Si tu as deja extrait le zip a la main : on corrige le nom du dossier (doit etre firebase_cpp_sdk_windows)
if ((Test-Path $extractedDir) -and -not (Test-Path (Join-Path $sdkTargetDir "CMakeLists.txt"))) {
    _EnsureFirebaseSdkFolderName -extractedDir $extractedDir -sdkTargetDir $sdkTargetDir
    if (Test-Path (Join-Path $sdkTargetDir "CMakeLists.txt")) {
        Write-Host ">>> Dossier SDK deja present, nom corrige. Lancement du build." -ForegroundColor Green
        Set-Location $projectRoot
        flutter build windows
        if ($LASTEXITCODE -eq 0) { Write-Host "`nBuild reussi !" -ForegroundColor Green } else { exit 1 }
        exit 0
    }
}

# 2. Supprimer uniquement le dossier extracted (SDK Firebase) pour eviter "fichier en cours d'utilisation"
if (Test-Path $extractedDir) {
    Write-Host "`n>>> Suppression du dossier extracted (SDK Firebase)" -ForegroundColor Yellow
    try {
        Remove-Item -Recurse -Force $extractedDir -ErrorAction Stop
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "Impossible de supprimer (fichier en cours d'utilisation)." -ForegroundColor Red
        Write-Host "Fermez Cursor, Visual Studio, et tout terminal 'flutter build', puis:" -ForegroundColor Yellow
        Write-Host "  1. Supprimez a la main le dossier: build\windows\x64\extracted" -ForegroundColor Gray
        Write-Host "  2. Relancez ce script." -ForegroundColor Gray
        exit 1
    }
}

# 2. flutter clean
Write-Host "`n>>> flutter clean" -ForegroundColor Yellow
Set-Location $projectRoot
flutter clean
if ($LASTEXITCODE -ne 0) { exit 1 }

# 3. flutter pub get
Write-Host "`n>>> flutter pub get" -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { exit 1 }

# 4. Pre-remplir le SDK Firebase AVANT le premier build (evite ZIP decompression failed -5)
$sdkCmakePath = Join-Path $sdkTargetDir "CMakeLists.txt"
$needExtract = -not (Test-Path $sdkCmakePath)
if ($needExtract) {
    Write-Host "`n>>> Telechargement et extraction du SDK Firebase C++ (avant build)" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    if (Test-Path $extractedDir) {
        try { Remove-Item -Recurse -Force $extractedDir -ErrorAction Stop } catch { }
    }
    New-Item -ItemType Directory -Path $extractedDir -Force | Out-Null
    $zipPath = Join-Path $env:TEMP "firebase_cpp_sdk_$firebaseSdkVersion.zip"
    Write-Host "Telechargement depuis $firebaseZipUrl ..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $firebaseZipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Host "Erreur telechargement: $_" -ForegroundColor Red
        Write-Host "Telechargez manuellement: $firebaseZipUrl" -ForegroundColor Gray
        Write-Host "Puis extrayez le contenu dans: $extractedDir" -ForegroundColor Gray
        exit 1
    }
    Write-Host "Extraction avec Expand-Archive..." -ForegroundColor Gray
    Expand-Archive -Path $zipPath -DestinationPath $extractedDir -Force
    # Le zip officiel extrait souvent un dossier "firebase_cpp_sdk" : CMake attend "firebase_cpp_sdk_windows"
    _EnsureFirebaseSdkFolderName -extractedDir $extractedDir -sdkTargetDir $sdkTargetDir
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    if (-not (Test-Path $sdkCmakePath)) {
        Write-Host "Erreur: CMakeLists.txt non trouve dans $sdkTargetDir" -ForegroundColor Red
        exit 1
    }
    Write-Host "SDK Firebase pret." -ForegroundColor Green
}

# 5. flutter build windows
Write-Host "`n>>> flutter build windows" -ForegroundColor Yellow
flutter build windows
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBuild echoue. Si l'erreur est toujours ZIP decompression failed:" -ForegroundColor Red
    Write-Host "  1. Fermez Cursor/VS Code et tout terminal, supprimez build\windows\x64\extracted a la main" -ForegroundColor Gray
    Write-Host "  2. Relancez ce script." -ForegroundColor Gray
    Write-Host "  3. Ou telechargez manuellement: $firebaseZipUrl" -ForegroundColor Gray
    Write-Host "     Puis extrayez dans build\windows\x64\extracted\" -ForegroundColor Gray
    exit 1
}

Write-Host "`nBuild reussi !" -ForegroundColor Green
