# Pipeline LPP simplifié (3 colonnes)

Script Python : **codes LPP** (Google Sheet ou CSV) + **LPPTOT867** → CSV **code | libellé | url**.

## Entrée des codes

- **Google Sheet** : feuille « nomenclature LPP » du fichier  
  `1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A`, colonne A.  
  Le script enlève « (CODE LPP) » et garde le code à 7 chiffres.
- **CSV** : export de cette feuille (colonne A = codes). Même règle : extraction du code à 7 chiffres.

## Source LPPTOT

- URL par défaut :  
  `http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip`  
  Téléchargement automatique si `--lpptot` n’est pas fourni.

## Sortie CSV (séparateur `;`)

| Colonne            | Contenu |
|--------------------|--------|
| code à 7 chiffres  | Extrait de la feuille / CSV |
| libellé            | Depuis LPPTOT (dernière période par code) |
| url                | `http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI` |

## Utilisation

```bash
# Depuis la racine du projet

# Avec un export CSV de la feuille "nomenclature LPP"
python tool/lpp_pipeline_simple.py --csv "nomenclature LPP.csv" -o lpp_export.csv

# Avec Google Sheet (pip install gspread google-auth ; variable GOOGLE_APPLICATION_CREDENTIALS)
python tool/lpp_pipeline_simple.py --google-sheet 1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A --sheet "nomenclature LPP" -o lpp_export.csv

# LPPTOT local (ZIP ou fichier extrait) au lieu du téléchargement
python tool/lpp_pipeline_simple.py --csv codes.csv --lpptot LPPTOT867.zip -o out.csv
```

**Fichier de sortie par défaut** : `lpp_nomenclature_3cols.csv`.
