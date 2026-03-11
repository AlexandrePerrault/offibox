# Build MSI Offibox. Lance recensement Annuaire PS (data.gouv.fr), puis "flutter build windows", puis WiX.
# Nécessite : WiX Toolset v3 (https://wixtoolset.org/)
# Exécuter depuis la racine du projet : .\build_msi.ps1
# Si -BumpVersion est passé (défaut : true), incrémente la version avant de builder (1.1.02 -> 1.1.03).
# Depuis CMD : powershell -File ".\build_msi.ps1" -BumpVersion false  (pour ne pas bumper)
# -PushToGitHub true : après succès, git add + commit + push + tag vX.Y.Z + creation d'une Release GitHub
#   (titre + notes lues depuis release_notes.md si present, sinon "Release X.Y.Z") + upload du MSI en asset.
#   C'est cette Release qui alimente la fenetre "Historique des versions" dans l'app (API GitHub Releases).
#
# Signature de code (éviter "Windows a protégé votre ordinateur" / SmartScreen) :
#   Définir OFFIBOX_SIGN=1 et OFFIBOX_CERT_PATH=chemin\vers\certificat.pfx (et OFFIBOX_CERT_PASSWORD=motdepasse)
#   ou utiliser -Sign true -CertPath "..." -CertPassword "..." en paramètres.
#   Nécessite : Windows SDK (signtool.exe) et un certificat de signature de code (CA reconnue par Microsoft).

param([string]$BumpVersion = "true", [string]$PushToGitHub = "false", [string]$Sign = "false", [string]$CertPath = "", [string]$CertPassword = "")

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

$doBump = $BumpVersion -notmatch '^(0|false|no|off)$'
if ($doBump) {
  $bumpScript = Join-Path $ProjectRoot "scripts\bump_version.ps1"
  $p = Start-Process -FilePath "powershell.exe" -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$bumpScript -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) { exit $p.ExitCode }
}

# Recenser le nombre de professionnels (Annuaire PS) pour « À propos » et rebuild pour figer la valeur dans la version
Write-Host "Recensement Annuaire PS (data.gouv.fr)..." -ForegroundColor Cyan
$p = Start-Process -FilePath "dart" -ArgumentList "run","scripts/update_annuaire_ps_count.dart" -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { Write-Host "ATTENTION: script annuaire PS a echoue (code $($p.ExitCode)), valeur par defaut conservee." -ForegroundColor Yellow }
Write-Host "Build Windows..." -ForegroundColor Cyan
$p = Start-Process -FilePath "flutter" -ArgumentList "build","windows" -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { Write-Host "ERREUR: flutter build windows a echoue (code $($p.ExitCode))" -ForegroundColor Red; exit $p.ExitCode }

Write-Host "Preparation WiX..." -ForegroundColor Cyan
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$WixDir   = Join-Path $ProjectRoot "installer\wix"
$OutDir   = Join-Path $ProjectRoot "website\download"

# Lire la version depuis pubspec.yaml (format X.Y.Z ou X.Y.Z+build)
$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$versionLine = Get-Content $PubspecPath -Raw | Select-String -Pattern "version:\s*([\d.]+)(?:\+\d+)?" | ForEach-Object { $_.Matches.Groups[1].Value }
$VersionName = if ($versionLine) { $versionLine.Trim() } else { "1.1.25" }
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
    Write-Host "  Pour l'autostart installateur : flutter build windows --dart-define=FLUTTER_BUILD_WINDOWS=true" -ForegroundColor Yellow
    Write-Host "  Attendu: $ReleaseDir" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 0) Optionnel : signature de l'exe AVANT harvest (pour que le MSI contienne l'exe signe)
$doSign = ($Sign -match '^(1|true|yes|on)$') -or ($env:OFFIBOX_SIGN -match '^(1|true|yes|on)$')
$signCertPath = if ($CertPath) { $CertPath } else { $env:OFFIBOX_CERT_PATH }
$signCertPassword = if ($CertPassword) { $CertPassword } else { $env:OFFIBOX_CERT_PASSWORD }
if ($doSign -and $signCertPath -and (Test-Path $signCertPath)) {
  $Signtool = $env:SIGNTOOL_PATH
  if (-not $Signtool -or -not (Test-Path $Signtool)) {
    $KitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $KitsRoot) {
      $latest = Get-ChildItem -Path $KitsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
      if ($latest) {
        $x64 = Join-Path $latest.FullName "x64\signtool.exe"
        if (Test-Path $x64) { $Signtool = $x64 }
      }
    }
  }
  if ($Signtool -and (Test-Path $Signtool)) {
    $ExeToSign = Join-Path $ReleaseDir "offibox.exe"
    if (Test-Path $ExeToSign) {
      Write-Host "Signature de l'executable (avant MSI)..." -ForegroundColor Cyan
      $timestampUrl = "http://timestamp.digicert.com"
      $signArgs = @("sign", "/tr", $timestampUrl, "/td", "sha256", "/fd", "sha256", "/f", $signCertPath, "/v")
      if ($signCertPassword) { $signArgs = $signArgs + @("/p", $signCertPassword) }
      & $Signtool @signArgs $ExeToSign
      if ($LASTEXITCODE -ne 0) { Write-Host "ATTENTION: signature exe echouee (code $LASTEXITCODE)" -ForegroundColor Yellow }
    }
  }
}

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
# WixUI_FeatureTree exige WixUIBannerBmp et WixUIDialogBmp (493x58 et 493x312). Créer des placeholders si absents.
$BitmapDir = [System.IO.Path]::GetFullPath((Join-Path $WixDir "bitmap"))
$BannerBmp = Join-Path $BitmapDir "bannrbmp.bmp"
$DialogBmp = Join-Path $BitmapDir "dlgbmp.bmp"
if (-not (Test-Path $BitmapDir)) { New-Item -ItemType Directory -Path $BitmapDir -Force | Out-Null }

function New-MinimalBmpBytes {
  param([int]$Width, [int]$Height)
  $rowBytes = [int](([math]::Ceiling(($Width * 3) / 4) * 4))
  $pixelDataSize = $rowBytes * $Height
  $fileSize = 54 + $pixelDataSize
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  $bw.Write([byte[]]@(0x42, 0x4D))
  $bw.Write([uint32]$fileSize)
  $bw.Write([uint16]0); $bw.Write([uint16]0)
  $bw.Write([uint32]54)
  $bw.Write([uint32]40)
  $bw.Write([int32]$Width)
  $bw.Write([int32]$Height)
  $bw.Write([uint16]1)
  $bw.Write([uint16]24)
  $bw.Write([uint32]0)
  $bw.Write([uint32]$pixelDataSize)
  $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
  $pad = $rowBytes - ($Width * 3)
  for ($y = 0; $y -lt $Height; $y++) {
    for ($x = 0; $x -lt $Width; $x++) { $bw.Write([byte[]]@(64, 16, 0)) }
    for ($p = 0; $p -lt $pad; $p++) { $bw.Write([byte]0) }
  }
  $bw.Flush()
  $ms.ToArray()
}

function Ensure-WixBitmap {
  param([string]$Path, [int]$Width, [int]$Height)
  if (Test-Path $Path) { return }
  try {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 16, 64))
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bmp.Dispose()
    Write-Host "Placeholder cree : $Path" -ForegroundColor Gray
  } catch {
    Write-Host "Fallback BMP (sans System.Drawing) : $Path" -ForegroundColor Gray
    [System.IO.File]::WriteAllBytes($Path, (New-MinimalBmpBytes -Width $Width -Height $Height))
  }
}
Ensure-WixBitmap -Path $BannerBmp -Width 493 -Height 58
Ensure-WixBitmap -Path $DialogBmp -Width 493 -Height 312
$BannerBmp = [System.IO.Path]::GetFullPath($BannerBmp)
$DialogBmp = [System.IO.Path]::GetFullPath($DialogBmp)
if (-not (Test-Path $BannerBmp) -or -not (Test-Path $DialogBmp)) {
  Write-Host "ERREUR: Bitmaps WiX introuvables apres creation." -ForegroundColor Red
  exit 1
}
# light.exe exige -dVariable=Value (un seul argument par variable, pas -d puis valeur séparée).
$LightArgs = @(
  '-out', $OutMsi, $ProductObj, $HarvestObj,
  '-b', $ReleaseDir,
  '-ext', 'WixUIExtension', '-ext', 'WixUtilExtension', '-sval',
  ('-dWixUIBannerBmp=' + $BannerBmp),
  ('-dWixUIDialogBmp=' + $DialogBmp)
)
& $Light @LightArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: light a echoue (code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "MSI cree : $OutMsi" -ForegroundColor Green

# 3b) Signature du MSI (evite l'avertissement SmartScreen "Windows a protege votre ordinateur")
if ($doSign -and $signCertPath -and (Test-Path $signCertPath)) {
  if (-not $Signtool -or -not (Test-Path $Signtool)) {
    $KitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $KitsRoot) {
      $latest = Get-ChildItem -Path $KitsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
      if ($latest) {
        $x64 = Join-Path $latest.FullName "x64\signtool.exe"
        if (Test-Path $x64) { $Signtool = $x64 }
      }
    }
  }
  if ($Signtool -and (Test-Path $Signtool)) {
    Write-Host "Signature du MSI..." -ForegroundColor Cyan
    $timestampUrl = "http://timestamp.digicert.com"
    $signArgs = @("sign", "/tr", $timestampUrl, "/td", "sha256", "/fd", "sha256", "/f", $signCertPath, "/v")
    if ($signCertPassword) { $signArgs = $signArgs + @("/p", $signCertPassword) }
    & $Signtool @signArgs $OutMsi
    if ($LASTEXITCODE -eq 0) {
      Write-Host "MSI signe (SmartScreen ne bloquera pas l'installation)." -ForegroundColor Green
    } else {
      Write-Host "ATTENTION: signature MSI echouee (code $LASTEXITCODE). Le MSI reste non signe." -ForegroundColor Yellow
    }
  } else {
    Write-Host "Signature demandee mais signtool introuvable. Installez Windows SDK ou definissez SIGNTOOL_PATH." -ForegroundColor Yellow
  }
} elseif ($doSign -and (-not $signCertPath -or -not (Test-Path $signCertPath))) {
  Write-Host "Signature demandee (OFFIBOX_SIGN=1) mais certificat absent. Definissez OFFIBOX_CERT_PATH (fichier .pfx)." -ForegroundColor Yellow
}

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
        & git add pubspec.yaml build_msi.ps1 installer\wix\Product.wxs.v3 website\index.html website\download\*.msi 2>$null
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
