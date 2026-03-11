# Connexion par e-mail (sans Gmail)

## Flux inscription / téléchargement

1. **Page d'inscription** : le client saisit son e-mail (et optionnellement pharmacie, adresse).
2. **Réception du mail** : Firebase envoie un e-mail avec un lien pour **définir le mot de passe**.
3. **Page « Définir votre mot de passe »** (`definir-mot-de-passe.html`) : le client ouvre le lien, saisit un **nouveau mot de passe** et **confirme le mot de passe**, puis valide.
4. **Authentification** : après succès, le client peut **se connecter** (e-mail + mot de passe) sur la page de connexion.
5. **Redirection** : une fois connecté, redirection vers Offibox (web GitHub Pages ou ouverture de l’appli avec **Ouvrir l’application Offibox** → schéma `offibox://`).

## Configuration Firebase (lien « définir mot de passe »)

Pour que le lien dans l’e-mail pointe vers **notre** page (avec champ « Confirmer le mot de passe ») :

1. **Firebase Console** → projet **offibox-prod** → **Authentication** → **Templates**.
2. Onglet **Password reset** (Réinitialisation du mot de passe).
3. **Personnaliser l’URL d’action** (Customize action URL) :
   - En production (ex. offibox.fr) : `https://www.offibox.fr/website/definir-mot-de-passe.html` (ou le chemin réel de la page sur votre domaine).
   - Sur GitHub Pages : `https://alexandreperrault.github.io/offibox/website/definir-mot-de-passe.html`
4. Enregistrer. Les prochains e-mails de réinitialisation utiliseront cette URL ; les paramètres `oobCode` et `mode=resetPassword` seront ajoutés par Firebase.

## Client déjà connecté (appli desktop)

Si le client a déjà une session (connecté une fois), l’appli démarre **sans demander de connexion**. À côté de la date de mise à jour dans la barre, s’affiche **« licence jusqu'au JJ/MM/AAAA »** (date de fin d’essai ou de licence).
