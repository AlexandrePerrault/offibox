# Build PC (Windows + Inno), Build Web, envoi du build (dont HTML) vers offibox-web, puis affichage de toutes les URLs.
#
# Usage (build + envoi + URLs) :
#   .\push_build_web_pc_and_urls.ps1 -PushWebTo "C:\path\to\offibox-web" -DoGitPush
#
# Usage (build seulement, puis afficher les URLs avec une base connue) :
#   .\push_build_web_pc_and_urls.ps1 -GitHubPagesBase "https://alexandreperrault.github.io/offibox-web"
#
# Optionnel :
#   -SkipFlutter  : ne pas refaire "flutter build windows" (Release deja a jour)
#   -SkipPc       : ne pas faire le build PC (exe)
#   -SkipWeb      : ne pas faire le build web ni l'envoi
#   -GitHubPagesBase : URL de base GitHub Pages si pas de -PushWebTo (ex: https://alexandreperrault.github.io/offibox-web)

param(
    [string]$PushWebTo = "",         # Dossier clone du depot offibox-web (pour envoi build + html). Vide = pas d'envoi.
    [switch]$DoGitPush,              # Avec -PushWebTo : git add, commit, push dans le clone
    [switch]$SkipFlutter,
    [switch]$SkipPc,
    [switch]$SkipWeb,
    [string]$GitHubPagesBase = ""    # Ex: https://alexandreperrault.github.io/offibox-web (pour afficher les URLs)
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir

# ---------- 1) Build PC + Build Web + Envoi ----------
Write-Host "`n========== Build PC + Build Web + Envoi ==========" -ForegroundColor Cyan
& (Join-Path $scriptDir "build_pc_and_web.ps1") -SkipFlutter:$SkipFlutter -SkipPc:$SkipPc -SkipWeb:$SkipWeb -PushWebTo $PushWebTo -DoGitPush:$DoGitPush
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur: build_pc_and_web.ps1 a echoue." -ForegroundColor Red
    exit $LASTEXITCODE
}

# ---------- 2) Determiner l'URL de base GitHub Pages (offibox-web) ----------
$baseUrl = $GitHubPagesBase
if (-not $baseUrl -and $PushWebTo -and (Test-Path (Join-Path $PushWebTo ".git"))) {
    $remote = git -C $PushWebTo config --get remote.origin.url 2>$null
    if ($remote) {
        $m = [regex]::Match($remote, 'github\.com[:/]([^/]+)/([^/.]+)')
        if ($m.Success) {
            $owner = $m.Groups[1].Value
            $repo = $m.Groups[2].Value
            $baseUrl = "https://$owner.github.io/$repo/"
        }
    }
}
if (-not $baseUrl) {
    $baseUrl = "https://alexandreperrault.github.io/offibox-web/"
}

$baseUrl = $baseUrl.TrimEnd('/') + '/'

# ---------- 3) Version PC (exe) et chemin local ----------
$version = $null
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $c = Get-Content $pubspecPath -Raw
    $vm = [regex]::Match($c, '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($vm.Success) { $version = $vm.Groups[1].Value }
}
$exeLocalPath = $null
$downloadDir = Join-Path $projectRoot "website\download"
if ($version -and (Test-Path $downloadDir)) {
    $exe = Get-ChildItem -Path $downloadDir -Filter "Offibox-Setup-*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($exe) { $exeLocalPath = $exe.FullName }
}

# Repo GitHub offibox (pour les releases) : essayer de lire depuis la racine projet
$offiboxReleasesUrl = "https://github.com/AlexandrePerrault/offibox/releases"
$offiboxOrigin = git -C $projectRoot config --get remote.origin.url 2>$null
if ($offiboxOrigin) {
    $om = [regex]::Match($offiboxOrigin, 'github\.com[:/]([^/]+)/([^/.]+)')
    if ($om.Success) {
        $offiboxReleasesUrl = "https://github.com/$($om.Groups[1].Value)/$($om.Groups[2].Value)/releases"
    }
}

# ---------- 4) Afficher toutes les URLs ----------
Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Green
Write-Host "  URLS DES ENVOIS (build web + HTML)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`n--- Base GitHub Pages (offibox-web) ---" -ForegroundColor Cyan
Write-Host $baseUrl

Write-Host "`n--- App Flutter (version web) ---" -ForegroundColor Cyan
Write-Host $baseUrl

Write-Host "`n--- HTML (dossier website/) ---" -ForegroundColor Cyan
$websitePages = @(
    "website/app.html",
    "website/app-embed.html",
    "website/demo/demo-app-animation.html",
    "website/login-wix.html",
    "website/validation.html",
    "website/inscription.html",
    "website/telechargement.html",
    "website/telechargement-pc.html",
    "website/plateformes.html",
    "website/login-wix-bandeau.html",
    "website/bandeau-offibox.html"
)
foreach ($p in $websitePages) {
    Write-Host "  $baseUrl$p"
}

Write-Host "`n--- HTML (dossier html/ - pages embed) ---" -ForegroundColor Cyan
$htmlPages = @(
    "html/app.html",
    "html/app-embed.html",
    "html/login-wix.html",
    "html/validation.html",
    "html/inscription.html",
    "html/telechargement.html",
    "html/telechargement-pc.html",
    "html/plateformes.html",
    "html/conditions-utilisation.html"
)
foreach ($p in $htmlPages) {
    Write-Host "  $baseUrl$p"
}

Write-Host "`n--- Build PC (installateur .exe) ---" -ForegroundColor Cyan
if ($exeLocalPath) {
    Write-Host "  Fichier local : $exeLocalPath"
}
Write-Host "  Releases GitHub (apres tag + push) : $offiboxReleasesUrl"
if ($version) {
    Write-Host "  Version generee : $version (tag v$version pour declencher la release)"
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Fin des URLs" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
