# Fiches VOC (Voie Orale contre le Cancer) – OMÉDIT

Récupération des fiches à destination des **professionnels de santé** et des **patients** (français) depuis [Fiches VOC – OMÉDIT](https://www.omedit-fiches-cancer.fr/fiches-voie-orale-contre-le-cancer-voc/fiches-voie-orale-contre-le-cancer-voc,6093,13536.html), injection dans une feuille Google Sheets puis push vers GitHub.

## Fichiers

- **01_config.gs** : Constantes (owner, repo, branch, URL source, nom de feuille, ID du tableur).
- **02_fetch_and_inject_sheet.gs** : Télécharge la page HTML, parse le tableau (médicament, fiche patient, fiche pro), écrit en feuille « VOC » : col 1 = médicament, col 2 = URL fiche patient, col 3 = URL fiche pro.
- **03_export_to_github.gs** : Exporte la feuille en CSV, pousse vers `offiboxdata/fiches_voc.csv`, pipeline mensuel et fonction d’installation du déclencheur.

## Configuration

1. **Google Sheet**  
   Créer un Google Sheet (ou utiliser un existant), copier son **ID** (dans l’URL : `https://docs.google.com/spreadsheets/d/XXXXX/edit` → `XXXXX`).  
   Dans **01_config.gs**, renseigner :
   ```js
   spreadsheetId: 'VOTRE_ID_ICI'
   ```

2. **Apps Script**  
   Dans le menu **Extensions > Apps Script**, créer un projet et coller le contenu des trois fichiers (01_config, 02_fetch, 03_export).  
   Enregistrer le projet.

3. **Token GitHub**  
   Dans Apps Script : **Projet concerné > Paramètres du projet (icône engrenage) > Propriétés du script**  
   Ajouter une propriété :
   - **GITHUB_TOKEN** : un token GitHub (classic) avec au moins le scope `repo` pour pouvoir pousser sur `AlexandrePerrault/offiboxdata`.

4. **Déclencheur mensuel (1er du mois à 8h)**  
   - **Option A (recommandée)** : Dans Apps Script, exécuter **une fois** la fonction **vocInstallMonthlyTrigger** (menu Exécutions > vocInstallMonthlyTrigger). Elle crée le déclencheur et supprime les anciens sur `vocMonthlyPipeline`.  
   - **Option B** : Déclencheurs (icône horloge) > Ajouter un déclencheur > Fonction : **vocMonthlyPipeline**, Type : Minuteur, Période : Mensuel, Jour : **1**, Heure : **8 h**.

## Pipeline et exécution

- **vocMonthlyPipeline** : pipeline complet (fetch page OMÉDIT → injection feuille VOC → push `fiches_voc.csv` sur GitHub). C’est la fonction appelée par le déclencheur mensuel.
- **vocInstallMonthlyTrigger** : à lancer une fois pour créer le déclencheur mensuel (1er du mois, 8h).
- **vocFetchAndInjectSheet** : met à jour uniquement la feuille « VOC » du Google Sheet.
- **vocPushSheetToGitHub** : envoie le contenu actuel de la feuille « VOC » vers `fiches_voc.csv` sur GitHub.

## GitHub

- Dépôt : **AlexandrePerrault/offiboxdata**
- Branche : **main**
- Fichier créé/mis à jour : **fiches_voc.csv**  
  Colonnes : `Médicament` ; `URL fiche patient` ; `URL fiche professionnel` (séparateur `;`, encodage UTF-8).
