# Incrémente la version dans pubspec.yaml :
# 1.0.11 -> 1.0.12 -> ... -> 1.0.100 -> 1.2.0 -> 1.2.1 -> ...
# À lancer avant chaque build (ou en pré-release).

$ErrorActionPreference = 'Stop'
$pubspecPath = Join-Path $PSScriptRoot '..' 'pubspec.yaml'
$content = Get-Content $pubspecPath -Raw

if (-not ($content -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)')) {
  Write-Error "Impossible de trouver version dans pubspec.yaml"
  exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

# Règle : 1.0.11 .. 1.0.99 -> +1 patch ; 1.0.100 -> 1.2.0 ; 1.2.x -> +1 patch
if ($patch -eq 100) {
  $major = 1
  $minor = 2
  $patch = 0
  $build++
} else {
  $patch++
  $build++
}

$newVersion = "${major}.${minor}.${patch}+${build}"
$content = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
Set-Content $pubspecPath -Value $content -NoNewline

Write-Host "Version mise à jour : $newVersion"
