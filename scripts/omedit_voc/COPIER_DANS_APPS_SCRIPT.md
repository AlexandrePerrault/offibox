# Scripts VOC à copier dans Google Apps Script

Créer un projet (ou utiliser un Google Sheet → **Extensions > Apps Script**), puis ajouter **3 fichiers** dans cet ordre.  
Configurer **Propriétés du script** : `GITHUB_TOKEN`.  
Renseigner **01_config.gs** : `spreadsheetId` (ID du Google Sheet).

---

## 1. Fichier : `01_config.gs`

Copier le contenu du fichier `01_config.gs` du dossier `omedit_voc`.

---

## 2. Fichier : `02_fetch_and_inject_sheet.gs`

Copier le contenu du fichier `02_fetch_and_inject_sheet.gs` du dossier `omedit_voc`.

---

## 3. Fichier : `03_export_to_github.gs`

Copier le contenu du fichier `03_export_to_github.gs` du dossier `omedit_voc`.

---

## Déclencheur mensuel (1er du mois)

Dans Apps Script : **Déclencheurs** (icône horloge) > **Ajouter un déclencheur**  
- Fonction : **vocMonthlyPipeline**  
- Type : **Minuteur**  
- Période : **Mensuel**  
- Jour : **1er du mois**, heure au choix.

## Exécution manuelle

- **vocFetchAndInjectSheet** : met à jour la feuille VOC.  
- **vocPushSheetToGitHub** : pousse la feuille vers `fiches_voc.csv` sur GitHub.  
- **vocMonthlyPipeline** : fetch + push (équivalent au 1er du mois).
