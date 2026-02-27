# Corrige l'avertissement CMake du SDK Firebase C++ (cmake_minimum_required 3.1).
# À lancer après "flutter clean" ou si l'avertissement réapparaît.
# Usage: .\patch_firebase_cmake.ps1 (depuis la racine du projet)

$cmakePath = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"
if (-not (Test-Path $cmakePath)) {
  Write-Host "Fichier non trouvé: $cmakePath"
  Write-Host "Lancez d'abord: flutter build windows (ou flutter run -d windows)"
  exit 1
}
$content = Get-Content $cmakePath -Raw
$content = $content -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.10...3.30)'
Set-Content $cmakePath -Value $content -NoNewline
Write-Host "CMake Firebase patché: $cmakePath"
