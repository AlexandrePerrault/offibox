## Offibox v1.1.24

### Dernières modifications

- **Annuaire professionnels de santé** : clic sur l’adresse MSSanté ouvre Mailiz (connexion sécurisée) dans la page sous la barre, copie l’adresse du professionnel et affiche un message avec bouton « Fermer » pour envoyer un message sécurisé.
- **Annuaire** : pour une même personne, la profession « Médecin généraliste » est affichée en priorité avant « Ostéopathe » (ou autre).
- **Installateur Windows (MSI)** : correction des variables WiX (bannières) et des doublons dans le dialogue Options.
- **Export outils métier (Apps Script)** : 6 feuilles exportées vers GitHub avec retry en cas de conflit 409.
- **GitHub Pages** : workflow dédié avec concurrency pour limiter les annulations de déploiement.

### Site web / téléchargement

- Page **Téléchargement** : badge cliquable avec version lue depuis GitHub et détection Windows (10/11 · 64 bits) ; bandeau plateformes (Google Play, App Store) avec « Disponible prochainement ».
- **Connexion Google** : documentation des APIs à activer (People API, Google Calendar API) et des Authorized redirect URIs en cas d’erreur 403.
- **Flutter web** : connexion Google via `signInWithPopup` (Firebase Auth) pour éviter la dépréciation de `google_sign_in` sur le web.

