# Build PC (Windows + Inno Setup) et Web en une seule commande.
# Usage:
#   .\build_pc_and_web.ps1
#   .\build_pc_and_web.ps1 -SkipFlutter          # Ne pas refaire "flutter build windows" (Release deja a jour)
#   .\build_pc_and_web.ps1 -SkipPc              # Build web uniquement
#   .\build_pc_and_web.ps1 -SkipWeb             # Build PC (exe) uniquement
#   .\build_pc_and_web.ps1 -PushWebTo "C:\path\to\offibox-web" -DoGitPush   # + copie et push web
#
# Sorties:
#   PC  : website\download\Offibox-Setup-<version>.exe
#   Web : build\web\ (base-href /offibox-web/)

param(
    [switch]$SkipFlutter,   # Pour la partie PC : ne pas lancer "flutter build windows"
    [switch]$SkipPc,        # Ne pas faire le build PC (exe)
    [switch]$SkipWeb,        # Ne pas faire le build web
    [string]$PushWebTo = "", # Si renseigne, copie build/web vers ce dossier (clone offibox-web)
    [switch]$DoGitPush      # Avec -PushWebTo : git add, commit, push dans le clone
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir

Push-Location $projectRoot
try {

    if (-not $SkipPc) {
        Write-Host "`n========== Build PC (Windows + Inno Setup) ==========" -ForegroundColor Cyan
        & (Join-Path $scriptDir "build_inno.ps1") -SkipFlutter:$SkipFlutter
        if ($LASTEXITCODE -ne 0) { throw "Build PC (build_inno.ps1) a echoue." }
    }

    if (-not $SkipWeb) {
        Write-Host "`n========== Build Web ==========" -ForegroundColor Cyan
        $baseHref = "/offibox-web/"
        Write-Host "flutter build web (base-href: $baseHref)..."
        flutter build web -t lib/main_web.dart --base-href $baseHref --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build web a echoue." }

        $buildWeb = Join-Path $projectRoot "build\web"
        if (Test-Path (Join-Path $projectRoot "website\pages\html")) {
            Write-Host "Copy website/pages/html -> build/web/html"
            Copy-Item -Path (Join-Path $projectRoot "website\pages\html") -Destination (Join-Path $buildWeb "html") -Recurse -Force
        }
        if (Test-Path (Join-Path $projectRoot "website")) {
            Write-Host "Copy website -> build/web/website"
            Copy-Item -Path (Join-Path $projectRoot "website") -Destination (Join-Path $buildWeb "website") -Recurse -Force
        }
        Write-Host "Build web OK : $buildWeb" -ForegroundColor Green
    }

    if ($PushWebTo -and -not $SkipWeb) {
        if (-not (Test-Path $PushWebTo)) {
            Write-Host "Erreur: dossier introuvable: $PushWebTo" -ForegroundColor Red
            exit 1
        }
        $buildWeb = Join-Path $projectRoot "build\web"
        Write-Host "`n========== Copie vers offibox-web ==========" -ForegroundColor Cyan
        Get-ChildItem -Path $buildWeb -Force | ForEach-Object {
            if ($_.Name -eq ".git") { return }
            $dest = Join-Path $PushWebTo $_.Name
            if (Test-Path $dest) {
                if ($_.PSIsContainer) { Remove-Item $dest -Recurse -Force }
                else { Remove-Item $dest -Force }
            }
            if ($_.PSIsContainer) { Copy-Item $_.FullName -Destination $dest -Recurse -Force }
            else { Copy-Item $_.FullName -Destination $dest -Force }
        }
        Write-Host "Copie terminee : $PushWebTo" -ForegroundColor Green
        if ($DoGitPush) {
            Push-Location $PushWebTo
            try {
                git add .
                $status = git status --short
                if ($status) {
                    git commit -m "Deploy web (build avec base-href /offibox-web/)"
                    git push origin main
                    Write-Host "Push vers offibox-web OK." -ForegroundColor Green
                } else {
                    Write-Host "Aucun changement a committer." -ForegroundColor Yellow
                }
            } finally {
                Pop-Location
            }
        }
    }

    Write-Host "`n========== Termine ==========" -ForegroundColor Green
    if (-not $SkipPc) { Write-Host "PC  : website\download\Offibox-Setup-*.exe" }
    if (-not $SkipWeb) { Write-Host "Web : build\web\" }

} finally {
    Pop-Location
}
