; Script Inno Setup - Offibox (installation par utilisateur, sans admin)
; Génère un .exe d'installation dans website\download\

#define MyAppName "Offibox"
; MyAppVersion : lu depuis pubspec.yaml par build_inno.ps1 et la CI (sinon valeur par défaut ci-dessous)
#ifndef MyAppVersion
#define MyAppVersion "1.1.25"
#endif
#define MyAppPublisher "Offibox"
#define MyAppURL "https://www.offibox.fr"
#define MyAppExeName "offibox.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7B3E8A2-9F4C-4D1E-8A5B-2C6D9E1F3A4B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
; Installation par utilisateur (comme l'ancien MSI) : AppData\Local\Offibox
DefaultDirName={userappdata}\Offibox
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Fichier de sortie
OutputDir=..\website\download
OutputBaseFilename=Offibox-Setup-{#MyAppVersion}
SetupIconFile={#ReleaseDir}\data\flutter_assets\assets\icons\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
; Interface moderne
WizardStyle=modern
; Pas de droits administrateur
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Licence EULA en français
LicenseFile=License.rtf
; Message si version plus récente déjà installée
SetupMutex=OffiboxSetupMutex_{#MyAppVersion}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"; LicenseFile: "License.rtf"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le bureau"; GroupDescription: "Options supplémentaires:"; Flags: checkedonce
Name: "launchatstartup"; Description: "Lancer Offibox au démarrage de Windows (recommandé)"; GroupDescription: "Options supplémentaires:"; Flags: checkedonce
Name: "launchafter"; Description: "Lancer Offibox à la fin de l'installation"; GroupDescription: "Options supplémentaires:"; Flags: unchecked

[Files]
; Tout le contenu du build Flutter Windows Release
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "La Boîte à Outils de l'Officine"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "La Boîte à Outils de l'Officine"

[Registry]
; Clé de base (supprimée à la désinstallation)
Root: HKCU; Subkey: "Software\Offibox"; ValueType: none; Flags: deletekey uninsdeletekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer Offibox"; Flags: nowait postinstall skipifsilent; Check: WizardIsTaskSelected('launchafter')

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RegWriteDWordValue(HKEY_CURRENT_USER, 'Software\Offibox', 'installed', 1);
    if WizardIsTaskSelected('launchatstartup') then
      RegWriteDWordValue(HKEY_CURRENT_USER, 'Software\Offibox', 'LaunchAtStartup', 1)
    else
      RegDeleteValue(HKEY_CURRENT_USER, 'Software\Offibox', 'LaunchAtStartup');
    if WizardIsTaskSelected('desktopicon') then
      RegWriteDWordValue(HKEY_CURRENT_USER, 'Software\Offibox', 'DesktopShortcut', 1)
    else
      RegDeleteValue(HKEY_CURRENT_USER, 'Software\Offibox', 'DesktopShortcut');
  end;
end;
