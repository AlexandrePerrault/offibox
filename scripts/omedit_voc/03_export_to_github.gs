// @ts-nocheck
/**
 * Exporte la feuille VOC (fiches voie orale cancer) vers GitHub : offiboxdata/fiches_voc.csv
 * Utilise OMEDIT_VOC_CONFIG (owner, repo, branch) et GITHUB_TOKEN en propriété du script.
 */

/**
 * Pousse le contenu de la feuille "VOC" vers le fichier fiches_voc.csv sur GitHub.
 * À exécuter après vocFetchAndInjectSheet() (ou manuellement si la feuille est déjà à jour).
 */
function vocPushSheetToGitHub() {
  var config = typeof OMEDIT_VOC_CONFIG !== 'undefined' ? OMEDIT_VOC_CONFIG : {};
  var owner = config.owner || 'AlexandrePerrault';
  var repo = config.repo || 'offiboxdata';
  var branch = config.branch || 'main';
  var spreadsheetId = config.spreadsheetId;
  var sheetName = config.sheetName || 'VOC';
  var githubPath = 'fiches_voc.csv';

  if (!spreadsheetId || spreadsheetId === '') {
    throw new Error('OMEDIT_VOC_CONFIG.spreadsheetId doit être renseigné.');
  }

  var token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('GITHUB_TOKEN manquant (Propriétés du script).');

  var sheet = SpreadsheetApp.openById(spreadsheetId).getSheetByName(sheetName);
  if (!sheet) throw new Error('Feuille "' + sheetName + '" introuvable.');

  var data = sheet.getDataRange().getValues();
  if (data.length < 1) {
    Logger.log('Feuille VOC vide – export ignoré.');
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
  var apiUrl = 'https://api.github.com/repos/' + owner + '/' + repo + '/contents/' + githubPath;

  var sha = null;
  var res = UrlFetchApp.fetch(apiUrl, {
    headers: { Authorization: 'token ' + token },
    muteHttpExceptions: true
  });

  if (res.getResponseCode() === 200) {
    sha = JSON.parse(res.getContentText()).sha;
  }

  var payload = {
    message: 'MAJ fiches VOC – ' + new Date().toLocaleString('fr-FR'),
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

  Logger.log('VOC → ' + githubPath + ' (GitHub ' + repo + '/' + branch + ')');
}

/**
 * Pipeline complet : fetch page VOC → injection feuille → push GitHub.
 * À appeler manuellement ou via déclencheur (1er du mois, 8h).
 */
function vocMonthlyPipeline() {
  try {
    vocFetchAndInjectSheet();
    vocPushSheetToGitHub();
    Logger.log('Pipeline VOC terminé.');
  } catch (e) {
    Logger.log('Erreur pipeline VOC : ' + e.message);
    throw e;
  }
}

/**
 * Crée un déclencheur mensuel : exécution de vocMonthlyPipeline le 1er de chaque mois à 8h (heure du fuseau du projet).
 * À exécuter une seule fois dans Apps Script (Exécutions > vocInstallMonthlyTrigger).
 * Les anciens déclencheurs sur vocMonthlyPipeline sont supprimés avant d'en créer un nouveau.
 */
function vocInstallMonthlyTrigger() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'vocMonthlyPipeline') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }
  ScriptApp.newTrigger('vocMonthlyPipeline')
    .timeBased()
    .onMonthDay(1)
    .atHour(8)
    .create();
  Logger.log('Déclencheur mensuel créé : vocMonthlyPipeline le 1er de chaque mois à 8h.');
}
