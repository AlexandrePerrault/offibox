# Mise à jour de la version et diffusion du MSI

## 1. La version change bien au build MSI

Oui. La version affichée dans l’app et utilisée pour les mises à jour vient de **`pubspec.yaml`** (ligne `version:`).

- Avant chaque nouveau build de release, **monte la version** dans `pubspec.yaml` (ex. `1.1.02+1` → `1.1.03+2`).
- Quand tu fais un build Windows puis que tu génères le MSI, cette version est prise en compte (Flutter injecte `FLUTTER_VERSION_*` dans le build Windows).
- L’app lit cette version au runtime via `package_info_plus` et la compare à la release GitHub pour proposer la MAJ.

## 2. Où déposer le fichier MSI

Le dépôt prévu est **GitHub Releases** du dépôt **`AlexandrePerrault/offibox`**.

1. Va sur : **https://github.com/AlexandrePerrault/offibox/releases**
2. Crée une **nouvelle release** (ou édite la dernière si tu veux que ce soit la “latest”).
3. **Tag** : utilise un tag de version, par ex. **`v1.1.03`** (le `v` est optionnel, l’app le gère).
4. **Titre / description** : tu peux mettre le numéro de version et les changements.
5. **Fichiers (Assets)** : glisse-dépose ou uploade ton **fichier `.msi`** (ex. `Offibox-1.1.03.msi` ou comme sorti par ton outil de build).
6. Publie la release.

L’app ne regarde que la release marquée **“Latest release”** et cherche un asset dont l’URL se termine par **`.msi`**. Dès qu’un tel asset est présent sur la dernière release, il sera proposé aux clients.

## 3. Comment le client récupère la dernière MAJ depuis le site

- **Côté site web** : tu peux mettre un lien “Télécharger Offibox” qui pointe vers la dernière release, par exemple :
  - **https://github.com/AlexandrePerrault/offibox/releases/latest**  
  Le client ouvre la page et télécharge le `.msi` manuellement.

- **Depuis l’application déjà installée** :
  - Au démarrage (Windows), l’app appelle **`https://api.github.com/repos/AlexandrePerrault/offibox/releases/latest`**.
  - Elle compare le **tag** de cette release (ex. `v1.1.03`) avec la **version installée** (celle de `pubspec.yaml` au moment du build).
  - Si la version sur GitHub est **strictement plus récente** et qu’un asset **`.msi`** est présent, l’app propose : *« Nouvelle version disponible (X.Y.Z). Installer maintenant ? »*.
  - La vérification est faite **au plus une fois par jour** (sauf si l’utilisateur a coché “Ne plus me demander”, auquel cas une vérification forcée peut déclencher le téléchargement direct).
  - Si l’utilisateur accepte, l’app **télécharge** le `.msi` (dans Téléchargements ou dossier temporaire) et **ouvre** le fichier pour lancer l’installateur.

En résumé : **déposer le MSI en asset de la dernière release GitHub** suffit pour que les clients reçoivent la proposition de MAJ dans l’app et pour que le “site” (page GitHub releases/latest) permette de récupérer la dernière version.
