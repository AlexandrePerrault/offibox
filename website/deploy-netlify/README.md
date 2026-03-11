# Déployer les pages Offibox (login, inscription, validation) pour iframes Wix

Ce dossier contient les pages à héberger : **login**, **inscription**, **validation**, **démo**, etc.

## Option recommandée : GitHub Pages (gratuit)

Les fichiers de `html/` sont déployés automatiquement sur **GitHub Pages** à chaque push sur `main`/`master` (workflow `.github/workflows/pages.yml`). Aucun coût, aucun compte Netlify nécessaire.

### URL de base (une fois Pages activé)

- **Base** : `https://alexandreperrault.github.io/offibox/`
- **Pages HTML** : `https://alexandreperrault.github.io/offibox/html/`

### Activer GitHub Pages

1. Sur le dépôt GitHub : **Settings** → **Pages**.
2. **Source** : choisir **GitHub Actions** (pas "Deploy from a branch").
3. Après un push sur `main`, le workflow déploie ; le site est disponible sous quelques minutes.

### Vérifier

- `https://alexandreperrault.github.io/offibox/html/login-wix.html`
- `https://alexandreperrault.github.io/offibox/html/inscription.html`
- `https://alexandreperrault.github.io/offibox/html/validation.html`
- `https://alexandreperrault.github.io/offibox/html/demo-app-animation.html`

### Iframes Wix (snippets)

Remplacez l’URL de base dans vos iframes par : `https://alexandreperrault.github.io/offibox/html/`

**Connexion :**
```html
<iframe 
  src="https://alexandreperrault.github.io/offibox/html/login-wix.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Connexion Offibox">
</iframe>
```

**Inscription :**
```html
<iframe 
  src="https://alexandreperrault.github.io/offibox/html/inscription.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Inscription Offibox">
</iframe>
```

**Validation :**
```html
<iframe 
  src="https://alexandreperrault.github.io/offibox/html/validation.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Validation Offibox">
</iframe>
```

### Firebase / Google

Ajoutez le domaine GitHub Pages dans :

- **Firebase Console** → Authentication → Authorized domains : `alexandreperrault.github.io`
- **Google Cloud Console** → Credentials → Authorized JavaScript origins : `https://alexandreperrault.github.io`

### Mises à jour

Modifiez les fichiers dans `deploy-netlify/html/`, commitez et poussez sur `main`. Le workflow déploie automatiquement.

---

## Alternative : Netlify

Si vous préférez Netlify (manuel ou connecté au dépôt) :

1. [app.netlify.com](https://app.netlify.com) → **Add new site** → **Deploy manually**.
2. Glissez-déposez le contenu de `deploy-netlify` (dossier `html` + README).
3. URL type : `https://VOTRE-SITE.netlify.app/html/...`
4. Dans Firebase / Google, ajoutez `VOTRE-SITE.netlify.app` en domaine autorisé.

## Structure

```
deploy-netlify/
  html/
    login-wix.html
    inscription.html
    validation.html
    demo-app-animation.html
    ...
  README.md
```
