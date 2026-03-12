# Bandeau « Sources officielles » — pourquoi les icônes ne s'affichent plus

## Cause

Les icônes du bandeau (Wix ou `login-wix-bandeau.html`) pointent vers :

- **Wix bandeau** : `https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/icons/...`
- **login-wix-bandeau** : `window.OFFIBOX_BANDEAU_BASE` → ex. `https://raw.githubusercontent.com/AlexandrePerrault/offibox/refactor/search-engine` puis `.../assets/icons/...`

Ces URLs renvoient **404** si :

- le dépôt **offiboxdata** est **privé** (GitHub renvoie 404 pour les raw de dépôts privés) ;
- la branche **icons** n’existe pas ou les fichiers ne sont pas à la racine ;
- la branche **refactor/search-engine** du dépôt offibox n’existe plus ou n’a pas `assets/icons/`.

## Solution

Faire servir les icônes depuis une URL **publique** que tu contrôles.

1. **Option recommandée : ton site (offibox.fr)**  
   - Héberger les icônes sur ton site, par ex. :  
     `https://www.offibox.fr/assets/icons/`  
   - Les fichiers sont déjà dans le projet : `assets/icons/` (BDPM.jpeg, assurance maladie.svg, logo-has.png, etc.).  
   - Les copier (ou déployer) dans un dossier exposé sur offibox.fr, par ex. `/assets/icons/`.

2. **Option : dépôt GitHub public**  
   - Rendre le dépôt **offiboxdata** public et créer une branche **icons** avec les icônes à la racine, **ou**  
   - Exposer les icônes depuis le dépôt **offibox** (branche utilisée pour GitHub Pages) dans `assets/icons/` et utiliser l’URL raw de cette branche.

3. **Dans le bandeau**  
   - Utiliser une **URL de base** configurable (voir ci‑dessous) et la définir sur l’URL qui sert vraiment les icônes (ex. `https://www.offibox.fr/assets/icons/`).

## Fichiers concernés

- **Bandeau Wix** (code à coller dans Wix) : `website/wix-bandeau-sources-officielles.html`
- **Page bandeau seule** (avec choix de l’URL de base) : `website/login-wix-bandeau.html`

## URL du fichier login-wix-bandeau.html

- **Dans le projet** : `website/login-wix-bandeau.html`  
- **Chemin local** : `C:\Users\perra\Documents\projets_flutter\offibox\website\login-wix-bandeau.html`  
- **Une fois le site déployé** (ex. sur offibox.fr ou GitHub Pages), l’URL sera du type :  
  - `https://www.offibox.fr/website/login-wix-bandeau.html`  
  - ou `https://alexandreperrault.github.io/offibox-web/website/login-wix-bandeau.html`  
  selon où est hébergé le dossier `website/`.

Dans `login-wix-bandeau.html`, la variable **`window.OFFIBOX_BANDEAU_BASE`** en haut du fichier doit pointer vers l’URL de base où sont accessibles les dossiers `assets/icons/` (sans `/assets/icons/` à la fin). Exemple : `https://www.offibox.fr` si les icônes sont en `https://www.offibox.fr/assets/icons/BDPM.jpeg`, etc.
