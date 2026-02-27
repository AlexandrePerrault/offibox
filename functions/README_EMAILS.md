# Configuration des emails Offibox (no-reply@offibox.fr)

Les emails sont envoyés depuis **no-reply@offibox.fr** pour :
- **1ère connexion** : confirmation + essai 15 jours
- **Fin d'essai** : notification que la période d'essai est terminée

## Option 1 : Extension Firebase "Trigger Email from Firestore"

1. Dans la console Firebase → Extensions → Installer "Trigger Email from Firestore"
2. Configurez votre SMTP (ex. SendGrid, Mailgun, ou SMTP de votre hébergeur)
3. L'adresse d'envoi doit être no-reply@offibox.fr (ou un alias configuré)

Les documents créés dans la collection `mail` seront envoyés automatiquement.

## Option 2 : Nodemailer (variables d'environnement)

Configurez les secrets Firebase :

```bash
firebase functions:secrets:set SMTP_HOST
firebase functions:secrets:set SMTP_PORT
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
```

Puis dans le code, utilisez `process.env.SMTP_*` (à adapter dans emails.ts pour lire les secrets).

## Déploiement

```bash
cd functions
npm install
npm run deploy
```
