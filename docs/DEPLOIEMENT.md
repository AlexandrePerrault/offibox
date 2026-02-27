# Déploiement Offibox

*(Scripts et dossiers d’installation MSI/EXE ont été retirés tant que l’app n’est pas finalisée. À réintégrer plus tard.)*

## Où stocker le dossier Offibox ?

### Sur la machine de l’utilisateur (installation)

| Emplacement | Usage recommandé |
|-------------|------------------|
| `C:\Program Files\Offibox\` | Installation classique (nécessite droits admin) |
| `%LOCALAPPDATA%\Offibox\` | Installation par utilisateur, sans admin (recommandé) |

**Recommandation** : utiliser `%LOCALAPPDATA%\Offibox\` pour une installation simple sans droits administrateur. Exemple :  
`C:\Users\<user>\AppData\Local\Offibox\`

### Projet source (développement)

Le projet Flutter peut rester où vous le développez, par exemple :
- `C:\Users\<user>\Documents\projets_flutter\offibox\`

### Releases (publication)

Les mises à jour sont récupérées depuis **GitHub Releases** du dépôt configuré dans `lib/constants/app_update_config.dart` :

- Repo par défaut : `AlexandrePerrault/offibox`
- Pour publier une nouvelle version :
  1. Créer une release sur GitHub avec un tag (ex. `v1.0.1`)
  2. Joindre le fichier `.exe` Windows en asset
  3. L’app vérifiera automatiquement une fois par jour au démarrage

---

## Mises à jour automatiques

- Vérification : **1 fois par jour** au démarrage de l’app
- Source : API GitHub Releases
- Téléchargement : dans le dossier Téléchargements de l’utilisateur
- L’utilisateur lance l’installer manuellement après téléchargement
