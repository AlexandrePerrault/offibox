# Build Offibox avec Inno Setup (interface moderne). Lance build Flutter, puis ISCC.
# Usage : .\build_innosetup.ps1 [-TrialNoAuth] [-SkipFlutter] [-BumpVersion false]
#
# Versionnage : ajouter le texte dans lib/data/version_history_notes.dart (menu Historique des versions).
#
# Signature eSigner SSL.com (2 méthodes) :
#   Méthode A — CodeSignTool (recommandée, sans installation CKA) :
#     Télécharger CodeSignTool : https://www.ssl.com/guide/esigner-codesigntool-command-guide/
#     Définir les variables suivantes avant le script :
#       $env:SSLCOM_USERNAME      = "contact@offibox.fr"
#       $env:SSLCOM_PASSWORD      = "votre_mot_de_passe_ssl.com"
#       $env:SSLCOM_CREDENTIAL_ID = "2f3503ba-e7a9-4530-b25f-..."   (credential ID eSigner)
#       $env:SSLCOM_TOTP_SECRET   = "XXXXXXXX"   (secret TOTP — Manage eSigner > View TOTP Secret)
#       $env:CODESIGNTOOL_PATH    = "C:\CodeSignTool\CodeSignTool.bat"
#   Méthode B — signtool.exe + eSigner CKA (clé virtuelle installée) :
#       $env:OFFIBOX_CERT_THUMBPRINT = "A1B2C3..."  (empreinte SHA1 depuis certmgr.msc)
#       ou -CertThumbprint "A1B2C3..."
#
# Token GitHub données : $env:OFFIBOXDATA_GITHUB_TOKEN
# Clé API eSante FHIR  : $env:ESANTE_API_KEY
# Medipim API v4        : $env:MEDIPIM_API_ID + $env:MEDIPIM_API_KEY

param(
  [string]$BumpVersion   = "true",
  [string]$PushToGitHub  = "false",
  [string]$CertThumbprint = "",
  [switch]$SkipFlutter,
  [switch]$TrialNoAuth,
  [string]$FlutterInstaller = "true"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

function Test-NativeCommandFailed {
  return ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0)
}

. (Join-Path $ProjectRoot "scripts\offibox_dart_defines.ps1")
if (Import-OffiboxDotEnv -RootPath $ProjectRoot) {
  Write-Host "Variables chargees depuis .env (process courant)." -ForegroundColor Gray
}

# --- Bump version ----------------------------------------------------------------
$doBump = $BumpVersion -notmatch '^(0|false|no|off)$'
if ($doBump) {
  & (Join-Path $ProjectRoot "scripts\bump_version.ps1")
  if (Test-NativeCommandFailed) { exit $LASTEXITCODE }
}

# --- Build Flutter ---------------------------------------------------------------
if (-not $SkipFlutter) {
  Write-Host ""
  Write-Host "=== Etape 1/3 : preparation (annuaire PS, build_info) ===" -ForegroundColor Cyan
  Write-Host "Recensement Annuaire PS (data.gouv.fr)..." -ForegroundColor Cyan
  Push-Location $ProjectRoot
  try {
    dart run scripts/update_annuaire_ps_count.dart
    if (Test-NativeCommandFailed) { exit $LASTEXITCODE }

    Write-Host "Mise a jour kVersionDate (build_info.dart)..." -ForegroundColor Cyan
    dart run scripts/update_build_info.dart
    if (Test-NativeCommandFailed) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }

  $useFlutterInstaller = $FlutterInstaller -notmatch '^(0|false|no|off)$'
  Write-Host ""
  Write-Host "=== Etape 2/3 : flutter build windows (plusieurs minutes) ===" -ForegroundColor Cyan
  Write-Host "Build Windows (toutes les cles .env -> dart-define)..." -ForegroundColor Cyan
  $fbArgs = Get-OffiboxFlutterBuildArgs -TrialNoAuth:$TrialNoAuth -NoTrialNoAuth:(-not $TrialNoAuth) -FlutterInstaller:$useFlutterInstaller
  if ($TrialNoAuth) {
    Write-Host "  + OFFIBOX_TRIAL_NO_AUTH (essai sans identification)" -ForegroundColor Cyan
  }
  if (-not $env:ESANTE_API_KEY -or $env:ESANTE_API_KEY.Trim().Length -eq 0) {
    Write-Host "  ! ESANTE_API_KEY non definie : fallback CSV annuaire (pas d'appel FHIR)" -ForegroundColor Yellow
  }
  Write-OffiboxDartDefineSummary -Pairs (Get-OffiboxDartDefinePairs -TrialNoAuth:$TrialNoAuth -NoTrialNoAuth:(-not $TrialNoAuth) -FlutterInstaller:$useFlutterInstaller) -TrialNoAuth:$TrialNoAuth
  & (Join-Path $ProjectRoot "scripts\repair_flutter_windows_ephemeral.ps1") -ProjectRoot $ProjectRoot
  & (Join-Path $ProjectRoot "scripts\repair_firebase_windows_sdk.ps1") -ProjectRoot $ProjectRoot
  & (Join-Path $ProjectRoot "scripts\repair_cmake_install_prefix.ps1") -ProjectRoot $ProjectRoot
  & flutter @fbArgs
  if (Test-NativeCommandFailed) {
    Write-Host "ERREUR: flutter build windows (code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
  }
  Write-Host "Flutter build windows : OK" -ForegroundColor Green
} else {
  Write-Host "Skip Flutter : utilisation du dossier Release existant." -ForegroundColor Yellow
}

# --- Chemins ---------------------------------------------------------------------
$ReleaseDir  = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$OutDir      = Join-Path $ProjectRoot "website\download"
$IssFile     = Join-Path $ProjectRoot "installer\innosetup\offibox.iss"

if (-not (Test-Path $ReleaseDir)) {
  Write-Host "ERREUR: Release introuvable ($ReleaseDir). Lancez flutter build windows." -ForegroundColor Red; exit 1
}

$ver = (Get-Content (Join-Path $ProjectRoot "pubspec.yaml") -Raw | Select-String "version:\s*([\d.]+)").Matches.Groups[1].Value
$VersionName = if ($ver) { $ver.Trim() } else { "1.1.0" }
$setupLeaf   = if ($TrialNoAuth) { "Offibox-Setup-Trial-$VersionName" } else { "Offibox-Setup-$VersionName" }
$OutExe      = Join-Path $OutDir "$setupLeaf.exe"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- Inno Setup ------------------------------------------------------------------
$Iscc = $env:ISCC
if (-not $Iscc -or -not (Test-Path $Iscc)) { $Iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
if (-not (Test-Path $Iscc)) {
  Write-Host "ERREUR: Inno Setup 6 non trouve. Installez depuis https://jrsoftware.org/isdownload.php" -ForegroundColor Red; exit 1
}

Write-Host ""
Write-Host "=== Etape 3/3 : Inno Setup (installateur .exe) ===" -ForegroundColor Cyan
Write-Host "Compilation Inno Setup..." -ForegroundColor Cyan
$ReleaseAbs = [IO.Path]::GetFullPath($ReleaseDir)
$OutAbs     = [IO.Path]::GetFullPath($OutDir)

# ISCC ecrit l'exe final via EndUpdateResource : OneDrive / Defender verrouillent souvent
# website\download (erreur 110). On compile d'abord hors sync (TEMP), puis copie.
$TempOutDir = Join-Path $env:TEMP "offibox-inno-build"
$TempOutAbs = [IO.Path]::GetFullPath($TempOutDir)
$TempExe    = Join-Path $TempOutDir "$setupLeaf.exe"

if (Test-Path $TempOutDir) {
  Remove-Item -LiteralPath $TempOutDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $TempOutDir | Out-Null

if (Test-Path $OutExe) {
  try {
    Remove-Item -LiteralPath $OutExe -Force -ErrorAction Stop
  } catch {
    Write-Host "ATTENTION: $OutExe verrouille (explorateur, antivirus, OneDrive). Compilation vers TEMP puis copie." -ForegroundColor Yellow
  }
}

function Invoke-IsccBuild {
  param([string]$OutputDirectory)
  # Ne pas laisser stdout ISCC remonter comme valeur de retour de la fonction.
  & $Iscc $IssFile /DReleaseDir="$ReleaseAbs" /DOutputDir="$OutputDirectory" /DOutputBaseFilename="$setupLeaf" /DAppVersion="$VersionName" 2>&1 | Out-Host
  if ($null -ne $LASTEXITCODE) { return [int]$LASTEXITCODE }
  return 0
}

# Fichiers de build / debug a ne pas embarquer dans l'installateur.
Get-ChildItem -LiteralPath $ReleaseDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in '.log', '.lib', '.exp' } |
  ForEach-Object {
    Write-Host "Nettoyage Release : $($_.Name)" -ForegroundColor Gray
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
  }

$isccExit = Invoke-IsccBuild -OutputDirectory $TempOutAbs
if ($isccExit -ne 0 -or -not (Test-Path $TempExe)) {
  Write-Host "Nouvelle tentative ISCC (dossier TEMP)..." -ForegroundColor Yellow
  Start-Sleep -Seconds 2
  if (Test-Path $TempOutDir) {
    Remove-Item -LiteralPath $TempOutDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Force -Path $TempOutDir | Out-Null
  $isccExit = Invoke-IsccBuild -OutputDirectory $TempOutAbs
}
if ($isccExit -ne 0 -and -not (Test-Path $TempExe)) {
  Write-Host "ERREUR: iscc (code $isccExit)" -ForegroundColor Red
  Write-Host "  Cause frequente : antivirus ou OneDrive sur le dossier de sortie." -ForegroundColor Yellow
  Write-Host "  Exclure TEMP\offibox-inno-build et website\download, ou desactiver la sync OneDrive sur le projet." -ForegroundColor Yellow
  exit 1
}
if (-not (Test-Path $TempExe)) {
  Write-Host "ERREUR: installateur introuvable apres ISCC ($TempExe)" -ForegroundColor Red
  exit 1
}

$copied = $false
for ($try = 1; $try -le 5; $try++) {
  try {
    Copy-Item -LiteralPath $TempExe -Destination $OutExe -Force -ErrorAction Stop
    $copied = $true
    break
  } catch {
    if ($try -lt 5) {
      Write-Host "Copie vers website\download (tentative $try/5)..." -ForegroundColor Yellow
      Start-Sleep -Seconds 2
    }
  }
}
if (-not $copied) {
  Write-Host "ERREUR: copie impossible vers $OutExe" -ForegroundColor Red
  Write-Host "  Installateur disponible ici : $TempExe" -ForegroundColor Yellow
  exit 1
}
Write-Host "Installateur cree : $OutExe" -ForegroundColor Green

# --- Dépôt GitHub public des releases (org, sans nom personnel) ---
$ReleaseRepo = if ($env:OFFIBOX_GITHUB_RELEASE_REPO) { $env:OFFIBOX_GITHUB_RELEASE_REPO.Trim() } else { "offibox/offibox-releases" }
$GitHubDownloadUrl = "https://github.com/$ReleaseRepo/releases/download/v$VersionName/$setupLeaf.exe"
$GitHubReleasesPage = "https://github.com/$ReleaseRepo/releases/latest"

$LatestJsonPath = Join-Path $OutDir "latest.json"
$latestPayload = @{
  version      = $VersionName
  download_url = $GitHubDownloadUrl
  published_at = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Compress
Set-Content -Path $LatestJsonPath -Value $latestPayload -Encoding UTF8 -NoNewline
Write-Host "Release publique : $ReleaseRepo" -ForegroundColor Green
Write-Host "  Page clients : $GitHubReleasesPage" -ForegroundColor Gray
Write-Host "  Setup direct : $GitHubDownloadUrl" -ForegroundColor Gray

# --- Signature -------------------------------------------------------------------
. (Join-Path $ProjectRoot 'scripts\Invoke-OffiboxCodeSign.ps1')

if (Invoke-OffiboxCodeSign -FilePath $OutExe) {
  Write-Host "Installateur signe (CodeSignTool) : $OutExe" -ForegroundColor Green
} else {
  # Methode B : signtool.exe + eSigner CKA
  $thumbprint = if ($CertThumbprint) { $CertThumbprint.Trim() } else { if ($env:OFFIBOX_CERT_THUMBPRINT) { $env:OFFIBOX_CERT_THUMBPRINT.Trim() } else { "" } }
  if ($thumbprint.Length -gt 0) {
    $Signtool = $env:SIGNTOOL_PATH
    if (-not $Signtool -or -not (Test-Path $Signtool)) {
      $KitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
      if (Test-Path $KitsRoot) {
        $latest = Get-ChildItem -Path $KitsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $x64 = Join-Path $latest.FullName "x64\signtool.exe"; if (Test-Path $x64) { $Signtool = $x64 } }
      }
    }
    if ($Signtool -and (Test-Path $Signtool)) {
      Write-Host "Signature via signtool.exe (eSigner CKA)..." -ForegroundColor Cyan
      & $Signtool sign /tr "http://ts.ssl.com" /td sha256 /fd sha256 /sha1 $thumbprint /v $OutExe
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Installateur signe (signtool) : $OutExe" -ForegroundColor Green
      } else {
        Write-Host "ATTENTION: signature signtool echouee (code $LASTEXITCODE)." -ForegroundColor Yellow
      }
    } else {
      Write-Host "ATTENTION: installateur NON signe." -ForegroundColor Yellow
      Write-Host "  CodeSignTool : verifiez SSLCOM_* dans .env (username = email ssl.com complet)." -ForegroundColor Yellow
      Write-Host "  Ou installez Windows SDK (signtool) + eSigner CKA." -ForegroundColor Yellow
      Write-Host "  Puis : .\scripts\sign_offibox_installer.ps1" -ForegroundColor Yellow
    }
  } else {
    Write-Host "ATTENTION: installateur NON signe (SSLCOM_* ou OFFIBOX_CERT_THUMBPRINT manquant)." -ForegroundColor Yellow
  }
}

# --- Push GitHub -----------------------------------------------------------------
$doPush = $PushToGitHub -match '^(1|true|yes)$'
if ($doPush) {
  Push-Location $ProjectRoot
  try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
      . (Join-Path $ProjectRoot 'scripts\Invoke-GitAddQuiet.ps1')
      $branch = & git rev-parse --abbrev-ref HEAD 2>$null
      if ($LASTEXITCODE -eq 0) {
        $gitPaths = @(
          "pubspec.yaml",
          "build_innosetup.ps1",
          "installer\innosetup\offibox.iss",
          "website\download\latest.json"
        )
        foreach ($rel in $gitPaths) {
          $full = Join-Path $ProjectRoot $rel
          if (Test-Path $full) { Add-GitPathQuiet -Path $full }
        }
        Get-ChildItem -Path (Join-Path $ProjectRoot "website\download") -Filter "*.exe" -File -ErrorAction SilentlyContinue |
          ForEach-Object { Add-GitPathQuiet -Path $_.FullName }
        $status = & git status --porcelain 2>$null
        if ($status) {
          & git commit -m "Release $VersionName"
          if ($LASTEXITCODE -eq 0) {
            & git push origin $branch
            if ($LASTEXITCODE -eq 0) {
              & git tag -f "v$VersionName" 2>$null | Out-Null
              & git push origin -f "v$VersionName" 2>$null | Out-Null
            }
          }
        } else {
          Write-Host "Depot prive : rien a committer (release org publiee quand meme)." -ForegroundColor Yellow
        }
      }
    }

    if (Get-Command gh -ErrorAction SilentlyContinue) {
      . (Join-Path $ProjectRoot 'scripts\Invoke-OffiboxPublicReleaseDocs.ps1')
      Publish-OffiboxGithubRelease `
        -Version $VersionName `
        -ProjectRoot $ProjectRoot `
        -OutExe $OutExe `
        -LatestJsonPath $LatestJsonPath `
        -ReleaseRepo $ReleaseRepo | Out-Null
    }
  } finally { Pop-Location }
}
