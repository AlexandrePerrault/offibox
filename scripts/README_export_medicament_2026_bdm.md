# Export feuille « médicament 2026-BDM » vers GitHub

Script Google Apps Script qui exporte la feuille **médicament 2026-BDM** du spreadsheet vers le dépôt GitHub **offiboxdata** (fichier `medicament_2026_BDM.csv`). Exécution automatique **tous les jours à 8h et 13h** (heure de Paris), même si ton PC est éteint.

## Constantes

| Constante | Valeur |
|-----------|--------|
| **Spreadsheet ID** | `1Tn0zkWjKh6lggWON176wjKM9mhMQ6HYZPbiYIFBxnfo` |
| **Feuille source** | `médicament 2026-BDM` |
| **Fichier GitHub** | `medicament_2026_BDM.csv` |
| **Dépôt** | `AlexandrePerrault/offiboxdata`, branche `main` |

## Installation (une fois)

1. **Ouvrir le Google Sheet** (l’URL contient l’ID `1Tn0zkWjKh6lggWON176wjKM9mhMQ6HYZPbiYIFBxnfo`).
2. **Extensions** > **Apps Script**.
3. **Coller le contenu** de `export_medicament_2026_bdm_to_github.gs` dans l’éditeur (remplacer le code par défaut ou créer un fichier `.gs`).
4. **Propriétés du script** :  
   **Projet** (icône engrenage) > **Propriétés du script** > ajouter :
   - `GITHUB_TOKEN` = ton token GitHub (classic) avec au moins le scope **repo** (pour pousser sur `offiboxdata`).
5. **Enregistrer** le projet.
6. **Exécuter une fois** la fonction **`installMedicament2026BDMTriggers`** :  
   Dans l’éditeur, sélectionner `installMedicament2026BDMTriggers` dans la liste des fonctions, puis **Exécuter**.  
   (À la première exécution, autoriser l’accès au tableur et au réseau.)
7. Les **déclencheurs** sont créés : **Exécutions** (horloge) > **Déclencheurs** pour les voir (8h et 13h, Europe/Paris).

## Utilisation

- **Export manuel** : dans Apps Script, exécuter **`exportMedicament2026BDMToGitHub`**.
- **Export automatique** : tous les jours à **8h** et **13h** (Europe/Paris), le script lit la feuille « médicament 2026-BDM », génère le CSV et pousse le fichier sur GitHub (`medicament_2026_BDM.csv`).

## Fichier généré sur GitHub

- **URL** : `https://github.com/AlexandrePerrault/offiboxdata/blob/main/medicament_2026_BDM.csv`
- **Raw** : `https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/medicament_2026_BDM.csv`

## Importer les données Python (BDM) vers la feuille

Pour **remplir** la feuille à partir des CSV générés par `bdm_build_libelle_and_csv.py` :

1. Générer les CSV : `python scripts/bdm_build_libelle_and_csv.py` → `scripts/bdm_output/bdm_total.csv`.
2. Envoyer vers Google Sheets : `pip install gspread google-auth`, créer un compte de service Google (API Sheets), partager le spreadsheet avec l’email du compte, puis :
   - `set GOOGLE_APPLICATION_CREDENTIALS=C:\chemin\creds.json`
   - `python scripts/bdm_upload_to_sheets.py`
   Ou : `python scripts/bdm_upload_to_sheets.py --credentials creds.json`
   Par défaut envoie **bdm_total.csv** ; pour un autre : `--csv scripts/bdm_output/bdm_libelle_cip13.csv`.

**Sans compte de service** : Fichier > Importer > Téléverser `scripts/bdm_output/bdm_total.csv` (séparateur Point-virgule, UTF-8).

## Injection dans la feuille des résultats

Ce script **n’injecte pas** les données dans la feuille : il **lit** la feuille « médicament 2026-BDM » telle qu’elle est et l’exporte en CSV vers GitHub. Si tu as un autre processus (Python, autre Apps Script, formule, etc.) qui remplit cette feuille ou une « feuille des résultats », assure-toi qu’il s’exécute **avant** 8h et 13h, ou que la feuille « médicament 2026-BDM » est bien celle qui contient les données à exporter.
