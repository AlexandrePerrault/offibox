# Build Offibox avant push GitHub
# Token obligatoire : $env:OFFIBOXDATA_GITHUB_TOKEN
param([switch]$SkipInstaller, [switch]$TrialNoAuth)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$token = $env:OFFIBOXDATA_GITHUB_TOKEN
if (-not $token) { Write-Host "ERREUR: Definir OFFIBOXDATA_GITHUB_TOKEN"; exit 1 }
$dartDefines = @("--dart-define=OFFIBOXDATA_GITHUB_TOKEN=$token", "--dart-define=FLUTTER_BUILD_WINDOWS=true")
if ($env:ESANTE_API_KEY) { $dartDefines += "--dart-define=ESANTE_API_KEY=$($env:ESANTE_API_KEY)" }
if ($TrialNoAuth) { $dartDefines += "--dart-define=OFFIBOX_TRIAL_NO_AUTH=true" }
Push-Location $ProjectRoot
flutter clean; flutter pub get
Invoke-Expression ("flutter build windows " + ($dartDefines -join " "))
if (-not $SkipInstaller) {
    $args = @("-SkipFlutter")
    if ($TrialNoAuth) { $args += "-TrialNoAuth" }
    & (Join-Path $ProjectRoot "installer\build_inno.ps1") @args
}
Pop-Location
Write-Host "Build OK" -ForegroundColor Green