# Build MSI Offibox après "flutter build windows"
# Nécessite : WiX Toolset v3 (https://wixtoolset.org/)
# Exécuter depuis la racine du projet : .\build_msi.ps1
# Si -BumpVersion est passé (défaut : true), incrémente la version avant de builder (1.1.02 -> 1.1.03).
# Depuis CMD : powershell -File ".\build_msi.ps1" -BumpVersion false  (pour ne pas bumper)
# -PushToGitHub true : après succès, git add + commit + push + tag vX.Y.Z + creation d'une Release GitHub
#   (titre + notes lues depuis release_notes.md si present, sinon "Release X.Y.Z") + upload du MSI en asset.
#   C'est cette Release qui alimente la fenetre "Historique des versions" dans l'app (API GitHub Releases).

param([string]$BumpVersion = "true", [string]$PushToGitHub = "false")

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

$doBump = $BumpVersion -notmatch '^(0|false|no|off)$'
if ($doBump) {
  $bumpScript = Join-Path $ProjectRoot "scripts\bump_version.ps1"
  $p = Start-Process -FilePath "powershell.exe" -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$bumpScript -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) { exit $p.ExitCode }
}

Write-Host "Preparation WiX..." -ForegroundColor Cyan
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$WixDir   = Join-Path $ProjectRoot "installer\wix"
$OutDir   = Join-Path $ProjectRoot "website\download"

# Lire la version depuis pubspec.yaml (format X.Y.Z ou X.Y.Z+build)
$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$versionLine = Get-Content $PubspecPath -Raw | Select-String -Pattern "version:\s*([\d.]+)(?:\+\d+)?" | ForEach-Object { $_.Matches.Groups[1].Value }
$VersionName = if ($versionLine) { $versionLine.Trim() } else { "1.1.17" }
$OutMsi = Join-Path $OutDir "Offibox-Setup-$VersionName.msi"

# WiX : variable d'environnement WIX ou chemin par défaut (doit pointer vers le dossier contenant heat.exe, souvent ...\bin)
$WixBin = $env:WIX
if ($WixBin -and (Test-Path (Join-Path $WixBin "bin")) -and -not (Test-Path (Join-Path $WixBin "heat.exe"))) {
    $WixBin = Join-Path $WixBin "bin"
}
if (-not $WixBin) {
    $WixBin = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
    if (-not (Test-Path $WixBin)) { $WixBin = "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin" }
    if (-not (Test-Path $WixBin)) { $WixBin = "C:\Program Files (x86)\WiX Toolset v3.11\bin" }
}
if (-not (Test-Path $WixBin)) {
    Write-Host "ERREUR: WiX Toolset non trouve. Installez-le depuis https://wixtoolset.org/ ou definissez la variable WIX vers le dossier 'bin' (ex: ...\WiX Toolset v3.14\bin)." -ForegroundColor Red
    exit 1
}

$Heat = Join-Path $WixBin "heat.exe"
$Candle = Join-Path $WixBin "candle.exe"
$Light  = Join-Path $WixBin "light.exe"
if (-not (Test-Path $Heat)) {
    Write-Host "ERREUR: heat.exe introuvable dans $WixBin" -ForegroundColor Red
    Write-Host "  Si WIX pointe vers le dossier d'installation (sans \bin), definissez WIX vers ...\WiX Toolset v3.14\bin" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $ReleaseDir)) {
    Write-Host "ERREUR: Dossier Release introuvable. Lancez d'abord : flutter build windows" -ForegroundColor Red
    Write-Host "  Attendu: $ReleaseDir" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 1) Harvest du dossier Release
$HarvestWxs = Join-Path $WixDir "Harvest.wxs"
Write-Host "Harvest $ReleaseDir -> $HarvestWxs"
& $Heat dir $ReleaseDir -dr INSTALLDIR -ke -srd -sreg -cg ReleaseFiles -gg -out $HarvestWxs
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: heat a echoue (code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2) Compilation
Write-Host "Compilation WiX..."
Push-Location $WixDir
try {
    & $Candle Product.wxs.v3 Harvest.wxs -ext WixUIExtension -ext WixUtilExtension -out ".\"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR: candle a echoue (code $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally { Pop-Location }

# 3) Lien -> MSI
$ProductObj = Join-Path $WixDir "Product.wxs.wixobj"
$HarvestObj = Join-Path $WixDir "Harvest.wixobj"
if (-not (Test-Path $ProductObj)) {
    Write-Host "ERREUR: Fichier absent: $ProductObj" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $HarvestObj)) {
    Write-Host "ERREUR: Fichier absent: $HarvestObj" -ForegroundColor Red
    exit 1
}
Write-Host "Lien -> $OutMsi"
# -b <path> : chemin de base pour résoudre SourceDir\... (Heat génère Source="SourceDir\fichier", Light cherche dans -b)
& $Light -out $OutMsi $ProductObj $HarvestObj -b $ReleaseDir -ext WixUIExtension -ext WixUtilExtension -sval
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: light a echoue (code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "MSI cree : $OutMsi" -ForegroundColor Green

# 4) Optionnel : pousser vers GitHub (commit + push + tag)
$doPush = $PushToGitHub -notmatch '^(0|false|no|off)$'
if ($doPush) {
  Push-Location $ProjectRoot
  try {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
      Write-Host "Push GitHub : git non trouve, ignore." -ForegroundColor Yellow
    } else {
      $branch = & git rev-parse --abbrev-ref HEAD 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Host "Push GitHub : pas un depot git, ignore." -ForegroundColor Yellow
      } else {
        & git add pubspec.yaml build_msi.ps1 installer\wix\Product.wxs.v3 installer\wix\Harvest.wxs website\index.html website\download\*.msi 2>$null
        $status = & git status --porcelain 2>$null
        if ($status) {
          & git commit -m "Release $VersionName"
          if ($LASTEXITCODE -eq 0) {
            & git push origin $branch
            if ($LASTEXITCODE -eq 0) {
              & git tag -f "v$VersionName" 2>$null | Out-Null
              $out = Join-Path $env:TEMP "git_push_out.txt"
              $err = Join-Path $env:TEMP "git_push_err.txt"
              $tagPush = Start-Process -FilePath "git" -ArgumentList "push","origin","-f","v$VersionName" -WorkingDirectory $ProjectRoot -Wait -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
              Remove-Item $out, $err -ErrorAction SilentlyContinue
              if ($tagPush.ExitCode -eq 0) {
                # Creer la Release GitHub (sinon "Historique des versions" ne voit que les Releases, pas les tags seuls)
                $gh = Get-Command gh -ErrorAction SilentlyContinue
                $notesFile = Join-Path $ProjectRoot "release_notes.md"
                if ($gh) {
                  $useNotesFile = $false
                  if (Test-Path $notesFile) {
                    $content = Get-Content $notesFile -Raw
                    if ($content -and ($content.Trim().Length -gt 0)) { $useNotesFile = $true }
                  }
                  if ($useNotesFile) {
                    & gh release create "v$VersionName" --title "v$VersionName" --notes-file $notesFile
                  } else {
                    & gh release create "v$VersionName" --title "v$VersionName" --notes "Release $VersionName"
                  }
                  if ($LASTEXITCODE -eq 0 -and (Test-Path $OutMsi)) {
                    & gh release upload "v$VersionName" $OutMsi --clobber
                  }
                }
                Write-Host "Push GitHub : commit + tag v$VersionName + release (notes depuis release_notes.md si present)" -ForegroundColor Green
              } else {
                Write-Host "Push GitHub : push du tag echoue" -ForegroundColor Red
              }
            } else {
              Write-Host "Push GitHub : push commit echoue" -ForegroundColor Red
            }
          } else {
            Write-Host "Push GitHub : commit echoue (rien a committer ?)" -ForegroundColor Yellow
          }
        } else {
          Write-Host "Push GitHub : rien a committer" -ForegroundColor Yellow
        }
      }
    }
  } finally { Pop-Location }
}
