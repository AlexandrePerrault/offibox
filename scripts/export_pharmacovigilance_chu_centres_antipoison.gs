// Export des feuilles Pharmacovigilance, Centres anti poison et CHU vers GitHub (CSV).
// À utiliser dans un Google Sheet (Extensions → Apps Script). Propriété : GITHUB_TOKEN.

var OUTILS_METIER_CONFIG = {
  owner: 'AlexandrePerrault',
  repo: 'offiboxdata',
  branch: 'main'
};

function pushSheetToGitHub(sheetName, fileName) {
  if (!sheetName) throw new Error('Nom de feuille manquant');
  if (!fileName) throw new Error('Nom de fichier manquant');

  var token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('Token GitHub non configuré.');

  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  if (!spreadsheet) throw new Error('Ce script doit être lié au Google Sheet (Extensions → Apps Script).');

  var sheet = spreadsheet.getSheetByName(sheetName);
  if (!sheet) {
    var noms = spreadsheet.getSheets().map(function(s) { return s.getName(); }).join(', ');
    throw new Error('Feuille introuvable. Feuilles disponibles : ' + noms);
  }

  var data = sheet.getDataRange().getValues();
  var csvContent = data.map(function(row) {
    return row.map(function(cell) {
      if (cell === null || cell === undefined) return '';
      return '"' + cell.toString().replace(/"/g, '""') + '"';
    }).join(',');
  }).join('\n');

  var content = Utilities.base64Encode(csvContent);
  var url = 'https://api.github.com/repos/' +
            OUTILS_METIER_CONFIG.owner + '/' +
            OUTILS_METIER_CONFIG.repo +
            '/contents/' + fileName;

  var headers = {
    Authorization: 'token ' + token,
    Accept: 'application/vnd.github.v3+json'
  };

  var getResponse = UrlFetchApp.fetch(url + '?ref=' + OUTILS_METIER_CONFIG.branch, {
    method: 'get',
    headers: headers,
    muteHttpExceptions: true
  });

  var sha = null;
  if (getResponse.getResponseCode() === 200) {
    sha = JSON.parse(getResponse.getContentText()).sha;
  }

  var payload = {
    message: 'Auto-update ' + sheetName + ' depuis Google Sheets',
    content: content,
    branch: OUTILS_METIER_CONFIG.branch
  };
  if (sha) payload.sha = sha;

  var putResponse = UrlFetchApp.fetch(url, {
    method: 'put',
    contentType: 'application/json',
    headers: headers,
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });

  if (putResponse.getResponseCode() >= 200 && putResponse.getResponseCode() < 300) {
    Logger.log('✅ Export réussi vers GitHub : ' + fileName);
  } else {
    throw new Error('Erreur GitHub : ' + putResponse.getContentText());
  }
}

/** Exporte Pharmacovigilance, Centres anti poison et CHU vers GitHub. */
function exportKeywords() {
  pushSheetToGitHub('pharmacovigilance', 'pharmacovigilance.csv');
  pushSheetToGitHub('Centres anti poison', 'centres_anti_poison.csv');
  pushSheetToGitHub('CHU', 'chu.csv');
}
