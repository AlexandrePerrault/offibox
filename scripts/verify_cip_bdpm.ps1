# Verifie le statut d'un CIP13 a partir des fichiers sources BDPM
# Usage: .\verify_cip_bdpm.ps1 -Cip13 "3400934832758"
# URLs: CIS_bdpm.txt, CIS_CIP_bdpm.txt, CIS_CPD_bdpm.txt

param(
    [Parameter(Mandatory=$true)][string]$Cip13
)
$Cip13 = $Cip13 -replace '\D', ''
if ($Cip13.Length -ne 13) { Write-Error "CIP13 doit faire 13 chiffres"; exit 1 }

$base = "https://base-donnees-publique.medicaments.gouv.fr/download/file"
$tmp = $env:TEMP

Write-Host "=== CIP13 $Cip13 ===" -ForegroundColor Cyan

# 1) CIS_CIP_bdpm.txt : CIP -> CIS, statut presentation (col0=CIS, col5=date, col6=CIP13, col7=oui/non)
Write-Host "`n--- CIS_CIP_bdpm.txt (presentations) ---" -ForegroundColor Yellow
$cipFile = Join-Path $tmp "CIS_CIP_bdpm.txt"
if (-not (Test-Path $cipFile)) {
    Write-Host "Telechargement CIS_CIP_bdpm.txt..."
    Invoke-WebRequest -Uri "$base/CIS_CIP_bdpm.txt" -UseBasicParsing -TimeoutSec 120 -OutFile $cipFile
}
$line = Select-String -Path $cipFile -Pattern $Cip13 | Select-Object -First 1
if ($line) {
    $cols = $line.Line -split "`t"
    $cis = $cols[0]
    Write-Host "CIS      : $cis"
    Write-Host "Libelle  : $($cols[2])"
    Write-Host "Col5     : $($cols[5])"
    Write-Host "CIP13    : $($cols[6])"
    Write-Host "Col7     : $($cols[7])"
} else {
    Write-Host "CIP13 non trouve dans CIS_CIP_bdpm.txt"
    $cis = $null
}

# 2) CIS_bdpm.txt : statut commercial (Commercialisee / etc.)
if ($cis) {
    Write-Host "`n--- CIS_bdpm.txt (specialites, CIS $cis) ---" -ForegroundColor Yellow
    $cisFile = Join-Path $tmp "CIS_bdpm.txt"
    if (-not (Test-Path $cisFile)) {
        Write-Host "Telechargement CIS_bdpm.txt..."
        Invoke-WebRequest -Uri "$base/CIS_bdpm.txt" -UseBasicParsing -TimeoutSec 120 -OutFile $cisFile
    }
    Select-String -Path $cisFile -Pattern "^$cis`t" | ForEach-Object { Write-Host $_.Line }
}

# 3) CIS_CPD_bdpm.txt : conditions (hospitalier, liste I, etc.) — pas une date de fin de commercialisation
if ($cis) {
    Write-Host "`n--- CIS_CPD_bdpm.txt (conditions prescription/delivrance pour CIS $cis) ---" -ForegroundColor Yellow
    $cpdFile = Join-Path $tmp "CIS_CPD_bdpm.txt"
    if (-not (Test-Path $cpdFile)) {
        Write-Host "Telechargement CIS_CPD_bdpm.txt..."
        Invoke-WebRequest -Uri "$base/CIS_CPD_bdpm.txt" -UseBasicParsing -TimeoutSec 120 -OutFile $cpdFile
    }
    $cpd = Select-String -Path $cpdFile -Pattern "^$cis`t"
    if ($cpd) { $cpd | ForEach-Object { Write-Host $_.Line } } else { Write-Host "(aucune ligne)" }
}

Write-Host "`n--- Regle NSFP dans Offibox ---" -ForegroundColor Cyan
Write-Host "Un medicament est masque (Masquer NSFP) si: nsfp=oui ET date rupture (col 12) non vide dans BDM_MASTER2026.csv."
Write-Host "Si le CIS est 'Commercialisee' dans CIS_bdpm et sans date de fin en col 12, il doit apparaitre dans la barre."
