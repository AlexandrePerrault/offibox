# Mises à jour sans GitHub (dépôt privé)

Pour que les clients téléchargent la dernière version (ex. V1.1.xx) **sans avoir accès à GitHub**, tu peux mettre le dépôt **offibox** en privé et héberger toi-même la version + le fichier d’installation.

## 1. Fichier `latest.json` sur ton site

L’app interroge l’URL configurée dans `lib/constants/app_update_config.dart` :

- **`customLatestVersionUrl`** = `https://offibox.fr/download/latest.json`

Sur ton serveur (offibox.fr), mets un fichier **`/download/latest.json`** avec le contenu suivant (à mettre à jour à chaque release) :

```json
{
  "version": "1.1.26",
  "download_url": "https://offibox.fr/download/Offibox-Setup-1.1.26.exe"
}
```

- **version** : numéro de la dernière version (sans le `v`).
- **download_url** : lien direct de téléchargement du .exe (ou .msi).

## 2. Héberger le .exe

À chaque release :

1. Tu génères l’installateur (ex. `.\installer\build_inno.ps1`).
2. Tu déposes **Offibox-Setup-X.Y.Z.exe** dans le dossier `/download/` de ton site (ou sur ton CDN).
3. Tu mets à jour **`latest.json`** avec cette version et l’URL du .exe.

Les clients n’ont jamais besoin d’aller sur GitHub : l’app lit `latest.json`, compare la version, et propose le téléchargement vers `download_url`.

## 3. Dépôts à mettre en privé

| Dépôt        | Rôle                          | Privé ? |
|-------------|--------------------------------|--------|
| **offiboxdata** | Données (CSV, listes)         | Oui (déjà fait) |
| **offibox**     | Code app Windows + workflow Release | Oui possible : les MAJ passent par offibox.fr |
| **offibox-web** | **Version web embarquée** de l’app pour les clients (GitHub Pages) | **Garder en public** : sinon les clients ne peuvent pas ouvrir l’app web sans compte GitHub. Privé uniquement si tu héberges la même version sur offibox.fr (ou ailleurs). |

## 4. Historique des versions (menu hamburger)

L’onglet « Historique des versions » charge aujourd’hui les releases depuis l’API GitHub. Si **offibox** est privé, cet appel échouera et l’historique ne s’affichera pas (ou sera vide). Pour l’instant il n’y a pas de source alternative ; tu peux documenter les versions sur ta page offibox.fr si besoin.

## 5. Désactiver l’URL custom (revenir à GitHub)

Pour revenir aux releases GitHub (dépôt public), vide `customLatestVersionUrl` dans `app_update_config.dart` :

```dart
static const String customLatestVersionUrl = '';
```

L’app utilisera à nouveau `https://api.github.com/repos/.../releases/latest`.
