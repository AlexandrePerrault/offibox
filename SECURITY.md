# Sécurité – Clé API Google exposée

Si une alerte Google Cloud indique qu’une clé API du projet **offibox-prod** a été trouvée en clair sur GitHub, suivez ces étapes.

## 1. Révoquer / régénérer la clé (prioritaire)

1. Ouvrez [Google Cloud Console](https://console.cloud.google.com/) → projet **offibox-prod**.
2. **APIs et services** → **Identifiants**.
3. Repérez la clé API concernée (celle mentionnée dans l’alerte).
4. **Révoquer** la clé ou la **supprimer**, puis **créer une nouvelle clé** pour l’usage Android/Firebase.
5. Dans **Firebase Console** → projet offibox-prod → **Paramètres du projet** → **Comptes de service** / configuration Android : **téléchargez à nouveau** `google-services.json` (il contiendra la nouvelle clé).
6. Remplacez localement `android/app/google-services.json` par ce fichier (ne plus le committer, voir ci‑dessous).

Cela coupe immédiatement l’usage de l’ancienne clé, même si elle reste visible dans l’historique Git.

## 2. Ne plus jamais committer le fichier

- Le fichier **`android/app/google-services.json`** est déjà dans **`.gitignore`**.
- Conservez **`android/app/google-services.json.example`** (sans vraie clé) pour documenter la structure.
- Chaque développeur doit obtenir son propre `google-services.json` depuis la console Firebase et le placer localement sans le pousser.

## 3. (Optionnel) Retirer le fichier de l’historique Git

L’ancienne clé restera visible dans les anciens commits tant que vous ne réécrivez pas l’historique. Si le dépôt est public et que vous voulez supprimer le fichier de tout l’historique :

- Utilisez [git-filter-repo](https://github.com/newren/git-filter-repo) ou [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) pour supprimer `android/app/google-services.json` de l’historique.
- Ensuite : `git push --force` (coordination avec toute l’équipe nécessaire).

**Important :** l’étape 1 (révocation / nouvelle clé) est suffisante pour sécuriser le projet ; l’étape 3 est un nettoyage pour ne plus exposer l’ancienne valeur dans l’historique.
