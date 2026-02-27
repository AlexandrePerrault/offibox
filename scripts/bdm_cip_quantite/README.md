# BDM CIP Quantité – Pipeline

Pipeline en 2 étapes pour éviter les timeouts et faciliter le débogage.

## Structure

| Fichier | Rôle |
|---------|------|
| `01_config.gs` | Configuration (URLs, noms) |
| `02_fetch_to_sheet.gs` | Étape 1 : télécharge, parse, écrit dans Google Sheet |
| `03_export_to_github.gs` | Étape 2 : lit le Sheet, exporte vers GitHub |
| `04_pipeline.gs` | Exécution enchaînée + déclencheur quotidien |

## Installation

1. Créer un projet sur [script.google.com](https://script.google.com)
2. Créer un nouveau Google Sheet (vide) pour stocker les données intermédiaires
3. Copier le contenu de chaque fichier `.gs` dans un fichier du projet (dans l’ordre 01 → 04)
4. **Propriétés du script** (Fichier → Propriétés du projet → Propriétés du script) :
   - `GITHUB_TOKEN` : token GitHub (scope `repo`)
   - `BDM_CIP_SHEET_ID` : ID du fichier Google Sheet (dans l’URL : `.../d/SHEET_ID/...`)

## Exécution

### Pipeline complet (recommandé)
```
runPipeline() → exécute fetch + export
```

### Exécution séparée (utile si timeout)
1. `fetchBdmToSheet()` → télécharge et remplit le Sheet (~2–4 min)
2. `exportSheetToGithub()` → exporte le Sheet vers GitHub (~30 s)

### Mise à jour quotidienne
```
installDailyTrigger() → exécute runPipeline() chaque jour à 6h
```

## Colonnes du CSV

| Colonne   | Description                                      |
|-----------|--------------------------------------------------|
| CIP13     | Code 13 chiffres                                 |
| nom       | Dénomination (accents normalisés)                |
| dosage    | Ex. 20 mg, 150 mg                                |
| quantite  | Nombre d'unités par boîte                        |
| libelle   | Libellé reconstruit : "Tramadol 150mg LP boîte de 30 comprimés" |

## Flux

```
CIS_bdpm.txt + CIS_CIP_bdpm.txt (BDPM)
        ↓
   [02_fetch_to_sheet]
        ↓
   Google Sheet (BDM_CIP_QUANTITE)
        ↓
   [03_export_to_github]
        ↓
   BDM_CIP_QUANTITE.csv sur GitHub
```
