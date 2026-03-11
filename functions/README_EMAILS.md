# Configuration des emails Offibox (no-reply@offibox.fr)

Les Cloud Functions envoient des emails pour :
- **1ère connexion** : bienvenue + essai 15 jours
- **Fin d'essai** : notification de fin de période d'essai
- **Vérification d’email** : lien de validation (inscription)
- **Mot de passe oublié** : lien de réinitialisation
- **Boîte à idées** et **formulaire Contact** → contact@offibox.fr

Sans configuration SMTP, les emails sont écrits dans la collection Firestore `mail` ; l’envoi réel ne se fait que si vous choisissez l’une des options ci‑dessous.

---

## Option 1 : Extension Firebase « Trigger Email from Firestore »

1. **Firebase Console** → [Extensions](https://console.firebase.google.com/project/offibox-prod/extensions)
2. **Installer** l’extension **« Trigger Email from Firestore »** (ou équivalent)
3. Lors de l’installation, **configurer le SMTP** (hébergeur, SendGrid, Mailgun, etc.) avec l’adresse d’envoi **no-reply@offibox.fr** (ou un alias)
4. Les documents créés dans la collection **`mail`** sont alors envoyés automatiquement par l’extension (délai typique 10 s – 1 min)

Aucun code à modifier : les fonctions créent déjà des documents dans `mail` quand SMTP n’est pas configuré.

---

## Option 2 : SMTP via Firebase Secret Manager (recommandé pour envoi immédiat)

Les fonctions utilisent **Firebase Secret Manager** pour SMTP. Une fois les secrets définis, l’envoi se fait directement depuis les Cloud Functions (Nodemailer), sans passer par la collection `mail`.

### 1. Créer les secrets avec la CLI Firebase

À la racine du projet (ou dans `functions`), exécuter :

```bash
firebase functions:secrets:set SMTP_HOST
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
```

À chaque commande, le CLI demande la **valeur** du secret (saisie au clavier, ou coller depuis votre fournisseur SMTP).

- **SMTP_HOST** : serveur SMTP (ex. `smtp.office365.com`, `smtp.gmail.com`, `smtp.sendgrid.net`, ou le serveur de votre hébergeur email)
- **SMTP_USER** : identifiant (souvent l’email d’envoi, ex. `no-reply@offibox.fr`)
- **SMTP_PASS** : mot de passe ou mot de passe d’application

### 2. (Optionnel) Port et TLS

Par défaut : port **587**, connexion non sécurisée (STARTTLS). Pour changer :

- **Port** : définir la variable d’environnement (config Firebase)  
  `SMTP_PORT` (ex. `465` pour SMTPS)
- **Connexion SSL/TLS directe** : définir  
  `SMTP_SECURE=true`

Exemple avec la CLI (variables d’environnement pour les options non sensibles) :

```bash
firebase functions:config:set smtp.port="465" smtp.secure="true"
```

Puis dans le code, utiliser `functions.config().smtp?.port` si vous l’exposez, ou laisser le code actuel qui lit `process.env.SMTP_PORT` et `process.env.SMTP_SECURE` si vous les définissez au déploiement.

### 3. Redéployer les functions

Après avoir créé ou mis à jour les secrets :

```bash
cd functions
npm run build
firebase deploy --only functions
```

Les fonctions qui envoient des emails déclarent déjà ces secrets ; elles recevront les valeurs au moment de l’exécution.

---

## Vérification

- **Logs** : dans Firebase Console → Functions → Logs, vous verrez soit  
  `[sendEmail] Envoyé via SMTP vers …`  
  soit  
  `[sendEmail] Doc créé dans mail/ vers …`  
  selon que SMTP est configuré ou non.
- **Sans SMTP** : les documents dans `mail` sont créés ; si l’extension Trigger Email est installée et configurée, elle enverra les emails.

---

## Exemples de fournisseurs SMTP

| Fournisseur     | SMTP_HOST              | Port | Remarque |
|-----------------|------------------------|------|----------|
| Office 365      | smtp.office365.com     | 587  | Compte no-reply@offibox.fr |
| Gmail           | smtp.gmail.com         | 587  | Mot de passe d’application conseillé |
| SendGrid        | smtp.sendgrid.net      | 587  | User = `apikey`, Pass = clé API |
| OVH / hébergeur | ex. ssl0.ovh.net       | 587 ou 465 | Selon offre email du domaine |

Une fois **SMTP_HOST**, **SMTP_USER** et **SMTP_PASS** définis dans Secret Manager et les functions redéployées, les emails partent directement depuis les Cloud Functions sans avoir à configurer l’extension Trigger Email.
