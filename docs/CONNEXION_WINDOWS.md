# Connexion Windows (auth page + offibox://)

Ce document décrit le flux **Connexion Windows** : authentification via le site offibox.fr puis retour dans l’app desktop via le schéma d’URL `offibox://`.

## Vue d’ensemble

1. **Page d’auth (site)**  
   L’utilisateur se connecte sur https://www.offibox.fr/ (ou une page dédiée). Après connexion réussie, le site redirige le navigateur vers une URL du type `offibox://auth/callback?...`.

2. **Parsing `offibox://` dans l’app**  
   Windows ouvre l’app Offibox avec cette URL (une seule instance : si l’app est déjà ouverte, l’URL lui est transmise et la fenêtre est ramenée au premier plan). L’app parse l’URL et exécute la connexion Firebase correspondante.

## Formats d’URL supportés

| URL | Usage |
|-----|--------|
| `offibox://auth/callback?token=XXX` | **Custom token** Firebase. Le serveur (ex. Cloud Function) génère un custom token et le site redirige avec ce paramètre. L’app appelle `FirebaseAuth.instance.signInWithCustomToken(token)`. |
| `offibox://auth/callback?id_token=XXX&access_token=YYY` | **OAuth (ex. Google)**. Le site récupère l’ID token (et optionnellement l’access token) puis redirige. L’app utilise `GoogleAuthProvider.credential(idToken:, accessToken:)` puis `signInWithCredential`. |

## Côté app (Flutter)

- **Enregistrement du schéma**  
  Au démarrage, sur Windows, l’app enregistre le protocole `offibox` via le plugin `protocol_handler` (`main.dart`).

- **Une seule instance**  
  Dans `windows/runner/main.cpp`, si une fenêtre Offibox existe déjà, le second lancement (ex. clic sur `offibox://...`) envoie l’URL à cette fenêtre via `DispatchToProtocolHandler(hwnd)` puis quitte ; la fenêtre existante reçoit l’URL et la traite.

- **Parsing et auth**  
  - `lib/auth/offibox_protocol_handler.dart` : parse `offibox://...` et appelle Firebase (`signInWithCustomToken` ou `signInWithCredential` selon les paramètres).
  - `lib/auth/offibox_protocol_listener_wrapper.dart` : écoute les URLs reçues (mixin `ProtocolListener`) et appelle `OffiboxProtocolHandler.handleUrl(url)`.

- **Page de connexion dans l’app**  
  La page de login in-app est `lib/auth/login_page.dart` (e-mail/mot de passe, option Google selon la plateforme). Sur Windows, la connexion peut aussi se faire entièrement via le site puis `offibox://auth/callback`, sans ressaisir les identifiants dans l’app.

## Côté site (offibox.fr)

À implémenter côté web :

1. Après connexion réussie (e-mail, Google, Microsoft, etc.), récupérer soit :
   - un **custom token** Firebase (généré par votre backend/Cloud Function), soit  
   - un **ID token** (et éventuellement access token) OAuth.
2. Rediriger le navigateur vers :
   - `offibox://auth/callback?token=<custom_token>`  
   ou  
   - `offibox://auth/callback?id_token=<id_token>&access_token=<access_token>` (optionnel).
3. L’utilisateur doit avoir l’app Offibox installée ; Windows associe le schéma `offibox` à l’exécutable (enregistré par le plugin à l’installation/premier lancement).

## Résumé des fichiers modifiés/ajoutés

| Fichier | Rôle |
|--------|------|
| `windows/runner/main.cpp` | Détection instance existante + `DispatchToProtocolHandler` pour envoyer l’URL à la fenêtre ouverte. |
| `lib/main.dart` | Enregistrement du protocole `offibox` (Windows). |
| `lib/app/offibox_app.dart` | Wrapper `OffiboxProtocolListenerWrapper` sur la route initiale pour écouter les URLs. |
| `lib/auth/offibox_protocol_handler.dart` | Parsing `offibox://auth/callback` et sign-in Firebase. |
| `lib/auth/offibox_protocol_listener_wrapper.dart` | Widget qui enregistre un `ProtocolListener` et appelle le handler. |

## Dépendance

- `protocol_handler: ^0.2.0` (enregistrement du schéma + réception des URLs sur Windows).
