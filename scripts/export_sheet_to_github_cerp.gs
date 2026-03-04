/**
 * Exporte une feuille Google Sheets vers le dossier CERP du dépôt GitHub offiboxdata.
 * Feuille "madouest" -> CERP/madouest.csv
 *
 * Configuration : Script Editor > Projet > Propriétés du script
 *   - GITHUB_TOKEN : token personnel avec scope repo
 *
 * Ou modifier les constantes ci-dessous.
 */

/**
 * 🔧 CONFIGURATION GITHUB
 */
const GITHUB_OWNER  = 'AlexandrePerrault';
const GITHUB_REPO   = 'offiboxdata';
const GITHUB_BRANCH = 'main';

/** Dossier cible dans le dépôt (sans slash final) */
const GITHUB_FOLDER = 'CERP';

/** Feuille à exporter -> fichier CSV */
const SHEET_NAME   = 'madouest';
const FILE_NAME    = 'madouest.csv';

/**
 * Enregistre le token GitHub (à exécuter une fois).
 * Récupère le token depuis les propriétés du script ou demande à l'utilisateur.
 */
function setGithubToken() {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (token) {
    Logger.log('Token déjà configuré.');
    return;
  }
  const ui = SpreadsheetApp.getUi();
  const result = ui.prompt('Token GitHub', 'Collez votre token personnel (scope repo) :', ui.ButtonSet.OK_CANCEL);
  if (result.getSelectedButton() === ui.Button.OK) {
    const t = result.getResponseText().trim();
    if (t) {
      PropertiesService.getScriptProperties().setProperty('GITHUB_TOKEN', t);
      ui.alert('Token enregistré.');
    }
  }
}

/**
 * Exporte la feuille [sheetName] en CSV et pousse vers GitHub dans CERP/[fileName].
 */
function pushSheetToGitHubCERP(sheetName, fileName) {
  sheetName = sheetName || SHEET_NAME;
  fileName  = fileName  || FILE_NAME;

  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) {
    SpreadsheetApp.getUi().alert('Exécutez d\'abord setGithubToken() pour configurer le token GitHub.');
    return;
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    SpreadsheetApp.getUi().alert('Feuille "' + sheetName + '" introuvable.');
    return;
  }

  const csv = sheetToCsv(sheet);
  const path = GITHUB_FOLDER + '/' + fileName;

  const url = 'https://api.github.com/repos/' + GITHUB_OWNER + '/' + GITHUB_REPO + '/contents/' + encodeURIComponent(path);

  const options = {
    method: 'get',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Accept': 'application/vnd.github.v3+json'
    },
    muteHttpExceptions: true
  };

  let sha = null;
  const getRes = UrlFetchApp.fetch(url, options);
  if (getRes.getResponseCode() === 200) {
    const data = JSON.parse(getRes.getContentText());
    sha = data.sha;
  }

  const payload = {
    message: 'Export ' + sheetName + ' -> ' + path + ' (' + new Date().toISOString().slice(0, 19) + ')',
    content: Utilities.base64Encode(Utilities.newBlob(csv).getBytes('UTF-8')),
    branch: GITHUB_BRANCH
  };
  if (sha) payload.sha = sha;

  options.method = 'put';
  options.payload = JSON.stringify(payload);
  options.contentType = 'application/json';

  const res = UrlFetchApp.fetch(url, options);
  const code = res.getResponseCode();

  if (code === 200 || code === 201) {
    SpreadsheetApp.getUi().alert('Export réussi : ' + path);
  } else {
    SpreadsheetApp.getUi().alert('Erreur ' + code + ' : ' + res.getContentText());
  }
}

/**
 * Exporte madouest vers CERP/madouest.csv (fonction principale).
 */
function exportMadouestToCERP() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  pushSheetToGitHub(ss.getId(), 'madouest', 'CERP/madouest.csv');
}

/**
 * Exporte la feuille MADOUEST vers CERP/MADOUEST.csv.
 */
function exportKeywords() {
  pushSheetToGitHub(
    '1-fAcPA2Gr7VHso-iqvpTpN5WT5ruUgAwbT6dgPH1EgY',  // ID du spreadsheet
    'MADOUEST',                                       // nom exact de la feuille
    'CERP/MADOUEST.csv'                               // fichier dans le dossier CERP
  );
}

/**
 * Version générique : exporte une feuille vers un chemin GitHub.
 * Pour madouest dans CERP : pushSheetToGitHub(spreadsheetId, 'madouest', 'CERP/madouest.csv')
 */
function pushSheetToGitHub(spreadsheetId, sheetName, githubPath) {
  if (!spreadsheetId || typeof spreadsheetId !== 'string') {
    throw new Error('spreadsheetId invalide : ' + spreadsheetId);
  }
  spreadsheetId = spreadsheetId.trim();

  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('GITHUB_TOKEN manquant. Exécutez setGithubToken().');

  const sheet = SpreadsheetApp.openById(spreadsheetId).getSheetByName(sheetName);
  if (!sheet) throw new Error('Feuille "' + sheetName + '" introuvable');

  const data = sheet.getDataRange().getValues();
  if (data.length < 2) throw new Error('Feuille "' + sheetName + '" vide ou sans données');

  const csv = data
    .map(function(row) {
      return row.map(function(cell) {
        var s = String(cell == null ? '' : cell);
        if (s.indexOf(';') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0) {
          return '"' + s.replace(/"/g, '""') + '"';
        }
        return s;
      }).join(';');
    })
    .join('\n');

  var contentBase64 = Utilities.base64Encode(csv, Utilities.Charset.UTF_8);

  var apiUrl = 'https://api.github.com/repos/' + GITHUB_OWNER + '/' + GITHUB_REPO + '/contents/' + encodeURIComponent(githubPath);

  var sha = null;
  var getRes = UrlFetchApp.fetch(apiUrl, {
    method: 'get',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Accept': 'application/vnd.github.v3+json'
    },
    muteHttpExceptions: true
  });

  if (getRes.getResponseCode() === 200) {
    sha = JSON.parse(getRes.getContentText()).sha;
  }

  var payload = {
    message: 'MAJ ' + sheetName + ' – ' + new Date().toLocaleString('fr-FR'),
    content: contentBase64,
    branch: GITHUB_BRANCH
  };
  if (sha) payload.sha = sha;

  var putRes = UrlFetchApp.fetch(apiUrl, {
    method: 'put',
    contentType: 'application/json',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Accept': 'application/vnd.github.v3+json'
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });

  var code = putRes.getResponseCode();
  if (code !== 200 && code !== 201) {
    throw new Error('GitHub API ' + code + ' : ' + putRes.getContentText());
  }
  Logger.log(sheetName + ' -> ' + githubPath);
}

/**
 * Ajoute un menu "Export CERP" dans la feuille de calcul.
 */
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Export CERP')
    .addItem('Configurer le token GitHub', 'setGithubToken')
    .addItem('Exporter madouest vers CERP', 'exportMadouestToCERP')
    .addItem('Exporter MADOUEST vers CERP', 'exportKeywords')
    .addToUi();
}

/**
 * Convertit une feuille en CSV (séparateur ;).
 */
function sheetToCsv(sheet) {
  const data = sheet.getDataRange().getValues();
  return data.map(function(row) {
    return row.map(function(cell) {
      const s = String(cell == null ? '' : cell);
      if (s.indexOf(';') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    }).join(';');
  }).join('\n');
}
