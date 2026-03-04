# Connexion première fois (app + web)

## 1. Installateur MSI (Setup)

- **Logo pendant le chargement**  
  L’installateur doit afficher le logo Offibox pendant la progression (bannière et/ou image de fond des dialogues WiX). Voir `installer/README.md` et `installer/wix/Resources/`.

- **Options à proposer (toutes cochables par défaut)**  
  - Créer une icône sur le bureau  
  - Lancer Offibox au démarrage de Windows (recommandé)  
  - Lancer Offibox (à la fin de l’installation)  

  L’app lit déjà `HKCU\Software\Offibox\LaunchAtStartup` au premier lancement après install pour activer le démarrage automatique.

---

## 2. Première connexion dans l’application

- **Fenêtre de connexion**  
  Au premier lancement après installation, afficher une fenêtre de connexion avec :
  - Connexion avec **Google**, ou  
  - Connexion avec **e-mail et mot de passe** (création de mot de passe par e-mail si inscription).  

  Implémentation actuelle : `LoginPage` (Google + e-mail/mot de passe). Si l’utilisateur est déjà connecté (session Firebase), `AuthGate` affiche directement `FirstLaunchCheck` puis la fenêtre principale : **pas de reconnexion demandée**.

---

## 3. Première connexion sur la page web (connexion Windows)

Pour un client qui se connecte **pour la première fois sur la page web** (connexion) :

1. **Connexion Gmail**  
   Dès que Gmail est connecté (Firebase Auth ou équivalent côté site), afficher la **page d’autorisation Google Calendar** pour que l’agenda soit disponible sur la barre de recherche Offibox.

2. **Refus de l’agenda**  
   Si le client refuse l’autorisation Calendar, il pourra toujours la faire plus tard via le **menu hamburger** (entrée « Connecter l’agenda Google ») dans l’app.

3. **Après validation**  
   Une fois l’autorisation Calendar validée (ou refus explicite), afficher **« Télécharger Offibox »** (bouton/lien vers le MSI).

4. **Détection de la version de Windows**  
   Côté site, détecter la version de Windows du client (User-Agent, ou Client Hints si disponible) pour proposer le bon installateur (ex. lien MSI 64 bits, ou message si version non supportée).

5. **Déjà connecté (web ou app)**  
   Si le client s’est déjà connecté (via le web ou l’application), ne plus redemander la connexion : réutiliser la session (Firebase Auth, cookie, etc.) et afficher directement la suite (agenda si pas encore fait, ou « Télécharger Offibox » / accès app).

---

## 4. Récapitulatif technique (ce dépôt)

| Élément                         | Où c’est géré |
|---------------------------------|---------------|
| Logo installateur              | WiX : bannière / image de fond (voir installer) |
| Options MSI (bureau, démarrage, lancer) | WiX : options + custom actions / conditions |
| Fenêtre connexion (Google / e-mail)     | `lib/auth/login_page.dart` |
| Pas de reconnexion si déjà connecté     | `lib/auth/auth_gate.dart` + Firebase Auth |
| Connexion web + agenda + télécharger     | Site offibox.fr (hors ce dépôt) |
| Détection version Windows               | Côté site (User-Agent / Client Hints) |
