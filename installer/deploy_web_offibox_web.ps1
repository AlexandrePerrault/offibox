# Build Flutter web pour le depot offibox-web et (optionnel) copie vers un clone pour push.
# Usage:
#   .\deploy_web_offibox_web.ps1
#   .\deploy_web_offibox_web.ps1 -PushTo "C:\path\to\offibox-web"
#   .\deploy_web_offibox_web.ps1 -PushTo "C:\path\to\offibox-web" -DoGitPush
#
# Base href pour GitHub Pages offibox-web : https://<owner>.github.io/offibox-web/

param(
    [string]$PushTo = "",   # Dossier clone du depot offibox-web (vide = build seulement)
    [switch]$DoGitPush      # Si -PushTo est renseigne, fait git add, commit, push
)

$ErrorActionPreference = "Stop"
# Racine projet = dossier parent de 'installer' (contient pubspec.yaml)
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $projectRoot "pubspec.yaml"))) {
    Write-Host "Erreur: pubspec.yaml introuvable (racine projet: $projectRoot)"
    exit 1
}

Set-Location $projectRoot

$baseHref = "/offibox-web/"
Write-Host "Build web (base-href: $baseHref)..."
flutter build web -t lib/main_web.dart --base-href $baseHref --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Copier pages HTML et website comme dans pages.yml (optionnel pour offibox-web)
$buildWeb = Join-Path $projectRoot "build\web"
if (Test-Path (Join-Path $projectRoot "website\pages\html")) {
    Write-Host "Copy website/pages/html -> build/web/html"
    Copy-Item -Path (Join-Path $projectRoot "website\pages\html") -Destination (Join-Path $buildWeb "html") -Recurse -Force
}
if (Test-Path (Join-Path $projectRoot "website")) {
    Write-Host "Copy website -> build/web/website"
    Copy-Item -Path (Join-Path $projectRoot "website") -Destination (Join-Path $buildWeb "website") -Recurse -Force
}

Write-Host "Build web OK: $buildWeb"

if (-not $PushTo) {
    Write-Host "Pour pousser vers le depot offibox-web, relancez avec -PushTo <chemin clone offibox-web>"
    exit 0
}

if (-not (Test-Path $PushTo)) {
    Write-Host "Erreur: dossier introuvable: $PushTo"
    exit 1
}

# Copier le contenu de build/web dans le clone (remplacer tout sauf .git)
Write-Host "Copie vers $PushTo..."
Get-ChildItem -Path $buildWeb -Force | ForEach-Object {
    $dest = Join-Path $PushTo $_.Name
    if ($_.Name -eq ".git") { return }
    if (Test-Path $dest) {
        if ($_.PSIsContainer) { Remove-Item $dest -Recurse -Force }
        else { Remove-Item $dest -Force }
    }
    if ($_.PSIsContainer) { Copy-Item $_.FullName -Destination $dest -Recurse -Force }
    else { Copy-Item $_.FullName -Destination $dest -Force }
}

if (-not $DoGitPush) {
    Write-Host "Copie terminee. Pour commit + push: cd $PushTo puis git add . ; git commit -m \"Deploy web (build)\" ; git push origin main"
    exit 0
}

Set-Location $PushTo
git add .
$status = git status --short
if (-not $status) {
    Write-Host "Aucun changement a committer."
    exit 0
}
git commit -m "Deploy web (build avec base-href /offibox-web/)"
git push origin main
Write-Host "Push vers offibox-web OK."
