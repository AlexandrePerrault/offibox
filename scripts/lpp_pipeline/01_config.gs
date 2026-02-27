// @ts-nocheck
/** CONFIG – Pipeline LPP : codes à 7 chiffres depuis ZIP LPPTOT → Sheet (Code LPP, URL, Libellé) + optionnel GitHub */

/** URL du ZIP LPPTOT (ex: LPPTOT867.zip) – source des codes et libellés */
const LPP_ZIP_URL = "http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip";

/** URL fiche LPP Ameli (ex: p_code_tips=8154122). Utiliser en col C (URL) si vide. */
const URL_TEMPLATE = "http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI";

const NOTIFICATION_EMAIL = "perraultalexandre78@gmail.com";
const GITHUB_OWNER = "AlexandrePerrault";
const GITHUB_REPO = "offiboxdata";
const GITHUB_FILE = "codes LPP +++ - codes LPP.csv";
const GITHUB_BRANCH = "main";

const SPREADSHEET_ID = "1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A";
/** Feuille source : colonne A contient les codes (ex. "(CODE LPP) 1100028") */
const SOURCE_SHEET_NAME = "nomenclature LPP";
/** Feuille de destination : col A = code, col B = URL, col C = Libellé */
const SHEET_NAME = "codes LPP";
/** Nombre max de fiches Ameli à interroger pour récupérer le libellé (0 = toutes). Réduire si dépassement du temps d'exécution (6 min). */
const MAX_CODES_TO_FETCH_DESIGNATION = 0;
const GITHUB_TOKEN = "";
