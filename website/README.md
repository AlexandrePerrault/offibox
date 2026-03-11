# Page d'accueil Offibox

Page d'accueil dynamique pour https://www.offibox.fr/.

## Utilisation avec Wix

### Option 1 : Recréer la page dans Wix
Utilisez le contenu de `index.html` comme référence pour créer les sections dans l'éditeur Wix :
- **Hero** : titre "La Boîte à Outils de l'Officine" + bouton de téléchargement
- **Le projet Offibox** : texte descriptif
- **Fonctionnalités** : grille de cartes (Recherche médicaments, Données à jour, Interface simple, Lancement au démarrage)
- **Tarif** : 29,90 €/mois
- **Qui sommes-nous** : texte
- **Aide & FAQ** : accordéon avec les questions fréquentes

### Option 2 : Intégrer via iframe
1. Hébergez ce dossier (Netlify, GitHub Pages, Vercel, etc.)
2. Dans Wix : Ajouter un élément → Intégrer → Code personnalisé
3. Collez : `<iframe src="https://votre-url.com" width="100%" height="800" frameborder="0"></iframe>`

### Téléchargement (quand l’app sera prête)
1. Dans Wix : Médias → Télécharger → uploadez le futur installateur (MSI ou EXE)
2. Cliquez sur le fichier → Obtenir le lien
3. Remplacez l'attribut `href` du bouton de téléchargement par ce lien

## Structure des fichiers

```
website/
├── index.html           # Page complète (HTML/CSS/JS)
├── assets/icons/
│   └── logo_offibox.png
└── README.md
```

## Connexion (Firebase Auth)

Le site utilise **Firebase Authentication** (même projet que l’app Flutter) pour une vraie connexion côté web :

- **login.html** : connexion Google (avec scope Calendrier en lecture) ou email/mot de passe ; inscription et « Mot de passe oublié ».
- **autorisation-agenda.html** : accessible uniquement si connecté ; propose de continuer vers le téléchargement (l’agenda Google est déjà autorisé si connexion Google).
- **telecharger.html** : affiche l’email connecté et un lien « Se déconnecter ».

La config web est dans `js/firebase-config.js` (alignée sur `lib/firebase_options.dart`).

### Marche à suivre : configurer Firebase pour le site web

1. **Ouvrir la console Firebase**  
   Aller sur [https://console.firebase.google.com/](https://console.firebase.google.com/) et sélectionner le projet **offibox-prod**.

2. **Activer les méthodes de connexion**  
   - Menu de gauche : **Build** → **Authentication** (ou **Authentification**).  
   - Onglet **Sign-in method** (Méthode de connexion).  
   - **Google** : cliquer sur la ligne → activer **Enable** (Activer) → enregistrer.  
   - **E-mail/Password** : cliquer sur la ligne → activer **Enable** (Activer) → enregistrer.

3. **Ajouter le domaine du site (Authorized domains)**  
   - Dans Authentication : onglet **Settings** (Paramètres) ou **Settings** en haut à droite.  
   - Section **Authorized domains** (Domaines autorisés).  
   - Cliquer sur **Add domain** (Ajouter un domaine).  
   - Saisir le domaine exact utilisé par le site, **sans** `https://` ni chemin, par exemple :  
     - `www.offibox.fr`  
     - `offibox.fr` (si le site est servi à la racine)  
     - `alexandreperrault.github.io` (GitHub Pages) ou autre hébergeur de préproduction.  
   - Pour tester en local : `localhost` est en général déjà autorisé.  
   - Enregistrer.

4. **Corriger l’erreur « 400 : redirect_uri_mismatch » (connexion Google)**  
   Cette erreur signifie que l’URL de redirection utilisée par Google ne figure pas dans la liste autorisée du client OAuth. À faire dans **Google Cloud Console** (le projet lié à Firebase est le même) :  
   - Aller sur [https://console.cloud.google.com/](https://console.cloud.google.com/).  
   - Sélectionner le projet **offibox-prod** (ou celui de votre Firebase).  
   - Menu **APIs & Services** → **Credentials** (Identifiants).  
   - Ouvrir le client OAuth 2.0 de type **Web application** utilisé par Firebase (souvent nommé « Web client (auto created by Google Service) » ou similaire).  
   - Dans **Authorized redirect URIs**, ajouter **exactement** :  
     - `https://offibox-prod.firebaseapp.com/__/auth/handler`  
   - Dans **Authorized JavaScript origins**, ajouter l’**origine** de votre site (sans chemin), par exemple :  
     - `https://www.offibox.fr`  
     - `https://offibox.fr`  
     - ou `http://localhost:5500` / `http://127.0.0.1:5500` si vous testez en local (adapter le port si besoin).  
   - Enregistrer. Attendre quelques minutes puis réessayer la connexion Google.

5. **Vérifier**  
   Ouvrir la page de connexion du site (ex. `https://www.offibox.fr/login.html`) et tester « Se connecter avec Google » et la connexion par e-mail. Si une erreur « unauthorized domain » apparaît, le domaine utilisé doit être exactement celui ajouté dans Authorized domains (Firebase). Si « redirect_uri_mismatch » persiste, vérifier que l’origine utilisée (barre d’adresse du navigateur) est bien ajoutée dans **Authorized JavaScript origins** et que `https://offibox-prod.firebaseapp.com/__/auth/handler` est bien dans **Authorized redirect URIs**.

6. **Erreur « Forbidden » (403) à la connexion Google**  
   Après « Se connecter avec Google », le site redirige vers `/` (page d’accueil). Si vous voyez **Forbidden** :

   **À vérifier en priorité (domaine = celui affiché dans la barre d’adresse quand vous cliquez sur « Se connecter avec Google ») :**

   - **Firebase Console** (projet offibox-prod) → **Authentication** → **Settings** → **Authorized domains**  
     → Ajouter **les deux** : `www.offibox.fr` et `offibox.fr` (sans `https://` ni `/`). Si vous testez en aperçu Wix, ajouter aussi le domaine d’aperçu (ex. `preview.wix.com` ou l’URL exacte sans préfixe).

   - **Google Cloud Console** (projet offibox-prod) → **APIs & Services** → **Credentials** → ouvrir le client OAuth 2.0 **Web** (créé par Firebase) :  
     → **Authorized JavaScript origins** : ajouter **exactement** (avec `https://`) :  
       - `https://www.offibox.fr`  
       - `https://offibox.fr`  
       (et en test : `http://localhost:PORT` si besoin).  
     → **Authorized redirect URIs** : doit contenir **exactement** :  
       - `https://offibox-prod.firebaseapp.com/__/auth/handler`  
     Enregistrer et attendre 2–5 minutes avant de retester.

   - **Si la page de connexion est dans une iframe Wix** : l’origine peut être celle du site Wix (ex. `https://www.wix.com` ou votre domaine Wix). Ajouter cette origine dans **Authorized JavaScript origins** (Google) et dans **Authorized domains** (Firebase) si différente de `www.offibox.fr`.

   - **Pour localiser le 403** : F12 → onglet **Network** (Réseau) → lancer la connexion Google → repérer la requête en rouge (403). Si l’URL contient `google.com` ou `firebaseapp.com`, le problème vient des domaines/origins ci‑dessus. Si l’URL est votre site (ex. `www.offibox.fr`), le 403 vient du serveur (Wix/hébergeur) qui refuse la requête ou la page.

### E-mails en français (vérification et mot de passe)

Les modèles d’e-mail Firebase (validation d’e-mail, réinitialisation du mot de passe) ne permettent pas de modifier le corps du message. Pour que vos clients reçoivent des e-mails en français :

1. **Cloud Functions** : Les fonctions `sendVerificationEmailFr` et `sendPasswordResetEmailFr` (dans `functions/src/emails.ts`) envoient des e-mails en français. Déployer les functions : `cd functions && npm run build && firebase deploy --only functions`.
2. **SMTP** : Comme les autres e-mails Offibox, l’envoi passe par votre SMTP (variables d’environnement `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`) ou par l’extension Firebase « Trigger Email » (collection `mail`).
3. **Site web** : La page `login-wix.html` appelle déjà `sendPasswordResetEmailFr` pour l’inscription et le « Mot de passe oublié » si le SDK Firebase Functions est chargé. Vérifier que le script `firebase-functions-compat.js` est bien inclus.

## Personnalisation

- **Logo** : déjà inclus dans `assets/icons/logo_offibox.png`.
- **Lien de téléchargement** : par défaut le site pointe vers GitHub Releases (`https://github.com/AlexandrePerrault/offibox/releases/latest`). Pour héberger le MSI vous-même, voir [docs/HEBERGEMENT_MSI.md](../docs/HEBERGEMENT_MSI.md).
