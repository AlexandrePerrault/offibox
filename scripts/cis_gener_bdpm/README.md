# Pipeline CIS_GENER bdpm (Apps Script)

Import du fichier **CIS_GENER_bdpm.txt** (base médicaments), injection dans un Google Sheet (colonnes : **générique**, **princeps A**, **princeps B**, **CIS**), export quotidien vers GitHub et envoi d’un mail en cas d’**ajouts ou suppressions** (comparaison J / J-1).

## Fichiers (dans l’ordre)

1. **01_config.gs** – config (Sheet, URL, GitHub, email d’alerte)
2. **02_fetch_parse_inject.gs** – téléchargement, parsing, comparaison J-1, injection Sheet
3. **03_export_to_github.gs** – export CSV vers GitHub
4. **04_pipeline.gs** – enchaînement + mail si changements

## Propriétés du script

- **GITHUB_TOKEN** : token GitHub (scope `repo`) pour pousser vers `offiboxdata`.
- **EMAIL_ALERT** : optionnel ; configurable dans `01_config.gs` (`CIS_GENER_CONFIG.EMAIL_ALERT`).

## Exécution

- **runCisGenerPipeline()** : lance tout (fetch → inject → export GitHub → mail si ajouts/suppressions).
- **installCisGenerDailyTrigger()** : planifie une exécution quotidienne à 6h.

## Fichier publié sur GitHub (offiboxdata)

- **cis_gener_bdpm.csv** : générique ; princeps A ; princeps B ; CIS

## Source des données

- URL : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt`
- Format : tab-separated ; colonne 2 = libellé (générique - princeps A - princeps B), colonne 3 = CIS.
