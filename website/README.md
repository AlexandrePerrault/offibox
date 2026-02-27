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

## Personnalisation

- **Logo** : déjà inclus dans `assets/icons/logo_offibox.png`.
- **Lien de téléchargement** : modifiez l'attribut `href` du bouton `.btn-download` avec l'URL réelle du fichier une fois l'installateur disponible.
