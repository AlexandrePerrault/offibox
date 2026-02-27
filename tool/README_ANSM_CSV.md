# Script ANSM → CSV génériques / princeps

Ce script construit un fichier CSV à partir des fichiers TXT de l’ANSM pour alimenter l’affichage **ligne 2** des résultats de recherche Offibox (badges « Princeps : X » / « Générique : X »).

## Sources ANSM

- **fic01den.txt** : liste des dénominations communes internationales (DCI)  
  Ex. : `579 ABACAVIR + LAMIVUDINE + ZIDOVUDINE`
- **fic03spe.txt** : spécialités (code groupe, CIP, type G/R, libellé)  
  Ex. : `1370 61876780 G ABACAVIR ARROW 300 mg, comprimé pelliculé sécable`

Les URLs par défaut pointent vers les fichiers publiés par l’ANSM (à mettre à jour si l’ANSM change d’URL ou de date).

## Utilisation

```bash
# Depuis la racine du projet
python tool/ansm_generiques_csv.py

# Fichier de sortie personnalisé
python tool/ansm_generiques_csv.py --output mon_fichier.csv

# Utiliser des fichiers TXT déjà téléchargés (sans réseau)
# Placer fic01den.txt et fic03spe.txt à la racine du projet
python tool/ansm_generiques_csv.py --no-fetch
```

**Sortie** : par défaut `generiques_ansm.csv` à la racine du projet.

## Format du CSV

Séparateur : `;`. Encodage : UTF-8.

| Colonne       | Contenu |
|---------------|--------|
| DCI           | Dénomination commune internationale (fic01den) |
| princeps_nom  | Nom du médicament princeps (référent) |
| princeps_cip  | CIP13 du princeps |
| cip13         | CIP13 du produit (générique ou princeps) |

- Une ligne par **générique** : `cip13` = CIP du générique, `princeps_nom` / `princeps_cip` = princeps associé.
- Une ligne par **princeps** : `cip13` = `princeps_cip` = CIP du princeps, `princeps_nom` = libellé du princeps.

L’app Offibox utilise déjà un CSV du même type (col 1 = princeps, col 3 = CIP13) pour `generiques.dart`. Ce script permet de régénérer ce CSV à partir des sources officielles ANSM.

## Mise sur GitHub

1. **Script** : le script `tool/ansm_generiques_csv.py` peut être poussé dans le dépôt Offibox (ou dans un dépôt dédié type `offiboxdata`).
2. **CSV** : le fichier généré `generiques_ansm.csv` peut être publié dans le dépôt de données (ex. `AlexandrePerrault/offiboxdata`) et l’URL dans `lib/data/generiques.dart` pointée vers ce fichier si vous souhaitez l’utiliser à la place de l’actuel.
3. **Mise à jour** : en cas de nouvelle version des fic01/fic03 sur le site ANSM, mettre à jour les URLs dans le script (ou les dates dans l’URL) et relancer le script, puis committer le nouveau CSV.

## Dépendances

Python 3.8+. Bibliothèques standard uniquement (`urllib`, `csv`, `re`, `argparse`, `pathlib`).
