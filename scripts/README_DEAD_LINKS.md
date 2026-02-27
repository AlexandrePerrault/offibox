# Vérification des liens morts Offibox

Le script `check_dead_links.py` parcourt tout le projet (lib, assets, scripts, etc.), détecte les URL et vérifie qu’elles répondent. **Si au moins une URL est morte**, un rapport est envoyé par email à **perraultalexandre78@gmail.com**.

## Utilisation

```bash
# Test complet + envoi email si liens morts
python scripts/check_dead_links.py

# Afficher les liens morts sans envoyer d’email
python scripts/check_dead_links.py --no-email

# Lister toutes les URL sans les tester
python scripts/check_dead_links.py --dry-run

# Afficher chaque URL testée
python scripts/check_dead_links.py -v

# Ne vérifier que les URLs du projet (ANSM, offiboxdata, offibox.fr, sante.gouv.fr, etc.)
# — recommandé pour le rapport email, évite les centaines d’URL de doc/dépendances
python scripts/check_dead_links.py --only-project
python scripts/check_dead_links.py --only-project --no-email
```

## Configuration email (Gmail)

Pour que le script envoie le rapport par email :

1. **Compte Gmail** : utilise un compte Gmail (ou Google Workspace) qui enverra les mails.
2. **Mot de passe d’application** :
   - Va sur [Compte Google → Sécurité](https://myaccount.google.com/security).
   - Active la « Validation en 2 étapes » si ce n’est pas déjà fait.
   - Dans « Mots de passe des applications », crée un mot de passe pour « Mail » / « Autre (nom personnalisé) » (ex. « Offibox check »).
   - Copie le mot de passe généré (16 caractères).
3. **Variables d’environnement** (à définir avant d’exécuter le script, ou dans la tâche planifiée) :
   - `OFFIBOX_CHECK_EMAIL_SENDER` = l’adresse Gmail qui envoie (ex. `perraultalexandre78@gmail.com`).
   - `OFFIBOX_CHECK_EMAIL_APP_PASSWORD` = le mot de passe d’application (16 caractères).

   Tu peux aussi utiliser `EMAIL_SENDER` et `EMAIL_APP_PASSWORD` à la place.

### Exemple (PowerShell, une fois)

```powershell
$env:OFFIBOX_CHECK_EMAIL_SENDER = "perraultalexandre78@gmail.com"
$env:OFFIBOX_CHECK_EMAIL_APP_PASSWORD = "xxxx xxxx xxxx xxxx"
cd C:\Users\perra\Documents\projets_flutter\offibox
python scripts\check_dead_links.py
```

### Exemple (Invite de commandes CMD)

En **CMD** (pas PowerShell), utilise `set` **sans espace autour du `=`** :

```cmd
cd /d C:\Users\perra\Documents\projets_flutter\offibox
set OFFIBOX_CHECK_EMAIL_SENDER=perraultalexandre78@gmail.com
set OFFIBOX_CHECK_EMAIL_APP_PASSWORD=mbsl pldt hpxy loqk
python scripts\check_dead_links.py
```

Important : lancer la commande depuis la **racine du projet** (`offibox`), sinon le script ne trouve aucune URL (0 URL trouvées).

### Exemple (tâche planifiée Windows)

Les variables d’environnement peuvent être définies dans un script batch/PowerShell appelé par le Planificateur de tâches (voir ci‑dessous).

---

## Exécution tous les matins à 6h (Windows)

### Option A : Planificateur de tâches + script batch

1. **Créer un script batch** `run_dead_links_check.bat` (par ex. dans `scripts/`) :

```batch
@echo off
set OFFIBOX_CHECK_EMAIL_SENDER=perraultalexandre78@gmail.com
set OFFIBOX_CHECK_EMAIL_APP_PASSWORD=ton_mot_de_passe_app_16_caracteres
cd /d C:\Users\perra\Documents\projets_flutter\offibox
python scripts\check_dead_links.py
```

   Remplace le chemin et le mot de passe. Pour plus de sécurité, évite de laisser le mot de passe en clair : tu peux définir les variables dans le Planificateur (voir option B).

2. **Ouvrir le Planificateur de tâches** : `Win + R` → `taskschd.msc` → Entrée.

3. **Créer une tâche** :
   - « Créer une tâche » (pas « Créer une tâche de base »).
   - **Général** : nom « Offibox – Vérif liens morts », cocher « Exécuter que l’utilisateur soit connecté ou non » si tu veux que ça tourne même sans être connecté.
   - **Déclencheurs** : « Nouveau » → Début : « Selon une planification » → Quotidien → Heure : **6:00** → Répéter tous les **1 jours**.
   - **Actions** : « Nouveau » → Action : « Démarrer un programme » → Programme : `C:\Users\perra\Documents\projets_flutter\offibox\scripts\run_dead_links_check.bat` (ou le chemin de `python.exe` avec comme argument `scripts\check_dead_links.py` et « Démarrer dans » = racine du projet).
   - **Conditions** (optionnel) : décocher « Ne démarrer que si l’ordinateur est sur secteur » si tu veux que ça tourne sur batterie.

4. Enregistrer. La tâche s’exécutera tous les jours à 6h.

### Option B : Variables dans la tâche (sans fichier .bat)

Dans le Planificateur, pour l’action tu peux :

- Programme : `C:\Users\perra\AppData\Local\Programs\Python\Python3xx\python.exe` (adapte la version).
- Arguments : `scripts\check_dead_links.py`
- Démarrer dans : `C:\Users\perra\Documents\projets_flutter\offibox`

Puis dans la tâche, onglet **Général** → « Configurer pour » Windows 10. Dans **Actions** → Modifier l’action, il n’y a pas de champ « variables d’environnement ». Donc pour les identifiants, soit tu les mets dans le .bat (Option A), soit tu crées des variables d’environnement système (Panneau de configuration → Système → Paramètres système avancés → Variables d’environnement) :  
`OFFIBOX_CHECK_EMAIL_SENDER` et `OFFIBOX_CHECK_EMAIL_APP_PASSWORD`. Ainsi, tout script lancé à 6h les verra.

---

## Comportement

- **Aucun lien mort** : le script termine sans envoyer d’email.
- **Un ou plusieurs liens morts** : envoi d’un email à perraultalexandre78@gmail.com avec la liste des URL en erreur, la raison (ex. HTTP 404) et les fichiers concernés.
- Les URL en `localhost`, `127.0.0.1`, `mailto:`, `tel:`, `file:` sont ignorées.
- Un délai d’environ 0,4 s est respecté entre chaque requête pour limiter la charge des serveurs.

### Filtrage des URL

- **Exemples / templates** : les URL contenant des placeholders (`$`, `%s`, `{...}`), les domaines type `example.com`, `domain.tld`, et une liste de sites de doc (Python, pip, IETF, etc.) ne sont **pas testées**, pour éviter des centaines de faux positifs.
- **Fichiers exclus** : `pubspec.lock` n’est pas scanné (URL des packages pub).
- **`--only-project`** : ne garde que les URL des domaines du projet (ANSM, base-donnees-publique.medicaments.gouv.fr, offibox.fr, sante.gouv.fr, offiboxdata sur GitHub, ameli, Viatris, OMÉDIT, Meddispar, etc.). Idéal pour le contrôle quotidien et le rapport email.
