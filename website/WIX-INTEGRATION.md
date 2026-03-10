# Ouvrir les pages Offibox sous Wix

Pour afficher la page de connexion Offibox (ou validation) **dans** votre site Wix, il faut l’intégrer via une **iframe**.

## 1. Héberger les pages

Les pages doivent être accessibles via une URL publique, par exemple :

- **Filesusr** : `https://www-offibox-fr.filesusr.com/html/login-wix.html`
- ou un autre hébergeur (Netlify, Vercel, etc.) où vous uploadez le dossier `website/` (avec `login-wix.html`, `validation.html`, `js/`, etc.).

## 2. Dans l’éditeur Wix

1. Ouvrez votre site dans l’**éditeur Wix**.
2. Cliquez sur **Ajouter** (+) → **Intégrer** → **Code personnalisé** (ou **Embed** / **HTML iframe**).
3. Choisissez **Code personnalisé** (pas « Code du site »).
4. Collez un code de ce type (en remplaçant l’URL par la vôtre) :

```html
<iframe 
  src="https://www-offibox-fr.filesusr.com/html/login-wix.html" 
  width="100%" 
  height="700" 
  style="border: none; min-height: 700px;"
  title="Connexion Offibox">
</iframe>
```

5. Ajustez la **largeur** et la **hauteur** dans l’éditeur Wix si besoin (ou dans le `style`).
6. **Enregistrez** et **publiez** le site.

## 3. URLs utiles

| Page        | Exemple d’URL (à adapter selon votre hébergement)        |
|------------|----------------------------------------------------------|
| Connexion  | `https://www-offibox-fr.filesusr.com/html/login-wix.html` |
| Validation | `https://www-offibox-fr.filesusr.com/html/validation.html` |
| Inscription| `https://www-offibox-fr.filesusr.com/html/inscription.html` |

Remplacez `https://www-offibox-fr.filesusr.com/html/` par l’URL de base de votre hébergement si ce n’est pas Filesusr.

## 4. Connexion Google (Firebase) dans l’iframe

Si la page s’ouvre **dans une iframe Wix**, le navigateur peut utiliser l’**origine du site Wix** (ex. `https://votresite.wixsite.com/...` ou `https://www.offibox.fr` si c’est votre domaine Wix).

Il faut alors **autoriser cette origine** :

1. **Firebase Console** → projet offibox-prod → **Authentication** → **Settings** → **Authorized domains**  
   → Ajouter le domaine (ex. `votresite.wixsite.com` ou `www.offibox.fr`), **sans** `https://`.

2. **Google Cloud Console** → **Credentials** → client « Web client (auto created by Google Service) » (−cskk...)  
   → **Authorized JavaScript origins** → Ajouter l’origine complète (ex. `https://www.offibox.fr`).

Sans ça, la connexion Google peut afficher « Forbidden » ou « domaine non autorisé ».

## 5. Ouvrir en plein écran (sans iframe)

Si vous préférez que le clic sur un bouton Wix **ouvre la page de connexion dans un nouvel onglet** (et non dans la page) :

1. Dans Wix, ajoutez un **bouton** ou un **lien**.
2. Dans les paramètres du bouton, mettez comme lien :  
   `https://www-offibox-fr.filesusr.com/html/login-wix.html`  
   (ou votre URL).
3. Cochez **Ouvrir dans une nouvelle fenêtre** si l’option existe.

La page s’ouvrira alors en plein écran ; l’origine sera celle de l’hébergement (Filesusr, etc.), à autoriser dans Firebase et Google comme d’habitude.

## 6. Flux connexion / inscription → application web

Après connexion réussie (ou après inscription complétée), l’utilisateur est redirigé vers **l’application Offibox version web**, hébergée sur **GitHub Pages** :

- **URL de l’app web** : `https://alexandreperrault.github.io/offibox/`

- **Connexion avec Google**  
  - Si le client **n’est pas encore inscrit** → redirection vers **inscription.html** (compléter coordonnées), puis après validation → **app web Offibox**.  
  - Si le client **est déjà inscrit** → redirection directe vers **l’app web Offibox** (GitHub Pages).

- **Clic sur « Inscription »** (page d’accueil / login) → ouverture de **inscription.html** (même page que pour les nouveaux utilisateurs Google). Après soumission → **app web Offibox**.

- **Déjà connecté** : si un utilisateur déjà connecté se connecte à nouveau (Google ou e‑mail), il est renvoyé vers **l’app web Offibox**.

- **Connexion par e‑mail/mot de passe** (compte déjà créé) → redirection vers **l’app web Offibox**.

Ainsi, une fois connecté, l’utilisateur retrouve **exactement** l’application Offibox (version web hébergée sur GitHub).

## 7. Déploiement de l’app web (GitHub Pages)

L’application Flutter « version web » est construite et déployée automatiquement par le workflow **Deploy Offibox Web to GitHub Pages** (`.github/workflows/pages.yml`) à chaque push sur `main`.

- **Activer GitHub Pages** : dans le dépôt GitHub → **Settings** → **Pages** → **Source** : choisir **GitHub Actions**.
- **Domaine Firebase** : pour que la connexion fonctionne depuis l’app web, ajouter le domaine **`alexandreperrault.github.io`** dans Firebase Console → **Authentication** → **Authorized domains**, et dans Google Cloud Console → **Authorized JavaScript origins** : `https://alexandreperrault.github.io`.

## 8. Page offibox.fr/connected et barre déployée

La page **https://www.offibox.fr/connected** est une page de votre site Wix (offibox.fr). Vous pouvez y afficher la **barre déployée** (ou un iframe vers l’app web `https://alexandreperrault.github.io/offibox/`) pour les utilisateurs connectés.

- La **barre déployée** doit s’afficher **uniquement si la licence est active** (vérification côté Wix ou via votre logique métier / abonnement).
- La logique « licence active » et l’affichage conditionnel de la barre se gèrent **sur Wix** (ou via un script qui interroge votre backend), pas dans les pages hébergées (Netlify / login-wix, inscription, validation).
