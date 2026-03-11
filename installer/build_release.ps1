# Build Offibox Setup (.exe) - a lancer dans PowerShell
# Clic-droit sur ce fichier -> "Executer avec PowerShell"
# OU dans PowerShell : cd installer puis .\build_release.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Set-Location $ProjectRoot
Write-Host "Projet: $ProjectRoot" -ForegroundColor Cyan

# Build Flutter + Inno Setup
& "$PSScriptRoot\build_inno.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur build." -ForegroundColor Red
    exit 1
}

$exe = Get-ChildItem -Path "$ProjectRoot\website\download" -Filter "Offibox-Setup-*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($exe) {
    Write-Host "OK - Fichier cree: $($exe.FullName)" -ForegroundColor Green
} else {
    Write-Host "Aucun .exe trouve dans website\download" -ForegroundColor Red
    exit 1
}
