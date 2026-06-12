; Inno Setup - Offibox. Compilation : iscc /DReleaseDir="..." /DAppVersion="X.Y.Z" /DOutputDir="..." /DOutputBaseFilename="..." offibox.iss
; Les variables /D sont passees par build_innosetup.ps1

#ifndef AppVersion
#define AppVersion "1.1.0"
#endif

#ifndef ReleaseDir
#define ReleaseDir "build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "website\download"
#endif

#ifndef OutputBaseFilename
#define OutputBaseFilename "Offibox-Setup"
#endif

#define MyAppName "Offibox"
#define MyAppPublisher "Offibox"
#define MyAppURL "https://offibox.fr"
#define MyAppExeName "offibox.exe"
#define MyAppDescription "La Boîte à Outils de l'Officine"

[Setup]
AppId={{B7B3E8A2-9F4C-4D1E-8A5B-2C6D9E1F3A4B}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppVerName={#MyAppName} {#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Offibox
DefaultGroupName=Offibox
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
SetupLogging=yes
; Ferme offibox.exe (et processus enfants WebView2) avant suppression des fichiers.
CloseApplications=force
RestartApplications=no
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile={#ReleaseDir}\data\flutter_assets\assets\icons\app_icon.ico
LicenseFile=..\License.rtf

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"; LicenseFile: "..\License.rtf"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le bureau"; GroupDescription: "Icônes supplémentaires:"; Flags: unchecked
Name: "launchatstartup"; Description: "Lancer Offibox au démarrage de Windows"; GroupDescription: "Options:"; Flags: checkedonce
Name: "launchnow"; Description: "Lancer Offibox à la fin de l'installation"; GroupDescription: "Options:"; Flags: checkedonce

[Files]
; Exclure explicitement tout secret/fichier de conf sensible pour éviter les fuites dans le setup.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".env,.env.*,*.pem,*.p12,*.pfx,*.key,credentials*.json,startup_diagnostic.log,*.lib,*.exp"

[Icons]
; WorkingDir + IconFilename : Flutter charge data/ à côté de l'exe ; icône extraite de l'exe installé.
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\Désinstaller {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: launchatstartup; Comment: "{#MyAppDescription}"

[Registry]
Root: HKCU; Subkey: "Software\Offibox"; ValueType: dword; ValueName: "LaunchAtStartup"; ValueData: "1"; Flags: uninsdeletekey; Tasks: launchatstartup
Root: HKCU; Subkey: "Software\Offibox"; ValueType: dword; ValueName: "installed"; ValueData: "1"; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "Lancer {#MyAppName}"; Flags: nowait postinstall skipifsilent; Tasks: launchnow
; Mise à jour silencieuse : relance Offibox après installation (/MERGETASKS=launchnow).
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "Relancer {#MyAppName}"; Flags: nowait postinstall; Tasks: launchnow; Check: WizardSilent

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
procedure KillOffiboxProcesses;
var
  ResultCode: Integer;
begin
  { /T = arbre de processus (WebView2, etc.) }
  Exec('taskkill.exe', '/F /IM {#MyAppExeName} /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(400);
end;

function InitializeUninstall(): Boolean;
begin
  KillOffiboxProcesses;
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}');
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    KillOffiboxProcesses;
  if CurUninstallStep = usPostUninstall then
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}');
end;
