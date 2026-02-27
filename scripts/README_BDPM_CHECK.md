# Vérification quotidienne des sources BDPM

## Script

`check_bdpm_sources.dart` télécharge les fichiers officiels BDPM (CIS_bdpm.txt, CIS_CIP_bdpm.txt), affiche la structure des colonnes et **15 exemples de libellés reconstruits** (nom, dosage, forme, quantité).

## Exécution

Depuis la racine du projet :

```bash
dart run scripts/check_bdpm_sources.dart
```

## Planification (vérification quotidienne)

- **Windows** : Task Scheduler — créer une tâche quotidienne qui lance `dart run scripts/check_bdpm_sources.dart` (chemin complet du projet).
- **Linux/macOS** : cron — ajouter par exemple `0 8 * * * cd /chemin/offibox && dart run scripts/check_bdpm_sources.dart` pour un run chaque jour à 8h.

## Fichiers utilisés

- CIS_bdpm.txt : dénomination, forme pharmaceutique par CIS.
- CIS_CIP_bdpm.txt : libellé de présentation, CIP13, taux de remboursement par présentation.

Les index de colonnes sont définis en tête du script ; les vérifier si le format BDPM change (PDF officiel ANSM « Contenu et format des fichiers téléchargeables »).

## Libellés dans l'app

Le module `lib/data/bdpm_labels_loader.dart` expose `loadBdpmLabels()` pour construire une map CIP13 → libellé (et optionnellement CIS → taux). Utilisable pour une future bascule depuis BDM_MASTER ou un mode prévisualisation.
