// Export de la feuille "codes_actes_pharmacie" vers GitHub (codes_actes_pharmacie.csv).
// À copier dans Apps Script du Google Sheet concerné.
// Propriétés du script : GITHUB_TOKEN (scope repo).
// Constantes GitHub :

var OUTILS_METIER_CONFIG = {
  owner: 'AlexandrePerrault',
  repo: 'offiboxdata',
  branch: 'main'
};

// ID du classeur Google Sheets contenant la feuille "codes_actes_pharmacie"
var CODES_ACTES_SPREADSHEET_ID = '1rs0c13kuC3QE5FFtoAQMZG-eQ0WoDF6Py4rH38RO2-w';

var SHEET_NAME = 'codes_actes_pharmacie';
var GITHUB_CSV_PATH = 'codes_actes_pharmacie.csv';

/**
 * Exporte la feuille "codes_actes_pharmacie" vers codes_actes_pharmacie.csv sur GitHub.
 * À exécuter depuis l'éditeur Apps Script (Exécuter > exportCodesActesPharmacieToGitHub).
 */
function exportCodesActesPharmacieToGitHub() {
  var token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('❌ GITHUB_TOKEN manquant (Propriétés du script)');

  var spreadsheet = SpreadsheetApp.openById(CODES_ACTES_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error('❌ Feuille "' + SHEET_NAME + '" introuvable');

  var data = sheet.getDataRange().getValues();
  if (data.length < 1) {
    Logger.log('⚠️ ' + SHEET_NAME + ' vide – export ignoré');
    return;
  }

  var csv = data
    .map(function(row) {
      return row.map(function(cell) {
        return '"' + String(cell).replace(/"/g, '""') + '"';
      }).join(';');
    })
    .join('\n');

  var contentBase64 = Utilities.base64Encode(csv, Utilities.Charset.UTF_8);
  var pathEncoded = encodeURIComponent(GITHUB_CSV_PATH);
  var apiUrl = 'https://api.github.com/repos/' + OUTILS_METIER_CONFIG.owner + '/' + OUTILS_METIER_CONFIG.repo + '/contents/' + pathEncoded;

  var sha = null;
  var getRes = UrlFetchApp.fetch(apiUrl, {
    headers: { Authorization: 'token ' + token, Accept: 'application/vnd.github.v3+json' },
    muteHttpExceptions: true
  });
  if (getRes.getResponseCode() === 200) {
    sha = JSON.parse(getRes.getContentText()).sha;
  }

  var payload = {
    message: 'MAJ ' + SHEET_NAME + ' – ' + new Date().toLocaleString('fr-FR'),
    content: contentBase64,
    branch: OUTILS_METIER_CONFIG.branch
  };
  if (sha) payload.sha = sha;

  var putRes = UrlFetchApp.fetch(apiUrl, {
    method: 'put',
    contentType: 'application/json',
    headers: { Authorization: 'token ' + token, Accept: 'application/vnd.github.v3+json' },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });

  var code = putRes.getResponseCode();
  if (code >= 200 && code < 300) {
    Logger.log('OK ' + SHEET_NAME + ' -> ' + GITHUB_CSV_PATH);
  } else {
    throw new Error('GitHub PUT echec (' + code + ') : ' + putRes.getContentText());
  }
}
