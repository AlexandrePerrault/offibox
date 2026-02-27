/**
 * Vérification des liens morts (URL de l'app Offibox) et envoi d'un mail si au moins un lien est mort.
 * À exécuter tous les matins à 6h (déclencheur à installer une fois avec installTriggerDeadLinks()).
 *
 * Utilise le même classeur que export_outils_metier_to_github.gs (OUTILS_METIER_CONFIG.spreadsheetId).
 * Feuilles scannées : outils métier, sites web, CHU, Centres anti poison, Pharmacovigilance, videos, catalogue, news, Commandes.
 * Colonnes considérées comme URL : en-tête contenant "url", "lien", "site" (insensible à la casse).
 *
 * Email envoyé à : perraultalexandre78@gmail.com (uniquement s'il y a au moins un lien mort).
 */

// Réutiliser la config du projet (même fichier ou même projet Apps Script que export_outils_metier_to_github.gs)
var DEAD_LINKS_CONFIG = {
  spreadsheetId: (typeof OUTILS_METIER_CONFIG !== 'undefined' && OUTILS_METIER_CONFIG.spreadsheetId)
    ? OUTILS_METIER_CONFIG.spreadsheetId
    : '1HVjyHIzGWh_PMOnbRYaWdSJkq4k4CUXeQu5xQBCGIrU',
  emailTo: 'perraultalexandre78@gmail.com',
  requestTimeout: 12,
  sheetNames: [
    'outils métier',
    'sites web',
    'CHU',
    'Centres anti poison',
    'Pharmacovigilance',
    'videos',
    'catalogue',
    'news',
    'Commandes'
  ]
};

var URL_HEADER_PATTERN = /url|lien|site/i;

function isUrl(str) {
  if (str === null || str === undefined) return false;
  var s = String(str).trim();
  return s.length > 8 && (s.indexOf('http://') === 0 || s.indexOf('https://') === 0);
}

function collectUrlsFromSheet(spreadsheet, sheetName) {
  var sheet = spreadsheet.getSheetByName(sheetName);
  if (!sheet) return [];
  var data = sheet.getDataRange().getValues();
  if (data.length < 2) return [];
  var headers = data[0].map(function(h) { return String(h || '').trim(); });
  var urlColIndexes = [];
  for (var c = 0; c < headers.length; c++) {
    if (URL_HEADER_PATTERN.test(headers[c])) urlColIndexes.push(c);
  }
  if (urlColIndexes.length === 0) return [];
  var out = [];
  for (var r = 1; r < data.length; r++) {
    for (var i = 0; i < urlColIndexes.length; i++) {
      var cell = data[r][urlColIndexes[i]];
      if (isUrl(cell)) out.push(String(cell).trim());
    }
  }
  return out;
}

function checkUrl(url) {
  try {
    var resp = UrlFetchApp.fetch(url, {
      method: 'get',
      muteHttpExceptions: true,
      followRedirects: true,
      validateHttpsCertificates: true
    });
    var code = resp.getResponseCode();
    return { ok: code >= 200 && code < 400, code: code, url: url };
  } catch (e) {
    return { ok: false, code: -1, url: url, error: String(e.message || e) };
  }
}

function runDeadLinksCheck() {
  var spreadsheetId = DEAD_LINKS_CONFIG.spreadsheetId;
  var spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  var urlToSheets = {};
  var allUrls = [];

  DEAD_LINKS_CONFIG.sheetNames.forEach(function(sheetName) {
    var urls = collectUrlsFromSheet(spreadsheet, sheetName);
    urls.forEach(function(u) {
      allUrls.push(u);
      if (!urlToSheets[u]) urlToSheets[u] = [];
      if (urlToSheets[u].indexOf(sheetName) === -1) urlToSheets[u].push(sheetName);
    });
  });

  var uniqueUrls = [];
  var seen = {};
  allUrls.forEach(function(u) {
    if (!seen[u]) {
      seen[u] = true;
      uniqueUrls.push(u);
    }
  });

  var dead = [];
  for (var i = 0; i < uniqueUrls.length; i++) {
    var result = checkUrl(uniqueUrls[i]);
    if (!result.ok) {
      dead.push({
        url: result.url,
        code: result.code,
        error: result.error,
        sheets: urlToSheets[result.url] || []
      });
    }
    Utilities.sleep(250);
  }

  if (dead.length === 0) {
    Logger.log('Aucun lien mort.');
    return;
  }

  var subject = 'Offibox – ' + dead.length + ' lien(s) mort(s) détecté(s)';
  var lines = [
    'Les URLs suivantes (utilisées dans l’app Offibox) ne répondent pas correctement.',
    'Feuille(s) : outils métier / sites web / CHU / etc.',
    '',
    'Détail :',
    ''
  ];
  dead.forEach(function(d) {
    lines.push('- ' + d.url);
    lines.push('  Feuille(s) : ' + (d.sheets.join(', ') || '?'));
    lines.push('  Code / erreur : ' + (d.code >= 0 ? d.code : (d.error || 'timeout/erreur')));
    lines.push('');
  });

  MailApp.sendEmail(DEAD_LINKS_CONFIG.emailTo, subject, lines.join('\n'));
  Logger.log('Email envoyé à ' + DEAD_LINKS_CONFIG.emailTo + ' : ' + dead.length + ' lien(s) mort(s).');
}

/** Crée un déclencheur quotidien à 6h (heure du fuseau du projet : Paramètres du projet → Fuseau horaire = Europe/Paris). À exécuter une seule fois. */
function installTriggerDeadLinks() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'runDeadLinksCheck') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }
  ScriptApp.newTrigger('runDeadLinksCheck')
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();
  Logger.log('Déclencheur quotidien à 6h installé pour runDeadLinksCheck.');
}
