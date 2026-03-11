# Générer l'installateur Inno Setup et publier sur GitHub

## Procédure complète (build → déploiement GitHub)

À faire **à la racine du projet** (`C:\...\offibox`) dans PowerShell.

| Étape | Commande / action |
|-------|-------------------|
| **1. Build Flutter** | `flutter build windows --release` |
| **2. Installateur + incrément version** | `cd installer` puis `.\build_inno.ps1 -SkipFlutter` puis `cd ..` |
| **3. Commit & push** | `git add ...` puis `git commit -m "Release X.Y.Z - Installateur Inno Setup"` puis `git push origin master` |
| **4. Tag & push (déclenche la CI)** | `git tag vX.Y.Z` puis `git push origin vX.Y.Z` (X.Y.Z = version dans pubspec après étape 2) |
| **5. Attendre la CI** | GitHub Actions → Release → 2–5 min → release créée avec le .exe |

**URLs une fois la release publiée** (remplacer `X.Y.Z` par la version, ex. `1.1.26`) :

- **Page release :** `https://github.com/AlexandrePerrault/offibox/releases/tag/vX.Y.Z`
- **Lien direct du setup :** `https://github.com/AlexandrePerrault/offibox/releases/download/vX.Y.Z/Offibox-Setup-X.Y.Z.exe`
- **Dernière release :** `https://github.com/AlexandrePerrault/offibox/releases/latest`

---

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

**Version :** à chaque exécution, le script **incrémente le patch** dans **`pubspec.yaml`** (ex. 1.1.25 → 1.1.26), met à jour le fichier, puis compile. Il affiche `Ancienne version` et `Nouvelle version` avant la compilation.

**Historique des versions (menu hamburger) :** les textes affichés viennent des **releases GitHub** (corps/description de chaque release). Modifier la description d’une release sur GitHub (Releases → Edit) met à jour automatiquement l’onglet hamburger « Historique des versions » au prochain chargement. La date affichée dans « À propos » vient de `lib/generated/build_info.dart` (`kVersionDate`).

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

## 5. Erreur 403 « Resource not accessible by integration »

Si le workflow Release échoue avec **403** et le message lié à **generate release notes** :

- Le workflow utilise désormais **`generate_release_notes: false`** : l’API de génération automatique des release notes n’est pas accessible avec le `GITHUB_TOKEN` par défaut. La description de la release est un court texte fixe.
- Vérifier aussi : **Settings** → **Actions** → **General** → **Workflow permissions** = **« Read and write permissions »** (pas « Read repository contents only »).

---

## 6. Vérifier que le setup .exe est sur GitHub

- **Page des releases :** https://github.com/AlexandrePerrault/offibox/releases  
- **Dernière release :** https://github.com/AlexandrePerrault/offibox/releases/latest  
- Le .exe est attaché à chaque release (ex. **Offibox-Setup-1.1.25.exe** pour le tag **v1.1.25**).  
- Lien direct de téléchargement : `https://github.com/AlexandrePerrault/offibox/releases/download/vX.Y.Z/Offibox-Setup-X.Y.Z.exe`

---

## 7. Signature numérique du setup (optionnel)

Pour que Windows et SmartScreen ne bloquent pas le téléchargement (« Windows a protégé votre ordinateur »), vous pouvez **signer le .exe** dans la CI avec un certificat Code Signing.

1. **Certificat** : obtenir un certificat Code Signing (DigiCert, Sectigo, etc.) au format **.pfx**.
2. **Secrets du dépôt** : dans le dépôt GitHub → **Settings** → **Secrets and variables** → **Actions**, ajouter :
   - **`OFFIBOX_SIGNING_CERT_BASE64`** : contenu du fichier .pfx encodé en **base64**.  
     Sous PowerShell :  
     `[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\chemin\to\votre-cert.pfx"))`  
     Copier le résultat (une longue chaîne) dans la valeur du secret.
   - **`OFFIBOX_SIGNING_PASSWORD`** : mot de passe du fichier .pfx.
3. **Obtenir un .exe signé** :
   - **Option A** : pousser un **nouveau tag** (ex. `git tag v1.1.26` puis `git push origin v1.1.26`). Le workflow build + signe + uploade le .exe.
   - **Option B** : pour **re-signer une release existante**, aller dans **Actions** → ouvrir l’exécution du workflow **Release** du tag concerné → **Re-run all jobs**. Le .exe sera reconstruit, signé et ré-uploadé (écrasement grâce à `overwrite_files: true`).
4. Si les secrets sont absents, l’étape « Sign setup (optional) » affiche « Secrets de signature non configures, skip. » et le .exe est publié **non signé**.

---

## 8. Modifications effectuées (pour les notes de release)

- **Installateur Windows** : passage à **Inno Setup 6** (fichier .exe) à la place du MSI WiX.
- **Comportement** : même installation par utilisateur (sans admin), même options (icône bureau, lancement au démarrage, lancement à la fin), même clés de registre.
- **Interface** : assistant en français, licence EULA (License.rtf), style d'assistant moderne.
- **Build** : script `installer\build_inno.ps1` (Flutter build windows + ISCC). La **version** est lue depuis **pubspec.yaml** à chaque build. Prérequis : [Inno Setup 6](https://jrsoftware.org/isinfo.php).
- **Site** : page téléchargement privilégie le .exe si présent dans les assets de la release GitHub.
- **Menu hamburger** : « Ouvrir offibox.fr » affiche « Fermer Offibox et aller sur Offibox.fr ? » ; sur Oui, l'app se ferme et le site s'ouvre dans le navigateur.
- **Erreur d'installation** : le fichier asset `logo APPEXokkk.jpg` (espace dans le nom) a été renommé en `logo_APPEXokkk.jpg` pour éviter l'erreur d'écriture lors de l'installation.

Vous pouvez copier/coller le bloc ci-dessus dans la description de la release GitHub.
