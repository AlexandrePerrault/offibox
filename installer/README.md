# Installateur Windows Offibox

L’installateur recommandé est **Inno Setup 6** (interface moderne, français, un seul .exe). L’ancien **WiX (MSI)** reste disponible en alternative.

---

## Méthode recommandée : Inno Setup 6

**Prérequis :** [Inno Setup 6](https://jrsoftware.org/isinfo.php) installé (gratuit).

1. À la racine du projet, ou dans `installer\` :
   ```powershell
   cd installer
   .\build_inno.ps1
   ```
   Le script lance `flutter build windows` puis compile `Offibox.iss` avec ISCC.  
   Pour ne pas relancer le build Flutter (dossier Release déjà à jour) :
   ```powershell
   .\build_inno.ps1 -SkipFlutter
   ```

2. **Sortie :** `website\download\Offibox-Setup-1.1.25.exe` (version lue depuis `Offibox.iss` / `pubspec.yaml`).

**Contenu de l’installateur :**
- Installation par utilisateur (sans admin) dans `%LocalAppData%\Offibox`
- Interface en français, licence EULA (fichier `License.rtf`)
- Options : créer une icône sur le bureau, lancer au démarrage de Windows, lancer à la fin de l’installation
- Même clés de registre que l’ancien MSI : `HKCU\Software\Offibox` (installed, LaunchAtStartup, DesktopShortcut)

**Mettre à jour la version :** modifier `#define MyAppVersion` dans `installer\Offibox.iss` (et éventuellement `pubspec.yaml`), puis relancer `.\build_inno.ps1`.

---

## Méthode alternative : WiX (MSI)

Deux options : **WiX v4** (SDK + `dotnet build`) ou **WiX v3** (script PowerShell).

### WiX v4
- **Prérequis :** .NET SDK.
- `flutter build windows` puis `cd installer` et `dotnet build`.
- MSI produit dans `website\download\` (ou `installer\obj\Release\`).

### WiX v3
- **Prérequis :** [WiX Toolset v3](https://wixtoolset.org/) installé.
- À la racine : `.\build_msi.ps1` → `website\download\Offibox-Setup-1.1.25.msi`.

---

## Options à proposer (Inno et WiX)

1. **Créer une icône sur le bureau**
2. **Lancer Offibox au démarrage de Windows (recommandé)** → `HKCU\Software\Offibox\LaunchAtStartup` = 1
3. **Lancer Offibox à la fin de l’installation**

---

## Signature de code (SmartScreen)

Pour éviter « Windows a protégé votre ordinateur », signer l’exécutable et l’installateur (.exe ou .msi) avec un certificat Code Signing (DigiCert, Sectigo, etc.) et `signtool.exe` (Windows SDK). Inno Setup peut appeler un outil de signature en post-compilation si besoin.

---

## Site et téléchargement

- **Inno Setup** produit un **.exe** : `Offibox-Setup-1.1.25.exe`.
- **WiX** produit un **.msi** : `Offibox-Setup-1.1.25.msi`.

Sur le site (page téléchargement, GitHub Releases), proposer le **.exe** en priorité si vous utilisez Inno Setup. Adapter les liens et le texte (ex. « fichier .exe » au lieu de « fichier .msi ») dans `website\telechargement.html`, `website\validation.html`, etc.

## Hébergement

Hébergez le dossier `website\` (avec `download\` et le fichier d’installation .exe ou .msi), ou hébergez l’installateur ailleurs et mettez à jour l’URL sur le site.
