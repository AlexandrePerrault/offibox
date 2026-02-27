# Build MSI Offibox après "flutter build windows"
# Nécessite : WiX Toolset v3 (https://wixtoolset.org/)
# Exécuter depuis la racine du projet : .\build_msi.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$WixDir   = Join-Path $ProjectRoot "installer\wix"
$OutDir   = Join-Path $ProjectRoot "website\download"
$OutMsi   = Join-Path $OutDir "Offibox-Setup-1.0.11.msi"

# WiX : variable d'environnement WIX ou chemin par défaut
$WixBin = $env:WIX
if (-not $WixBin) {
    $WixBin = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
    if (-not (Test-Path $WixBin)) { $WixBin = "C:\Program Files (x86)\WiX Toolset v3.11\bin" }
}
if (-not (Test-Path $WixBin)) {
    Write-Host "WiX Toolset non trouvé. Installez-le depuis https://wixtoolset.org/ ou définissez la variable WIX." -ForegroundColor Red
    exit 1
}

$Heat = Join-Path $WixBin "heat.exe"
$Candle = Join-Path $WixBin "candle.exe"
$Light  = Join-Path $WixBin "light.exe"

if (-not (Test-Path $ReleaseDir)) {
    Write-Host "Dossier Release introuvable. Lancez d'abord : flutter build windows" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 1) Harvest du dossier Release
$HarvestWxs = Join-Path $WixDir "Harvest.wxs"
Write-Host "Harvest $ReleaseDir -> $HarvestWxs"
& $Heat dir $ReleaseDir -dr INSTALLDIR -ke -srd -cg ReleaseFiles -gg -out $HarvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 2) Compilation
Write-Host "Compilation WiX..."
Push-Location $WixDir
& $Candle Product.wxs.v3 Harvest.wxs -ext WixUIExtension -out .
Pop-Location
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 3) Lien -> MSI
$ProductObj = Join-Path $WixDir "Product.wxs.v3.wixobj"
$HarvestObj = Join-Path $WixDir "Harvest.wixobj"
Write-Host "Lien -> $OutMsi"
& $Light -out $OutMsi $ProductObj $HarvestObj -ext WixUIExtension -sval
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "MSI cree : $OutMsi" -ForegroundColor Green
