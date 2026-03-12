# Option B : stockage des données clients et export CSV

## Validé et en place

L’**option B** est implémentée : les données du formulaire d’inscription sont enregistrées en base via une **Cloud Function** (côté serveur, RGPD-friendly).

### Ce qui est fait

1. **Cloud Function `saveRegistrationData`**  
   Appelée automatiquement après la création du compte (page d’inscription). Elle enregistre dans Firestore `users/{uid}` :
   - email (depuis l’auth)
   - clientName (nom de la pharmacie ou prénom + nom)
   - nom, prenom, profession, professionOther, pharmacy, address, zip, city, groupement
   - registrationUpdatedAt (date de mise à jour)

2. **Page d’inscription**  
   Après `signUpWithEmailPassword`, la page appelle `saveRegistrationData` avec les champs du formulaire, puis envoie l’email de définition du mot de passe et redirige vers la validation.

3. **Cloud Function `exportClientsCsv`**  
   Réservée aux **admins** (emails dans `ADMIN_EMAILS`). Retourne un CSV de tous les utilisateurs avec les colonnes d’inscription.

---

## Récupérer un fichier client en CSV

### Méthode 1 : Depuis l’app (ou une page admin) en étant connecté en admin

1. Connecte-toi avec un compte **admin** (email dans la liste des admins des Cloud Functions : `offibox17@gmail.com`, `offibox@gmail.com`).
2. Appelle la callable **`exportClientsCsv`** (depuis l’app Flutter, le dashboard web, ou un script Node).

**Exemple en Flutter** (à placer dans une page réservée admin) :

```dart
final callable = FirebaseFunctions.instance.httpsCallable('exportClientsCsv');
final result = await callable.call<Map<String, dynamic>>();
final csv = result.data['csv'] as String?;
if (csv != null) {
  // Enregistrer en fichier ou afficher
  // Ex. partage / téléchargement : écrire dans un fichier puis partager
}
```

**Exemple en JavaScript** (console du navigateur sur une page où Firebase Auth est connecté en admin) :

```javascript
firebase.functions().httpsCallable('exportClientsCsv')()
  .then(function(r) {
    var csv = r.data && r.data.csv;
    if (csv) {
      var blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = 'offibox_clients_' + new Date().toISOString().slice(0,10) + '.csv';
      a.click();
    }
  });
```

### Méthode 2 : Script Node (Firebase Admin)

1. Dans le dossier du projet :
   ```bash
   cd functions
   npm run build
   node -e "
   const admin = require('firebase-admin');
   const fs = require('fs');
   admin.initializeApp();
   admin.firestore().collection('users').get()
     .then(snap => {
       const headers = 'uid;email;clientName;nom;prenom;profession;pharmacy;address;zip;city;groupement;plan;trialEndsAt;createdAt';
       const rows = snap.docs.map(d => {
         const x = d.data();
         const esc = v => (v == null ? '' : (''+v).includes(';') ? '\"' + (''+v).replace(/\"/g,'\"\"') + '\"' : v);
         return [d.id, x.email, x.clientName, x.nom, x.prenom, x.profession, x.pharmacy, x.address, x.zip, x.city, x.groupement, x.plan, x.trialEndsAt?.toDate?.(), x.createdAt?.toDate?.()].map(esc).join(';');
       });
       fs.writeFileSync('clients_export.csv', '\uFEFF' + headers + '\n' + rows.join('\n'), 'utf8');
       console.log('Fichier clients_export.csv créé.');
     });
   "
   ```
2. Le fichier **`clients_export.csv`** est créé dans `functions/`. Tu peux l’ouvrir avec Excel (encodage UTF-8, séparateur `;`).

### Méthode 3 : Firebase Console

1. **Firebase Console** → projet **offibox-prod** → **Firestore** → collection **`users`**.
2. Export manuel : tu peux exporter la collection en JSON/CSV selon les outils proposés (extensions ou “Export” si disponible).
3. Pour un vrai CSV avec toutes les colonnes, les méthodes 1 ou 2 sont préférables.

---

## Colonnes du CSV exporté par `exportClientsCsv`

| Colonne | Description |
|--------|-------------|
| uid | Identifiant Firebase Auth |
| email | Adresse e-mail |
| clientName | Nom client / pharmacie (affiché) |
| nom | Nom (formulaire) |
| prenom | Prénom (formulaire) |
| profession | Profession (pharmacien, préparateur, autre) |
| professionOther | Précision si « Autre » |
| pharmacy | Nom de la pharmacie |
| address | Adresse |
| zip | Code postal |
| city | Ville |
| groupement | Groupement (optionnel) |
| plan | Plan (trial, pro, …) |
| trialEndsAt | Fin d’essai (ISO) |
| createdAt | Création (ISO) |
| registrationUpdatedAt | Dernière mise à jour inscription (ISO) |

Le fichier est en **UTF-8** avec BOM (pour Excel). Séparateur : **point-virgule (`;`)**.

---

## Déploiement

Après modification des Cloud Functions :

```bash
cd functions
npm run build
firebase deploy --only functions
```

Les callables `saveRegistrationData` et `exportClientsCsv` seront alors à jour en production.
