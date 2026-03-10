# Pipeline Annuaire PS 2026

Script Python qui :
1. Télécharge le fichier **PS_LibreAcces_Personne_activite** depuis data.gouv.fr
2. Nettoie les données (encodage, espaces, lignes vides)
3. Injecte dans la feuille Google Sheets **« annuaire PS 2026 »**
4. Exporte en CSV vers GitHub : **annuaire PS 2026.csv** (dépôt `AlexandrePerrault/offiboxdata`, branche `main`)

## Prérequis

```bash
pip install gspread google-auth
```

- **Google** : compte de service avec accès au spreadsheet (partagé en éditeur avec l’email du compte).
- **GitHub** : token avec scope `repo` (variable d’environnement `GITHUB_TOKEN`).

## Configuration

| Élément | Valeur |
|--------|--------|
| Spreadsheet ID | `1CBHIdBePtr1JhA-UZLSk_jZ5bRBMYIUgBV-3m13Umk4` |
| Feuille | `annuaire PS 2026` |
| Fichier GitHub | `annuaire PS 2026.csv` |
| Dépôt | `AlexandrePerrault/offiboxdata`, branche `main` |

## Usage

```bash
# Depuis la racine du projet
export GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/creds.json
export GITHUB_TOKEN=ghp_xxx
python scripts/annuaire_ps_2026_pipeline.py
```

Options utiles :
- `--url URL` : URL du fichier source (si data.gouv change l’URL des extractions).
- `--no-sheets` : ne pas envoyer vers Google Sheets.
- `--no-github` : ne pas pousser vers GitHub.
- `--pharmacies-only` : extraire **uniquement les établissements pharmacie** (une ligne par pharmacie, ~20 000) : CSV dédoublonné `annuaire_ps_2026_output/annuaire_pharmacies_2026.csv` (Nom_pharmacie, Adresse, Code_postal, Ville, Telephone). À combiner avec `--no-sheets --no-github` pour n’obtenir que ce fichier.
- `--max-rows N` : limiter à N lignes de données (pour test).

**Exemple — uniquement le CSV des pharmacies (établissements) :**
```bash
python scripts/annuaire_ps_2026_pipeline.py --pharmacies-only --no-sheets --no-github
```
→ Fichier produit : `scripts/annuaire_ps_2026_output/annuaire_pharmacies_2026.csv`

## Exécution quotidienne

- **Linux / Mac** (crontab) :  
  `0 8 * * * /usr/bin/python3 /chemin/vers/offibox/scripts/annuaire_ps_2026_pipeline.py`

- **Windows** : Planificateur de tâches → nouvelle tâche → déclencheur « tous les jours » à 8h → action « Démarrer un programme » : `python`, arguments : `C:\chemin\vers\scripts\annuaire_ps_2026_pipeline.py`. Définir `GOOGLE_APPLICATION_CREDENTIALS` et `GITHUB_TOKEN` dans l’environnement de la tâche si besoin.

## URL source

L’URL par défaut pointe vers une ressource data.gouv (date 20260228). Si l’extraction est republiée avec une nouvelle date, mettre à jour l’URL dans le script ou passer `--url "nouvelle_url"`.
