# Pages Offibox (login, inscription, validation) – GitHub Pages

Ce dossier contient les pages déployées sur **GitHub Pages** : **login**, **inscription**, **validation**, **démo**, etc. (iframes Wix, lien depuis l’app PC.)

## Déploiement

Les fichiers de `html/` sont copiés vers le build et déployés automatiquement à chaque push sur `main`/`master` (workflow `.github/workflows/pages.yml`).

### URL de base

- **Base** : `https://alexandreperrault.github.io/offibox/`
- **Pages HTML** : `https://alexandreperrault.github.io/offibox/html/`

### Activer GitHub Pages

1. Sur le dépôt GitHub : **Settings** → **Pages**.
2. **Source** : choisir **GitHub Actions** (pas "Deploy from a branch").
3. Après un push sur `main`/`master`, le workflow déploie ; le site est disponible sous quelques minutes.

### Vérifier

- `https://alexandreperrault.github.io/offibox/html/login-wix.html`
- `https://alexandreperrault.github.io/offibox/html/inscription.html`
- `https://alexandreperrault.github.io/offibox/html/validation.html`
- `https://alexandreperrault.github.io/offibox/html/demo-app-animation.html`

### Iframes Wix (snippets)

URL de base pour les iframes : `https://alexandreperrault.github.io/offibox/html/`

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

Modifiez les fichiers dans `website/pages/html/`, commitez et poussez sur `master`. Le workflow déploie automatiquement.

## Structure

```
website/pages/
  html/
    login-wix.html
    inscription.html
    validation.html
    demo-app-animation.html
    ...
  README.md
```
