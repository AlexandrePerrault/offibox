# Médicaments vétérinaires ANMV / Anses

## Chaîne de données

| Étape | Détail |
|-------|--------|
| **Source officielle** | [amm-vet-fr-v2.xls](https://pro.anses.fr/RCP/amm-vet-fr-v2.xls) — open data Anses/ANMV |
| **Fréquence Anses** | Mise à jour **chaque mardi** (data.gouv.fr) |
| **Fichier Offibox** | `FICHIER MED VETERINAIRES2026.csv` sur [offiboxdata](https://github.com/AlexandrePerrault/offiboxdata) |
| **MAJ automatique** | Workflow GitHub `.github/workflows/anmv_veterinary_daily.yml` — **tous les jours à 6h UTC** |
| **App desktop** | Rechargement à **13h30** (heure locale) si le commit offiboxdata a changé |

## Script local

```bash
pip install xlrd
python scripts/fetch_anmv_veterinary.py
python scripts/fetch_anmv_veterinary.py --push   # OFFIBOXDATA_GITHUB_TOKEN ou GITHUB_TOKEN
```

## Vérifier la fraîcheur

```bash
gh api "repos/AlexandrePerrault/offiboxdata/commits?path=FICHIER%20MED%20VETERINAIRES2026.csv&per_page=1"
```

La première ligne du CSV contient `Date d'extraction : …` (horodatage export Anses).

## Ancien pipeline

Les commits `🔄 MAJ EXTRACTION_ANMV` provenaient d’un Google Apps Script externe (hebdomadaire).  
Le workflow CI ci-dessus le remplace et vérifie **quotidiennement** la source Anses.
