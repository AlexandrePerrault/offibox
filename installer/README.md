# Installateur MSI Offibox

Deux méthodes possibles : **WiX v4 (SDK + dotnet build)** ou **WiX v3 (script PowerShell)**.

## Logo pendant le chargement

Pour afficher le logo Offibox pendant l’installation (bannière et fond des dialogues) :

- **WiX v3 (build_msi.ps1)** : le script utilise automatiquement `installer\wix\bitmap\bannrbmp.bmp` (bannière) et `installer\wix\bitmap\dlgbmp.bmp` (fond) s'ils existent (493×58 px et 493×312 px recommandés).
- **WiX v4 :** Adapter selon la doc WiX v4 (variables d’interface).

## Options à proposer (toutes cochables)

L’installateur doit proposer et permettre de cocher/décocher :

1. **Créer une icône sur le bureau**
2. **Lancer Offibox au démarrage de Windows (recommandé)** → écrit `HKCU\Software\Offibox\LaunchAtStartup` = 1 ; l’app lit cette clé au premier lancement (voir `main.dart`).
3. **Lancer Offibox** → exécuter `offibox.exe` à la fin de l’installation.

En WiX v3, cela peut être fait via **WixUI_FeatureTree** (icône bureau = feature optionnelle) + **dialogue personnalisé** ou cases sur l’écran de fin pour « démarrage Windows » et « lancer maintenant ».

---

## Méthode 1 : WiX v4 (éditeur de texte + .NET SDK)

**Prérequis :** .NET SDK (ou Visual Studio 2022).

1. Build Flutter : `flutter build windows`  
   Pour que l’installateur applique l’autostart (clé de registre « Lancer au démarrage »), utilisez :  
   `flutter build windows --dart-define=FLUTTER_BUILD_WINDOWS=true`
2. Puis :
   ```powershell
   cd installer
   dotnet build
   ```

Le MSI est produit dans `website\download\` si la config du projet le permet, sinon dans `installer\bin\Debug\` ou `bin\Release\`. Copiez le `.msi` dans `website\download\` pour le lien du site.

**Note :** Si vous avez des erreurs « Cannot find the File … SourceDir\… », le chemin des fichiers récoltés n’est pas résolu. Dans ce cas, utilisez la **méthode 2 (WiX v3)**.

---

## Langue de l’installateur (français)

En **WiX v4** (`Package.wxs`), l’attribut `Language="1036"` sur l’élément `Package` force l’interface de l’installateur en français. Si l’installateur s’affiche en anglais, vérifier que cet attribut est bien présent.

## Erreur 2762 lors de l’installation

L’erreur **2762** (« Unable to schedule operation. The action must be scheduled between InstallInitialize and InstallFinalize ») apparaît souvent quand une **CustomAction** en mode `Execute="deferred"` est appelée depuis une interface (dialogue) au lieu de l’être dans la séquence d’exécution. **Solution :** utiliser uniquement le build **WiX v4** (`Package.wxs`), qui ne contient pas de custom actions différées. Si vous utilisez un ancien script WiX v3 (`Product.wxs.v3`) avec des actions « Lancer Offibox » ou « Démarrage Windows », passer ces actions en `Execute="immediate"` ou les placer correctement entre `InstallInitialize` et `InstallFinalize` dans `InstallExecuteSequence`.

---

## Méthode 2 : WiX v3 (heat, candle, light)

**Prérequis :** [WiX Toolset v3](https://wixtoolset.org/) installé.

À la racine du projet :

```powershell
.\build_msi.ps1
```

Le script produit **`website\download\Offibox-Setup-1.1.24.msi`** (voir `installer\wix\Product.wxs`).

---

## Éviter « Windows a protégé votre ordinateur » (SmartScreen)

Pour que l’installateur et l’application ne déclenchent pas l’avertissement Microsoft Defender SmartScreen, il faut **signer le MSI et l’exécutable** avec un **certificat de signature de code** émis par une autorité reconnue (DigiCert, Sectigo, etc.).

1. **Obtenir un certificat** : acheter un certificat « Code Signing » (ou « Extended Validation » pour une confiance immédiate sous SmartScreen) auprès d’un partenaire Microsoft.
2. **Installer le Windows SDK** (pour `signtool.exe`) : [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/) ou via Visual Studio.
3. **Configurer la signature** avant de lancer `.\build_msi.ps1` :
   - **Variables d’environnement** (recommandé) :
     - `OFFIBOX_SIGN=1`
     - `OFFIBOX_CERT_PATH=C:\chemin\vers\votre_certificat.pfx`
     - `OFFIBOX_CERT_PASSWORD=mot_de_passe_du_pfx`
     - Optionnel : `SIGNTOOL_PATH=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe` si le script ne trouve pas signtool.
   - **Ou en paramètres** :  
     `.\build_msi.ps1 -Sign true -CertPath "C:\...\cert.pfx" -CertPassword "..."`

Le script signe d’abord `offibox.exe` dans le dossier Release, puis construit le MSI (qui contient donc l’exe signé), puis signe le fichier MSI. Une fois le MSI signé et distribué, Windows ne devrait plus afficher l’écran « Windows a protégé votre ordinateur » (après éventuelle accumulation de réputation pour les certificats non EV).

---

## Mettre à jour la version

- **WiX v4 :** modifier `Version` dans `installer\Package.wxs` et éventuellement `PackageFileName` dans `Offibox.wixproj`.
- **WiX v3 :** modifier `installer\wix\Product.wxs` et `build_msi.ps1`.
- Toujours mettre à jour le lien dans **`website\index.html`** (bouton Téléchargement).

## Hébergement

Hébergez le dossier `website\` (avec `download\` et le fichier `.msi`) ou hébergez le MSI ailleurs et remplacez l’`href` du bouton par l’URL du fichier.
