// @ts-nocheck
/***************************************
 * CONFIG – Pipeline statuts ANSM (CIS_CIP_Dispo_Spec.txt → Sheet → GitHub)
 * Token : Propriétés du script (GITHUB_TOKEN) ou constante ci-dessous.
 ***************************************/

/** Email pour notification en cas de changement (ajouts/suppressions) */
const NOTIFICATION_EMAIL = "perraultalexandre78@gmail.com";

const GITHUB_OWNER = "AlexandrePerrault";
const GITHUB_REPO = "offiboxdata";
const GITHUB_FILE = "statuts ANSM.csv";
const GITHUB_BRANCH = "main";

const SPREADSHEET_ID = "133f_hk06uOJy1j3SUKBJXrWHXEVXcUpTtvn-eV01xEE";
const SHEET_NAME = "statuts ANSM";

/** Fichier TXT base-donnees-publique.medicaments.gouv.fr */
const SOURCE_TXT_URL = "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt";

// Renseigner le token ici ou dans Propriétés du script (clé GITHUB_TOKEN)
const GITHUB_TOKEN = "";
