# Incrémente la version à chaque build : 1.1.02 -> 1.1.03 (format X.Y.Z uniquement)
# Met à jour : pubspec.yaml, installer WiX, website, build_msi.ps1
# À lancer avant chaque build release : .\scripts\bump_version.ps1

$ErrorActionPreference = 'Stop'
$ProjectRoot = Join-Path $PSScriptRoot '..'
$PubspecPath = Join-Path $ProjectRoot 'pubspec.yaml'

$content = Get-Content $PubspecPath -Raw
# Accepte "version: 1.1.02" ou "version: 1.1.02+1" (on ignore +build)
if (-not ($content -match 'version:\s*(\d+)\.(\d+)\.(\d+)(?:\+\d+)?')) {
  Write-Error "Impossible de trouver version (X.Y.Z ou X.Y.Z+build) dans pubspec.yaml"
  exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]

$oldVersionName = "${major}.${minor}.$($patch.ToString('D2'))"
$newPatch = $patch + 1
$newVersionName = "${major}.${minor}.$($newPatch.ToString('D2'))"
$newVersion = $newVersionName

# 1) pubspec.yaml : on écrit uniquement X.Y.Z (sans +build)
$content = $content -replace 'version:\s*\d+\.\d+\.\d+(?:\+\d+)?', "version: $newVersion"
Set-Content $PubspecPath -Value $content -NoNewline

# 2) Fichiers à mettre à jour avec le nouveau numéro de version (nom seulement, ex. 1.1.03)
# Product.wxs.v3 : ligne 1 = déclaration XML (doit rester version="1.0"), puis remplacer Version="..." dans le reste.
$productWxs = Join-Path $ProjectRoot 'installer\wix\Product.wxs.v3'
if (Test-Path $productWxs) {
  $lines = Get-Content $productWxs -Encoding UTF8
  if ($lines.Count -gt 0) {
    $first = $lines[0] -replace 'Version="[^"]*"', 'version="1.0"'
    $first = $first -replace 'version="[^"]*"', 'version="1.0"'
    $lines[0] = $first
    $rest = $lines[1..($lines.Count - 1)] -join "`n"
    $rest = $rest -replace '(?<!Installer)Version="[^"]+"', "Version=`"$newVersionName`""
    $lines = @($lines[0]) + ($rest -split "`n")
    Set-Content $productWxs -Value $lines -Encoding UTF8
  }
}
$files = @(
  @{ Path = Join-Path $ProjectRoot 'installer\Package.wxs'; Pattern = 'Version="[^"]+"'; Replacement = "Version=`"$newVersionName`"" },
  @{ Path = Join-Path $ProjectRoot 'installer\Offibox.wixproj'; Pattern = 'Offibox-Setup\.\d+\.\d+\.\d+\.msi'; Replacement = "Offibox-Setup.$newVersionName.msi" },
  @{ Path = Join-Path $ProjectRoot 'website\index.html'; Pattern = 'Offibox-Setup-\d+\.\d+\.\d+\.msi'; Replacement = "Offibox-Setup-$newVersionName.msi" },
  @{ Path = Join-Path $ProjectRoot 'installer\README.md'; Pattern = 'Offibox-Setup-\d+\.\d+\.\d+\.msi'; Replacement = "Offibox-Setup-$newVersionName.msi" },
  @{ Path = Join-Path $ProjectRoot 'website\download\README.md'; Pattern = 'Offibox-Setup-\d+\.\d+\.\d+\.msi'; Replacement = "Offibox-Setup-$newVersionName.msi" }
)

foreach ($f in $files) {
  if (Test-Path $f.Path) {
    $text = Get-Content $f.Path -Raw
    $text = $text -replace $f.Pattern, $f.Replacement
    Set-Content $f.Path -Value $text -NoNewline
  }
}

# 3) build_msi.ps1 : fallback dans le script
$buildMsiPath = Join-Path $ProjectRoot 'build_msi.ps1'
$buildMsiContent = Get-Content $buildMsiPath -Raw
$buildMsiContent = $buildMsiContent -replace 'else \{ "[\d.]+" \}', "else { `"$newVersionName`" }"
Set-Content $buildMsiPath -Value $buildMsiContent -NoNewline

Write-Host "Version : $oldVersionName -> $newVersion" -ForegroundColor Green
Write-Host "Fichiers mis a jour : pubspec.yaml, installer, website, build_msi.ps1"
