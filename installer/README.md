# Installateur MSI Offibox

Deux méthodes possibles : **WiX v4 (SDK + dotnet build)** ou **WiX v3 (script PowerShell)**.

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

Le script produit **`website\download\Offibox-Setup-1.0.11.msi`** (voir `installer\wix\Product.wxs`).

---

## Mettre à jour la version

- **WiX v4 :** modifier `Version` dans `installer\Package.wxs` et éventuellement `PackageFileName` dans `Offibox.wixproj`.
- **WiX v3 :** modifier `installer\wix\Product.wxs` et `build_msi.ps1`.
- Toujours mettre à jour le lien dans **`website\index.html`** (bouton Téléchargement).

## Hébergement

Hébergez le dossier `website\` (avec `download\` et le fichier `.msi`) ou hébergez le MSI ailleurs et remplacez l’`href` du bouton par l’URL du fichier.
