# Connexion directe depuis l’app PC vers le site

Quand l’utilisateur clique sur **« Ouvrir offibox.fr »** dans le menu hamburger de l’app Windows, une boîte de dialogue propose **« Fermer Offibox ? »** (Oui / Non). Si l’utilisateur choisit **Oui**, la barre se ferme et le navigateur s’ouvre sur la page d’accueil du site.

## Connexion automatique sur le site (optionnel)

Si l’utilisateur est **déjà connecté dans l’app PC**, l’app peut ouvrir le site avec un paramètre d’URL pour permettre une **connexion directe sur le site** sans ressaisir identifiants.

- **Paramètre** : `app_login_token`
- **Valeur** : le **Firebase ID Token** (JWT) de l’utilisateur courant, récupéré via `FirebaseAuth.instance.currentUser.getIdToken()`.

Exemple d’URL ouverte par l’app quand l’utilisateur est connecté :

```
https://offibox.fr?app_login_token=eyJhbGciOiJSUzI1NiIs...
```

### Côté site (à implémenter)

Pour que l’utilisateur soit connecté automatiquement sur le site :

1. **Détecter** la présence de `app_login_token` dans l’URL (query string).
2. **Vérifier** le token côté serveur avec le **Firebase Admin SDK** (vérification du JWT Firebase).
3. Si le token est valide : **créer une session** (ou connecter Firebase Auth côté web avec ce token) et **rediriger** vers la page d’accueil sans le paramètre (pour ne pas laisser le token dans l’historique).

Sécurité : ne pas faire confiance au token côté client seul ; la vérification doit être faite côté backend (Firebase Admin SDK).

### Référence dans l’app

- Fichier : `lib/window/offibox_window.dart`
- Méthode : `_launchOffiboxWithOptionalToken()`
- Constante (privée) : `_kAppLoginTokenParam = 'app_login_token'`
