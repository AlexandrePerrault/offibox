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
     - `votre-projet.netlify.app` ou `votre-projet.vercel.app` (hébergement de préproduction).  
   - Pour tester en local : `localhost` est en général déjà autorisé.  
   - Enregistrer.

4. **Vérifier**  
   Ouvrir la page de connexion du site (ex. `https://www.offibox.fr/login.html`) et tester « Se connecter avec Google » et la connexion par e-mail. Si une erreur « unauthorized domain » apparaît, le domaine utilisé doit être exactement celui ajouté dans Authorized domains.

## Personnalisation

- **Logo** : déjà inclus dans `assets/icons/logo_offibox.png`.
- **Lien de téléchargement** : par défaut le site pointe vers GitHub Releases (`https://github.com/AlexandrePerrault/offibox/releases/latest`). Pour héberger le MSI vous-même, voir [docs/HEBERGEMENT_MSI.md](../docs/HEBERGEMENT_MSI.md).
