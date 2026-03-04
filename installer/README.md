# Installateur MSI Offibox

Deux méthodes possibles : **WiX v4 (SDK + dotnet build)** ou **WiX v3 (script PowerShell)**.

## Logo pendant le chargement

Pour afficher le logo Offibox pendant l’installation (bannière et fond des dialogues) :

- **WiX v3 :** Placer deux images BMP dans `installer\wix\Resources\` :
  - `banner.bmp` : 493 × 58 px (bannière en haut des écrans)
  - `dialog.bmp` : 493 × 312 px (fond des écrans Bienvenue / Fin)
  Puis lancer la liaison avec :  
  `light ... -dWixUIBannerBmp=Resources\banner.bmp -dWixUIDialogBmp=Resources\dialog.bmp`
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
2. Puis :
   ```powershell
   cd installer
   dotnet build
   ```

Le MSI est produit dans `website\download\` si la config du projet le permet, sinon dans `installer\bin\Debug\` ou `bin\Release\`. Copiez le `.msi` dans `website\download\` pour le lien du site.

**Note :** Si vous avez des erreurs « Cannot find the File … SourceDir\… », le chemin des fichiers récoltés n’est pas résolu. Dans ce cas, utilisez la **méthode 2 (WiX v3)**.

---

## Méthode 2 : WiX v3 (heat, candle, light)

**Prérequis :** [WiX Toolset v3](https://wixtoolset.org/) installé.

À la racine du projet :

```powershell
.\build_msi.ps1
```

Le script produit **`website\download\Offibox-Setup-1.1.18.msi`** (voir `installer\wix\Product.wxs`).

---

## Mettre à jour la version

- **WiX v4 :** modifier `Version` dans `installer\Package.wxs` et éventuellement `PackageFileName` dans `Offibox.wixproj`.
- **WiX v3 :** modifier `installer\wix\Product.wxs` et `build_msi.ps1`.
- Toujours mettre à jour le lien dans **`website\index.html`** (bouton Téléchargement).

## Hébergement

Hébergez le dossier `website\` (avec `download\` et le fichier `.msi`) ou hébergez le MSI ailleurs et remplacez l’`href` du bouton par l’URL du fichier.
