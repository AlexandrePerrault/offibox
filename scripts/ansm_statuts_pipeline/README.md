# Pipeline statuts ANSM (CIS_CIP_Dispo_Spec)

Télécharge le fichier **CIS_CIP_Dispo_Spec.txt** depuis la base publique des médicaments, injecte **toutes** les lignes dans la feuille Google **statuts ANSM**, et pousse vers GitHub uniquement les lignes dont **la colonne F (date MAJ) est à moins de 2 mois**. En cas de changements (ajouts/suppressions), envoi d’un email avec les clés et **URL correspondantes**.

## Fichiers

| Fichier | Rôle |
|--------|------|
| `01_config.gs` | Constantes : SOURCE_TXT_URL, NOTIFICATION_EMAIL, GITHUB_*, SPREADSHEET_ID, SHEET_NAME |
| `02_fetch_and_parse.gs` | Téléchargement du TXT et parsing (tab ou virgule) |
| `03_inject_sheet.gs` | Écriture de toutes les lignes dans la feuille "statuts ANSM" |
| `04_github_and_email.gs` | Filtre col F < 2 mois, comparaison avec GitHub, push CSV, email (ajouts/suppressions + URL) |
| `05_pipeline.gs` | `runDailyAnsmStatuts()`, `installDailyTrigger()` |

## Source

- **TXT** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt`
- **Colonne F** (index 5) = date MAJ. Seules les lignes dont cette date est dans les 2 derniers mois sont envoyées sur GitHub.
- **GitHub** : `statuts ANSM.csv` sur `AlexandrePerrault/offiboxdata`, branche `main`.

## Utilisation

1. Créer un projet Google Apps Script et coller chaque fichier `.gs`.
2. Renseigner **GITHUB_TOKEN** dans les Propriétés du script (clé `GITHUB_TOKEN`) ou dans `01_config.gs`.
3. Exécuter **`runDailyAnsmStatuts`** une fois pour tester.
4. Exécuter **`installDailyTrigger`** pour lancer le pipeline tous les jours à 6h.

## Email

Envoyé à `NOTIFICATION_EMAIL` **uniquement en cas de changements** (ajouts ou suppressions de lignes dans le CSV filtré). Le corps liste les ajouts et suppressions avec la clé (CIS|CIP) et l’URL correspondante (colonne G si présente).

## Ajustements

- Si le TXT a un autre séparateur ou ordre de colonnes, adapter `step2_parseTxt_` et dans `04_github_and_email.gs` les constantes **COL_DATE_INDEX** (colonne F = 5) et **COL_URL_INDEX** (colonne URL).
