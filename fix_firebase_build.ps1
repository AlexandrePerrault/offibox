# Script pour corriger l'erreur "ZIP decompression failed (-5)" et firebase_firestore.lib manquant
# Le SDK Firebase C++ n'a pas ete correctement extrait par CMake (bug connu sur Windows)

$ErrorActionPreference = "Stop"
$projectRoot = (Get-Item $PSScriptRoot).FullName
$firebaseSdkVersion = "12.7.0"
$firebaseZipUrl = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_$firebaseSdkVersion.zip"

Write-Host "=== Correction build Firebase Windows ===" -ForegroundColor Cyan

# 1. Supprimer le dossier build pour forcer une extraction propre
$buildDir = Join-Path $projectRoot "build\windows\x64"
$extractedDir = Join-Path $buildDir "extracted"
$sdkTargetDir = Join-Path $extractedDir "firebase_cpp_sdk_windows"

if (Test-Path $buildDir) {
    Write-Host "`n>>> Suppression du dossier build\windows\x64" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
    Write-Host "OK" -ForegroundColor Green
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

# 4. Premiere tentative : flutter build windows (declenche le telechargement)
Write-Host "`n>>> flutter build windows (1ere tentative)" -ForegroundColor Yellow
$buildOutput = flutter build windows 2>&1
$buildSuccess = $LASTEXITCODE -eq 0

# 5. Si erreur "ZIP decompression failed (-5)", telecharger et extraire manuellement
if (-not $buildSuccess -and $buildOutput -match "ZIP decompression failed") {
    Write-Host "`n>>> Erreur ZIP detectee - Telechargement manuel du SDK Firebase" -ForegroundColor Yellow
    
    # Creer les dossiers (le premier build peut avoir echoue avant de les creer)
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    if (Test-Path $extractedDir) { Remove-Item -Recurse -Force $extractedDir }
    New-Item -ItemType Directory -Path $extractedDir -Force | Out-Null
    
    $zipPath = Join-Path $env:TEMP "firebase_cpp_sdk_windows_$firebaseSdkVersion.zip"
    
    Write-Host "Telechargement depuis $firebaseZipUrl ..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $firebaseZipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Host "Erreur telechargement: $_" -ForegroundColor Red
        Write-Host "Telechargez manuellement: $firebaseZipUrl" -ForegroundColor Gray
        Write-Host "Puis extrayez dans: $extractedDir" -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "Extraction avec Expand-Archive..." -ForegroundColor Gray
    Expand-Archive -Path $zipPath -DestinationPath $extractedDir -Force
    
    # Verifier que firebase_cpp_sdk_windows existe (le ZIP peut avoir un sous-dossier)
    $extractedContent = Get-ChildItem $extractedDir
    if ($extractedContent.Count -eq 1 -and $extractedContent[0].Name -eq "firebase_cpp_sdk_windows") {
        Write-Host "SDK extrait correctement" -ForegroundColor Green
    } elseif (-not (Test-Path $sdkTargetDir)) {
        # Le ZIP peut extraire directement firebase_cpp_sdk_windows
        $possibleSdk = Get-ChildItem $extractedDir -Directory | Where-Object { $_.Name -like "*firebase*" } | Select-Object -First 1
        if ($possibleSdk) {
            Rename-Item $possibleSdk.FullName "firebase_cpp_sdk_windows"
        }
    }
    
    if (-not (Test-Path (Join-Path $sdkTargetDir "CMakeLists.txt"))) {
        Write-Host "Erreur: CMakeLists.txt non trouve dans $sdkTargetDir" -ForegroundColor Red
        exit 1
    }
    
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    Write-Host ">>> Relance du build..." -ForegroundColor Yellow
    flutter build windows
    if ($LASTEXITCODE -ne 0) { exit 1 }
} elseif (-not $buildSuccess) {
    Write-Host "`n$buildOutput" -ForegroundColor Red
    Write-Host "`nSi l'erreur persiste, essayez :" -ForegroundColor Cyan
    Write-Host "  1. Mettre a jour Visual Studio (Build Tools 2022 avec C++)" -ForegroundColor Gray
    Write-Host "  2. flutter pub cache clean" -ForegroundColor Gray
    Write-Host "  3. Desactiver temporairement l'antivirus pendant le build" -ForegroundColor Gray
    Write-Host "  4. Telecharger manuellement : $firebaseZipUrl" -ForegroundColor Gray
    Write-Host "     Puis extraire dans build\windows\x64\extracted\" -ForegroundColor Gray
    exit 1
}

Write-Host "`nBuild reussi !" -ForegroundColor Green
