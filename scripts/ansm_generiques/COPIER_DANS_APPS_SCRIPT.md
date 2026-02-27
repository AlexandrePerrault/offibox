# Pipeline ANSM génériques (Apps Script)

Compilation des 3 fichiers ANSM (fic01den, fic02grp, fic03spe), MAJ quotidienne, export GitHub, comparaison J/J-1, envoi d’un mail à **perraultalexandre78@gmail.com** en cas de nouveau(x) groupe(s).

## Fichiers à créer dans le projet Apps Script (dans l’ordre)

1. **01_config.gs** – config (dont `EMAIL_ALERT: "perraultalexandre78@gmail.com"`)
2. **02_fetch_and_compare.gs** – téléchargement, parsing, comparaison J/J-1
3. **03_export_to_github.gs** – export CSV + `ansm_new_groups.json` vers GitHub
4. **04_pipeline.gs** – enchaînement + envoi du mail si nouveaux groupes

## Propriétés du script

- **GITHUB_TOKEN** : token GitHub (scope `repo`) pour pousser vers `offiboxdata`.

## Exécution

- **runAnsmPipeline()** : lance tout (fetch → export → mail si nouveaux groupes).
- **installAnsmDailyTrigger()** : planifie une exécution quotidienne à 6h.

## Fichiers publiés sur GitHub (offiboxdata)

- **generiques_ansm.csv** : DCI ; princeps_nom ; princeps_cip ; cip13
- **ansm_new_groups.json** : `{ "date": "YYYY-MM-DD", "newGroups": ["code1", ...], "count": n }` — utilisé pour la barre d’infos dans l’app si vous l’implémentez.

## Modifier l’email d’alerte

Dans **01_config.gs**, éditer la ligne :

```javascript
EMAIL_ALERT: "perraultalexandre78@gmail.com"
```
