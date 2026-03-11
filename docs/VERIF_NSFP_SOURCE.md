# Vérification : pourquoi un CIP n’apparaît pas comme NSFP

## Règle NSFP dans Offibox

Un médicament est affiché comme **NSFP** (« ne se fait plus ») uniquement si :

1. **`nsfp == true`** (colonne **7** du CSV BDM = `"oui"`)
2. **`nsfpDate` non vide** (colonne **12** = date de rupture remplie)

Code : `lib/models/search_result_extensions.dart` → `isNsfpEffective`.

## Source des données NSFP

- **Fichier** : **BDM_MASTER2026.csv**
- **URL** :  
  `https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_MASTER2026.csv`
- **Parsing** : `lib/data/bdm_parser.dart` → `parseBdmSync`
  - Colonne **7** → `nsfp` (texte `"oui"` → `true`)
  - Colonne **12** → `nsfpDate` (date rupture, formatée en FR)

Ce fichier **n’est pas dans le dépôt offibox** ; il est dans le dépôt **offiboxdata**.

## Exemple : CIP 3400927949906 (Imbruvica)

Si ce CIP n’apparaît **pas** comme NSFP, vérifier dans **BDM_MASTER2026.csv** (dépôt offiboxdata) :

1. **La ligne existe** : une ligne dont la colonne **2** (CIP13) = `3400927949906`.
2. **Colonne 7** = `oui` (sinon `nsfp` reste `false`).
3. **Colonne 12** = **non vide** (date de rupture).  
   Sans date, `isNsfpEffective` reste `false` et le médicament ne s’affiche pas comme NSFP.

### À faire côté données

- Ouvrir **BDM_MASTER2026.csv** (ou le script qui le génère à partir du BDPM/ANSM).
- Pour le CIP 3400927949906 (et les présentations Imbruvica concernées) :
  - Mettre la colonne **7** à `oui`
  - Renseigner la colonne **12** (date d’arrêt de commercialisation).
- Si le CSV est produit par un script à partir des fichiers officiels BDPM/ANSM, il faut que ce script récupère le statut « arrêt de commercialisation » / date de rupture et remplisse les colonnes 7 et 12.

## Fichiers source dans le projet Offibox

| Rôle | Fichier |
|------|--------|
| URL du CSV BDM | `lib/data/data_sources.dart` → `BDM_URL` |
| Parsing CSV (colonnes 7 et 12) | `lib/data/bdm_parser.dart` → `parseBdmSync` |
| Mapping vers SearchResult | `lib/data/search_result_mapper.dart` → `nsfp`, `nsfpDate` |
| Règle « NSFP effectif » | `lib/models/search_result_extensions.dart` → `isNsfpEffective` |
| Règle rappelée (script) | `scripts/verify_cip_bdpm.ps1` (règle NSFP) |

Le CIP **3400927949906** n’apparaît dans **aucun fichier source** du dépôt offibox : son statut NSFP dépend **uniquement** du contenu de **BDM_MASTER2026.csv** dans le dépôt offiboxdata.
