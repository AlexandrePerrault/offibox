# Déployer les pages Offibox (Netlify) pour les iframes Wix

Ce dossier contient les 3 pages à héberger pour les iframes Wix : **login**, **inscription**, **validation**.

## Structure

```
deploy-netlify/
  html/
    login-wix.html
    inscription.html
    validation.html
  README.md  (ce fichier)
```

## Étapes Netlify

1. **Compte** : allez sur [app.netlify.com](https://app.netlify.com) et connectez-vous (ou créez un compte gratuit).
2. **Nouveau site** : **Add new site** → **Deploy manually**.
3. **Upload** : glissez-déposez **tout le dossier `deploy-netlify`** (ou seulement le contenu : dossier `html` + ce README) dans la zone « Drag and drop your site output folder ».
4. **URL** : Netlify vous donne une URL du type `https://quelque-chose-123.netlify.app`.
5. **Vérifier** : ouvrez dans le navigateur :
   - `https://VOTRE-SITE.netlify.app/html/login-wix.html`
   - `https://VOTRE-SITE.netlify.app/html/inscription.html`
   - `https://VOTRE-SITE.netlify.app/html/validation.html`

## Mettre à jour les iframes dans Wix

Dans l’éditeur Wix, pour chaque **embed / code personnalisé** qui affiche une de ces pages, remplacez l’URL de base :

- **Avant** : `https://www-offibox-fr.filesusr.com/html/`
- **Après** : `https://VOTRE-SITE.netlify.app/html/`

### Snippets iframe à coller dans Wix

**Connexion :**
```html
<iframe 
  src="https://VOTRE-SITE.netlify.app/html/login-wix.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Connexion Offibox">
</iframe>
```

**Inscription :**
```html
<iframe 
  src="https://VOTRE-SITE.netlify.app/html/inscription.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Inscription Offibox">
</iframe>
```

**Validation (après connexion) :**
```html
<iframe 
  src="https://VOTRE-SITE.netlify.app/html/validation.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Validation Offibox">
</iframe>
```

Remplacez `VOTRE-SITE` par le sous-domaine réel donné par Netlify (ex. `offibox-pages` → `https://offibox-pages.netlify.app`).

## Firebase / Google

Pensez à ajouter le domaine Netlify dans :

- **Firebase Console** → Authentication → Authorized domains : `VOTRE-SITE.netlify.app`
- **Google Cloud Console** → Credentials → Authorized JavaScript origins : `https://VOTRE-SITE.netlify.app`

## Mises à jour ultérieures

Après modification des fichiers dans `website/`, recopiez-les dans `deploy-netlify/html/` puis refaites un **Deploy** sur Netlify (glisser-déposer à nouveau le dossier ou déployer via Git si vous avez connecté le dépôt).
