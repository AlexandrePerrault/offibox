# Ouvre Bloc-notes avec les commandes PowerShell pour build et release Offibox
$code = @'
# ========== COMMANDES POWERSHELL RELEASE OFFIBOX ==========
# Copier-coller dans PowerShell (adaptez le chemin et la version).

# ----- 1. BUILD .EXE (à la racine du projet) -----
cd C:\Users\perra\Documents\projets_flutter\offibox
.\installer\build_inno.ps1

# (Option : sans refaire le build Flutter)
# .\installer\build_inno.ps1 -SkipFlutter


# ----- 2. BUILD ÉTAPE PAR ÉTAPE (comme la CI) -----
cd C:\Users\perra\Documents\projets_flutter\offibox
flutter pub get
flutter build windows --release
$v = (Get-Content pubspec.yaml | Select-String '^\s*version:\s*(.+)$').Matches.Groups[1].Value.Trim()
Write-Host "Version: $v"
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) { throw "ISCC introuvable. Installez Inno Setup 6." }
& $iscc "/DMyAppVersion=$v" installer/Offibox.iss
Get-ChildItem -Path website\download -Filter "Offibox-Setup-*.exe"


# ----- 3. CRÉER LA RELEASE GITHUB (tag + push) -----
cd C:\Users\perra\Documents\projets_flutter\offibox
Select-String -Path pubspec.yaml -Pattern "version:"
git tag v1.1.26
git push origin v1.1.26

'@

$fichier = Join-Path $PSScriptRoot "CODES_RELEASE_OFFIBOX.txt"
$code | Set-Content -Path $fichier -Encoding UTF8
Start-Process notepad $fichier
