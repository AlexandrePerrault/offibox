# Licences et limite d’appareils (5 postes)

## Règle appliquée partout (desktop + version en ligne)

- La limite est gérée côté **Cloud Function** `registerDevice` (Firebase).
- Les comptes **contact@offibox.fr**, **offibox@offibox.fr**, **offibox@gmail.com**, **offibox17@gmail.com** sont **exemptés** de la limite (équivalent 999 postes), que ce soit depuis l’app desktop ou la version en ligne (dès qu’elle appelle la même Cloud Function avec le même utilisateur Firebase).

## Où contrôler le nombre de licences (postes) par email ?

Le nombre max de postes **par compte** est défini dans **Firestore** :

- **Collection** : `users`
- **Document** : `users/{uid}` (uid = identifiant Firebase Auth du compte)
- **Champ** : `maxDevices` (nombre, optionnel)

**Comportement :**

- Si `maxDevices` est **absent** → limite par défaut = **5** postes.
- Si vous mettez `maxDevices: 10` (ou autre) sur un document `users/{uid}` → ce compte pourra enregistrer jusqu’à 10 appareils.

**Où modifier :**

1. **Console Firebase**  
   Firestore Database → collection `users` → document correspondant à l’email (uid) → ajouter ou modifier le champ `maxDevices`.

2. **Tableau de bord admin (futur)**  
   Vous pouvez ajouter dans l’admin (réservé offibox17@gmail.com / offibox@gmail.com) une colonne ou un écran pour éditer `maxDevices` par client (écriture Firestore sur `users/{uid}`).

3. **Script ou Cloud Function**  
   Un script ou une fonction peut mettre à jour `users/{uid}.maxDevices` (ex. à l’activation d’une licence ou depuis un back-office).

En résumé : **un email = un uid = un document `users/{uid}`** ; le champ **`maxDevices`** de ce document contrôle le nombre de postes autorisés pour ce compte.

## Connexion depuis plusieurs endroits / partage d’identifiants

- Chaque **poste** (PC, machine) est identifié par un **deviceId** unique. À chaque connexion avec le même compte, l’app enregistre cet appareil via `registerDevice`.
- La limite (ex. 5) s’applique au **nombre d’appareils distincts** enregistrés pour ce compte, pas au nombre de connexions simultanées.

**En pratique :**

- **Même personne, plusieurs PC** : chaque PC = 1 appareil. 5 PC différents = 5 postes, 6ᵉ PC = blocage « limite de 5 postes » (sauf si vous avez augmenté `maxDevices` pour ce compte).
- **Partage d’identifiant / mot de passe** : si un ami se connecte avec le même email/mot de passe, **son PC compte comme un nouvel appareil**. Donc partager ses identifiants = remplir les 5 postes plus vite (voire bloquer le titulaire du compte si 5 amis ont déjà enregistré leurs PC).

Il n’y a pas de détection spécifique du « partage » : on compte uniquement les **appareils différents** enregistrés pour le compte. Pour éviter qu’un client dépasse la limite en prêtant son compte, vous pouvez :

- garder la limite à 5 (ou moins) et communiquer clairement : « 5 postes max par compte » ;
- ou augmenter `maxDevices` pour certains contrats (ex. 10 postes) dans Firestore.

## Résumé

| Question | Réponse |
|----------|--------|
| **Même règle desktop + version en ligne ?** | Oui. La Cloud Function `registerDevice` est la même ; contact@offibox.fr (et les autres emails exemptés) ont 999 postes partout. |
| **Où contrôler le nombre de licences par email ?** | Firestore `users/{uid}.maxDevices` (par défaut 5 si absent). Modifiable dans la console Firebase ou via un futur écran admin. |
| **Plusieurs connexions / partage de compte ?** | On compte les **appareils** (postes) différents. Partager identifiant + mot de passe = chaque PC de l’ami compte comme 1 poste ; même limite que pour le titulaire. |
