# Connexion Google : erreur Forbidden (403) ou auth/unauthorized-domain

Si « Se connecter avec Google » affiche **Forbidden**, **403** ou **auth/unauthorized-domain** (« This domain is not authorized for OAuth operations »), c’est un problème de **domaine non autorisé**. Firebase et Google Cloud ont chacun leur liste : il faut ajouter le domaine **aux deux** endroits.

## 1. Firebase Console (obligatoire pour auth/unauthorized-domain)

L’erreur **auth/unauthorized-domain** vient de Firebase : le domaine doit être dans la liste Firebase en premier.

1. Ouvrir [Firebase Console](https://console.firebase.google.com/) → projet **offibox-prod** (ou le vôtre).
2. **Authentication** → **Settings** (Paramètres) → **Authorized domains**.
3. Cliquer **Add domain** et ajouter **exactement** le domaine (hôte) de la page où vous testez, **sans** `https://` ni `/` :
   - `www.offibox.fr`
   - `offibox.fr`
   - En local : `localhost`
   - Si la page est hébergée ailleurs (ex. Wix / Filesusr) : le domaine affiché dans la barre d’adresse, ex. `9c9b84dd-79d4-485b-a108-d0c1cb04c969.filesusr.com`.
4. Enregistrer. Attendre 1–2 minutes puis retester.

## 2. Google Cloud Console (origines JavaScript + redirect)

1. Ouvrir [Google Cloud Console](https://console.cloud.google.com/) → **même projet** que Firebase.
2. **APIs & Services** → **Credentials**.
3. Ouvrir le client **OAuth 2.0** de type **Web application** (souvent « Web client (auto created by Google Service) »).
4. **Authorized JavaScript origins** : ajouter l’**origine exacte** (avec `https://` ou `http://`), par ex. :
   - `https://www.offibox.fr`
   - `https://offibox.fr`
   - En local : `http://localhost:5500` (adapter le port).
5. **Authorized redirect URIs** : doit contenir **exactement** :
   - `https://offibox-prod.firebaseapp.com/__/auth/handler`  
   (remplacer `offibox-prod` par l’ID de votre projet Firebase si différent.)
6. **Save**. Attendre 2–5 minutes avant de retester.

## 3. Vérifier l’origine réelle

L’origine = ce qui s’affiche dans la barre d’adresse **au moment du clic** sur « Se connecter avec Google » (sans le chemin, sans le `?`).  
Exemple : si l’URL est `https://www.offibox.fr/login-wix.html`, l’origine est `https://www.offibox.fr`.  
Cette valeur doit être présente à la fois dans **Firebase Authorized domains** (sans `https://`) et dans **Google Authorized JavaScript origins** (avec `https://`).

## 4. Si la page est dans une iframe (ex. Wix)

L’origine peut être celle du site parent (ex. `https://www.wix.com` ou votre domaine Wix). Dans ce cas, ajouter **cette** origine dans les deux consoles (Firebase + Google), pas seulement `www.offibox.fr`.

## 5. Message d’erreur dans la page

Si votre fichier HTML n’affiche pas encore un message explicite en cas de Forbidden, vous pouvez ajouter dans le `catch` du clic Google :

```javascript
} else if (err && (err.code === 'auth/unauthorized-domain' || (err.message && (err.message.toLowerCase().indexOf('forbidden') !== -1 || err.message.indexOf('403') !== -1)))) {
  msg = 'Erreur Forbidden : vérifiez Firebase (Authorized domains) et Google Cloud (Authorized JavaScript origins + redirect URI). Voir CONNEXION_GOOGLE_FORBIDDEN.md ou README.md.';
}
```

Voir aussi la section « Erreur Forbidden (403) » dans `README.md`.
