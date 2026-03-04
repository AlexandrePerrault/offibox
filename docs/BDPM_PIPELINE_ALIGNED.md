# Pipeline BDPM aligné (medicaments-api)

Ce document décrit le pipeline de reconstruction de la base de médicaments, aligné sur [medicaments-api](https://github.com/Giygas/medicaments-api) (Giygas) : mêmes sources officielles, mêmes 5 fichiers TSV, mêmes indices de colonnes.

## 1. Sources officielles (5 fichiers)

Tous les fichiers sont publiés par l’[Agence nationale de sécurité du médicament](https://base-donnees-publique.medicaments.gouv.fr/telechargement) (BDPM). Format : **TSV** (séparateur tabulation), **sans ligne d’en-tête**, encodage **UTF-8** ou **ISO-8859-1** selon le fichier.

| Fichier | URL | Rôle |
|--------|-----|------|
| **CIS_bdpm.txt** | [CIS_bdpm.txt](https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt) | Spécialités (une ligne par CIS) |
| **CIS_CIP_bdpm.txt** | [CIS_CIP_bdpm.txt](https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt) | Présentations (une ligne par CIP13) |
| **CIS_COMPO_bdpm.txt** | [CIS_COMPO_bdpm.txt](https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt) | Compositions (substances, dosage par CIS) |
| **CIS_GENER_bdpm.txt** | [CIS_GENER_bdpm.txt](https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt) | Groupes génériques (Princeps / Générique par CIS) |
| **CIS_CPD_bdpm.txt** | [CIS_CPD_bdpm.txt](https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CPD_bdpm.txt) | Conditions de prescription et de dispensation |

## 2. Ordre du pipeline (comme medicaments-api)

1. **Télécharger** les 5 fichiers (concurrent si possible, timeout ~5 min/fichier).
2. **Décoder** : UTF-8 par défaut ; si invalide, fallback ISO-8859-1.
3. **Parser** chaque fichier en TSV (`\t`), ignorer lignes vides, lignes avec trop peu de colonnes ou champs invalides.
4. **Indexer** par CIS : compositions, génériques, présentations, conditions → maps `CIS → liste`.
5. **Construire** les médicaments : pour chaque spécialité (CIS_bdpm), assembler dénomination, forme, présentations (CIP), compositions, génériques, conditions via les maps (lookup O(1)).

Référence : `medicaments-api` — `downloader.go` (téléchargement), `tsvConverter.go` (parsing), `medicamentsParser.go` (assemblage).

## 3. Index des colonnes (0-based, alignés medicaments-api)

### CIS_bdpm.txt (Spécialités)

| Index | Champ |
|-------|--------|
| 0 | CIS |
| 1 | Dénomination |
| 2 | Forme pharmaceutique |
| 3 | Voies d’administration (séparateur `;`) |
| 4 | Statut d’autorisation |
| 5 | Type de procédure |
| 6 | État de commercialisation |
| 7 | Date d’AMM |
| 10 | Titulaire(s) |
| 11 | Surveillance renforcée |

### CIS_CIP_bdpm.txt (Présentations)

| Index | Champ |
|-------|--------|
| 0 | CIS |
| 1 | CIP7 |
| 2 | Libellé de la présentation |
| 3 | Statut de la présentation |
| 4 | État de commercialisation |
| 5 | Date de déclaration |
| 6 | CIP13 |
| 7 | Agrément aux collectivités |
| 8 | Taux de remboursement |
| 9 | Prix (virgule décimale ; retirer séparateurs de milliers) |

### CIS_COMPO_bdpm.txt (Compositions)

| Index | Champ |
|-------|--------|
| 0 | CIS |
| 1 | Désignation de l’élément |
| 2 | Code substance |
| 3 | Dénomination substance |
| 4 | Dosage |
| 5 | Référence dosage |
| 6 | Nature du composant (SA/ST) |

Pour Offibox, la phrase « composition » affichée en « + d’infos » est : **col 3 : col 4 pour col 5** (Dénomination substance : Dosage pour Référence dosage), éventuellement agrégée par CIS.

### CIS_GENER_bdpm.txt (Génériques)

| Index | Champ |
|-------|--------|
| 0 | Identifiant du groupe générique |
| 1 | Libellé du groupe |
| 2 | CIS |
| 3 | Type : `0` = Princeps, `1` = Générique, `2` = Complémentarité posologique, `3` = Générique substituable |

### CIS_CPD_bdpm.txt (Conditions)

| Index | Champ |
|-------|--------|
| 0 | CIS |
| 1 | Condition (prescription / dispensation) |

## 4. Usage dans Offibox

- **URLs** : `lib/data/data_sources.dart` — `CIS_BDPM_TXT_URL`, `CIS_CIP_BDPM_TXT_URL`, `CIS_COMPO_BDPM_TXT_URL`, `CIS_GENER_BDPM_TXT_URL`, `CIS_CPD_BDPM_TXT_URL`.
- **Libellés + taux** : `lib/data/bdpm_labels_loader.dart` — charge CIS_bdpm + CIS_CIP_bdpm, reconstruit libellé par CIP13 et taux par CIS (colonnes alignées ci-dessus).
- **Composition** : `loadCompositionBdpmByCis()` dans `bdpm_labels_loader.dart` — charge CIS_COMPO, retourne CIS → "col 3 : col 4 pour col 5".
- **Liste BDM affichée** : actuellement issue de `BDM_MASTER2026.csv` (GitHub). Une reconstruction complète à partir des 5 fichiers suivrait ce pipeline (ex. script `scripts/bdm_build_libelle_and_csv.py`).

## 5. Fichier complémentaire (hors 5 de base)

- **CIS_CIP_Dispo_Spec.txt** : ruptures, tensions, remises, **arrêt de commercialisation**. Utilisé pour le badge « arrêt de commercialisation » et les statuts ANSM.  
  URL : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt`
