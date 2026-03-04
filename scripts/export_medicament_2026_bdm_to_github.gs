// @ts-nocheck
/**
 * Export de la feuille "médicament 2026-BDM" vers GitHub (offiboxdata).
 * Fichier final : medicament_2026_BDM.csv
 * À copier dans Apps Script du Google Sheet concerné.
 * Propriétés du script : GITHUB_TOKEN (token GitHub avec scope repo).
 *
 * Déclencheurs : exécution tous les jours à 8h et 13h (heure du fuseau du projet).
 * Pour installer : Exécutions > installMedicament2026BDMTriggers (une fois).
 */

var OUTILS_METIER_CONFIG = {
  owner: 'AlexandrePerrault',
  repo: 'offiboxdata',
  branch: 'main'
};

/** ID du spreadsheet contenant la feuille "médicament 2026-BDM". */
var MEDICAMENT_2026_BDM_SPREADSHEET_ID = '1Tn0zkWjKh6lggWON176wjKM9mhMQ6HYZPbiYIFBxnfo';

/** Nom de la feuille source. */
var MEDICAMENT_2026_BDM_SHEET_NAME = 'médicament 2026-BDM';

/** Chemin du fichier sur GitHub (nom URL-safe). */
var MEDICAMENT_2026_BDM_GITHUB_PATH = 'medicament_2026_BDM.csv';

/**
 * Exporte la feuille "médicament 2026-BDM" vers GitHub (medicament_2026_BDM.csv).
 * À appeler manuellement ou via déclencheur (8h et 13h).
 */
function exportMedicament2026BDMToGitHub() {
  var token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('GITHUB_TOKEN manquant (Propriétés du script).');

  var owner = OUTILS_METIER_CONFIG.owner;
  var repo = OUTILS_METIER_CONFIG.repo;
  var branch = OUTILS_METIER_CONFIG.branch;

  var ss = SpreadsheetApp.openById(MEDICAMENT_2026_BDM_SPREADSHEET_ID);
  var sheet = ss.getSheetByName(MEDICAMENT_2026_BDM_SHEET_NAME);
  if (!sheet) throw new Error('Feuille "' + MEDICAMENT_2026_BDM_SHEET_NAME + '" introuvable.');

  var data = sheet.getDataRange().getValues();
  if (data.length < 1) {
    Logger.log('Feuille "' + MEDICAMENT_2026_BDM_SHEET_NAME + '" vide – export ignoré.');
    return;
  }

  var csv = data
    .map(function (row) {
      return row.map(function (cell) {
        return '"' + String(cell).replace(/"/g, '""') + '"';
      }).join(';');
    })
    .join('\n');

  var contentBase64 = Utilities.base64Encode(csv, Utilities.Charset.UTF_8);
  var apiUrl = 'https://api.github.com/repos/' + owner + '/' + repo + '/contents/' + MEDICAMENT_2026_BDM_GITHUB_PATH;

  var sha = null;
  var res = UrlFetchApp.fetch(apiUrl, {
    headers: { Authorization: 'token ' + token },
    muteHttpExceptions: true
  });

  if (res.getResponseCode() === 200) {
    sha = JSON.parse(res.getContentText()).sha;
  }

  var payload = {
    message: 'MAJ ' + MEDICAMENT_2026_BDM_SHEET_NAME + ' – ' + new Date().toLocaleString('fr-FR'),
    content: contentBase64,
    branch: branch
  };
  if (sha) payload.sha = sha;

  UrlFetchApp.fetch(apiUrl, {
    method: 'put',
    contentType: 'application/json',
    headers: { Authorization: 'token ' + token },
    payload: JSON.stringify(payload)
  });

  Logger.log('Export ' + MEDICAMENT_2026_BDM_SHEET_NAME + ' → ' + MEDICAMENT_2026_BDM_GITHUB_PATH + ' (GitHub ' + repo + '/' + branch + ')');
}

/**
 * Installe les déclencheurs : exécution de exportMedicament2026BDMToGitHub tous les jours à 8h et 13h.
 * À exécuter une seule fois dans l’éditeur Apps Script (Exécutions > installMedicament2026BDMTriggers).
 * Les déclencheurs existants sur cette fonction sont supprimés avant d’en créer de nouveaux.
 * Fonctionne même si le PC est éteint (exécution sur les serveurs Google).
 */
function installMedicament2026BDMTriggers() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'exportMedicament2026BDMToGitHub') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }

  ScriptApp.newTrigger('exportMedicament2026BDMToGitHub')
    .timeBased()
    .everyDays(1)
    .atHour(8)
    .inTimezone('Europe/Paris')
    .create();

  ScriptApp.newTrigger('exportMedicament2026BDMToGitHub')
    .timeBased()
    .everyDays(1)
    .atHour(13)
    .inTimezone('Europe/Paris')
    .create();

  Logger.log('Déclencheurs créés : exportMedicament2026BDMToGitHub tous les jours à 8h et 13h (Europe/Paris).');
}
