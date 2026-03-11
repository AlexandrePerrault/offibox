# Générer l'installateur Inno Setup et publier sur GitHub

## 1. Générer le .exe en local

Dans un terminal PowerShell à la **racine du projet** ou dans `installer` :

```powershell
cd installer
.\build_inno.ps1
```

Sans refaire le build Flutter (dossier Release déjà à jour) :

```powershell
.\build_inno.ps1 -SkipFlutter
```

Le fichier produit est : **`website\download\Offibox-Setup-<version>.exe`**.

**Version :** elle est lue automatiquement depuis **`pubspec.yaml`** (ligne `version: 1.1.25`) à chaque build. Le script affiche `Version (pubspec.yaml) : 1.1.25` avant la compilation.

---

## 2. Mettre à jour la version

Une seule modification à faire : **`pubspec.yaml`** à la racine du projet.

Exemple pour passer en 1.1.26 :

```yaml
version: 1.1.26
```

Puis relancer `.\build_inno.ps1`. Le .exe généré sera **Offibox-Setup-1.1.26.exe**.

Vous n'avez pas à modifier `Offibox.iss` : la version est injectée par le script et par la CI à partir de `pubspec.yaml`.

---

## 3. Push du code et création de la release sur GitHub

Branche par défaut du dépôt : **`master`** (utiliser `git push origin master`).

### Option A : Vous uploadez le .exe à la main

```powershell
# À la racine du projet offibox
git add .
git status
git commit -m "Release 1.1.25 - Installateur Inno Setup"
git push origin master
```

Créer le tag et le pousser :

```powershell
git tag v1.1.25
git push origin v1.1.25
```

Puis sur GitHub :

1. Aller dans **Releases** → **Draft a new release**.
2. Choisir le tag **v1.1.25**.
3. Titre : `v1.1.25` ou `Offibox 1.1.25`.
4. Dans "Attach binaries", ajouter le fichier **`website\download\Offibox-Setup-1.1.25.exe`** (depuis votre PC).
5. Publier la release.

### Option B : La CI crée la release avec le .exe (recommandé)

Le workflow `.github/workflows/release.yml` : au **push d'un tag v***, build Windows + Inno Setup (version lue dans `pubspec.yaml`) puis création de la release avec le **.exe** en pièce jointe.

```powershell
# À la racine du projet
git add .
git commit -m "Release 1.1.25 - Installateur Inno Setup"
git push origin master

git tag v1.1.25
git push origin v1.1.25
```

Quelques minutes après le push du tag, la release **v1.1.25** est créée automatiquement avec **Offibox-Setup-1.1.25.exe** attaché.

---

## 4. URL du .exe sur GitHub

Une fois la release publiée (à la main ou par la CI) :

- **Page de la release :**  
  `https://github.com/AlexandrePerrault/offibox/releases/tag/v1.1.25`

- **Lien direct de téléchargement du .exe :**  
  `https://github.com/AlexandrePerrault/offibox/releases/download/v1.1.25/Offibox-Setup-1.1.25.exe`

Remplacer **1.1.25** par la version concernée (ex. 1.1.26 → `v1.1.26` et `Offibox-Setup-1.1.26.exe`).

---

## 5. Modifications effectuées (pour les notes de release)

- **Installateur Windows** : passage à **Inno Setup 6** (fichier .exe) à la place du MSI WiX.
- **Comportement** : même installation par utilisateur (sans admin), même options (icône bureau, lancement au démarrage, lancement à la fin), même clés de registre.
- **Interface** : assistant en français, licence EULA (License.rtf), style d'assistant moderne.
- **Build** : script `installer\build_inno.ps1` (Flutter build windows + ISCC). La **version** est lue depuis **pubspec.yaml** à chaque build. Prérequis : [Inno Setup 6](https://jrsoftware.org/isinfo.php).
- **Site** : page téléchargement privilégie le .exe si présent dans les assets de la release GitHub.
- **Menu hamburger** : « Ouvrir offibox.fr » affiche « Fermer Offibox et aller sur Offibox.fr ? » ; sur Oui, l'app se ferme et le site s'ouvre dans le navigateur.
- **Erreur d'installation** : le fichier asset `logo APPEXokkk.jpg` (espace dans le nom) a été renommé en `logo_APPEXokkk.jpg` pour éviter l'erreur d'écriture lors de l'installation.

Vous pouvez copier/coller le bloc ci-dessus dans la description de la release GitHub.
