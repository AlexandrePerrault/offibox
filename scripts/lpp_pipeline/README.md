# Pipeline LPP (Google Apps Script)

Télécharge le **ZIP LPPTOT867** depuis l’URL CNAM, extrait les **codes à 7 chiffres** et les **libellés** depuis le contenu binaire, injecte dans une feuille de destination et peut pousser le CSV vers GitHub.

## Fichiers

| Fichier | Rôle |
|--------|------|
| `01_config.gs` | Constantes : LPP_ZIP_URL, URL_TEMPLATE, SPREADSHEET_ID, SHEET_NAME, GITHUB_*, GITHUB_TOKEN |
| `01_fetch_from_zip.gs` | **Step 1** : fetch ZIP LPPTOT867 → unzip → parse blocs (code 7 derniers chiffres + libellé) |
| `02_extract_last_period.gs` | Conservé : extraction depuis feuille source + enrichissement Ameli (mode manuel) |
| `03_inject_and_github.gs` | **Step 3** : écrit dans la feuille destination (Code LPP, Libellé, URL) |
| `04_github_push.gs` | **Step 4** : push CSV 3 colonnes vers GitHub si changements ; notification email |
| `05_pipeline.gs` | `runDailyLPP()` : fetch ZIP → parse → inject → GitHub |

## Flux

1. **Source** : URL `LPP_ZIP_URL` (ex. LPPTOT867.zip) – téléchargement direct.
2. **Extraction** : le fichier extrait du ZIP est décodé en ISO-8859-1 ; regex pour repérer les blocs `10101011203248 SIEGE DE SERIE, ... TABLETTE AMOVIBLE. 10102...` → code LPP = 7 derniers chiffres du bloc initial, libellé = texte entre les blocs.
3. **Injection** : feuille `SHEET_NAME` (par défaut **"codes LPP"**) : **col A** = Code LPP, **col B** = Libellé, **col C** = URL.
4. **Optionnel** : si `GITHUB_TOKEN` est renseigné et qu’il y a des changements, push du CSV (Code LPP ; URL ; Libellé) vers GitHub et email à `NOTIFICATION_EMAIL`.

## Utilisation dans Google Apps Script

1. Créer un projet Apps Script (ou ouvrir un existant).
2. Coller le contenu de chaque fichier `.gs` dans un fichier du même nom (ou tout regrouper).
3. Dans `01_config.gs` : vérifier **SPREADSHEET_ID**, **SOURCE_SHEET_NAME**, **SHEET_NAME**. Optionnel : **MAX_CODES_TO_FETCH_DESIGNATION** (0 = toutes les fiches ; mettre par ex. 500 si dépassement du temps d’exécution 6 min).
4. Renseigner **GITHUB_TOKEN** dans la config ou dans *Propriétés du script* (clé `GITHUB_TOKEN`) pour le push GitHub.
5. Exécuter **`runDailyLPP`** pour lancer le pipeline (lecture → extraction → récupération libellés → injection → GitHub si changements).
6. Pour un **trigger quotidien** : exécuter **`installDailyTrigger`** une fois (tous les jours à 6h).

## Colonnes Sheet / CSV GitHub

- **Sheet** : **Code LPP** (col A) | **Libellé** (col B) | **URL** (col C).
- **Fichier GitHub** : `codes LPP +++ - codes LPP.csv`.
- **CSV** (séparateur **`;`**, UTF-8 BOM) : **Code LPP** ; **URL** ; **Libellé** (le libellé est échappé s’il contient `;` ou `"`). Compatible avec le loader Flutter (code, url, libelle).

## Sécurité

Ne pas commiter le token GitHub. Utiliser *Propriétés du script* (clé `GITHUB_TOKEN`) ; le script les utilise en priorité.
