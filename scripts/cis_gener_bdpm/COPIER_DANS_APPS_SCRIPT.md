# Pipeline CIS_GENER bdpm – Copier dans Apps Script

Créez un projet Google Apps Script (ou un fichier dédié dans un projet existant), puis copiez les 4 fichiers **dans l’ordre** :

1. **01_config.gs**
2. **02_fetch_parse_inject.gs**
3. **03_export_to_github.gs**
4. **04_pipeline.gs**

## Propriétés du script (Fichier → Propriétés du projet → Propriétés du script)

- **GITHUB_TOKEN** : token GitHub avec droit `repo` (pour pousser vers `offiboxdata`).

## Lancer le pipeline

- Exécuter la fonction **runCisGenerPipeline()** pour un run manuel.
- Exécuter **installCisGenerDailyTrigger()** une fois pour installer le déclencheur quotidien (6h).

## Modifier l’email d’alerte

Dans **01_config.gs**, modifier :

```javascript
EMAIL_ALERT: "votre@email.com"
```

 dans l’objet `CIS_GENER_CONFIG`.
