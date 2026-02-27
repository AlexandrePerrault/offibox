// Export des feuilles "outils métier", "sites web", "Commandes", "catalogue", "news", "videos", "CHU", "Centres anti poison", "Pharmacovigilance" vers GitHub (9 CSV).
// À copier dans Apps Script du Google Sheet concerné.
// Propriétés du script : GITHUB_TOKEN
// Constantes dans un objet pour éviter conflit avec d'autres scripts (GITHUB_OWNER, etc.).

var OUTILS_METIER_CONFIG = {
  owner: 'AlexandrePerrault',
  repo: 'offiboxdata',
  branch: 'main',
  spreadsheetId: '1HVjyHIzGWh_PMOnbRYaWdSJkq4k4CUXeQu5xQBCGIrU'
};

function pushSheetToGitHub(spreadsheetId, sheetName, githubPath) {
  // Appel à 2 arguments : pushSheetToGitHub(sheetName, githubPath) → on utilise la config pour l'ID
  if (arguments.length === 2 && typeof OUTILS_METIER_CONFIG !== 'undefined' && OUTILS_METIER_CONFIG.spreadsheetId) {
    spreadsheetId = OUTILS_METIER_CONFIG.spreadsheetId;
    sheetName = arguments[0];
    githubPath = arguments[1];
  }
  // Appel sans sheetName/githubPath valides -> export de toutes les feuilles (outils metier, sites web, Commandes, catalogue, news, videos)
  if ((!sheetName || typeof sheetName !== 'string' || !githubPath || typeof githubPath !== 'string') &&
      typeof OUTILS_METIER_CONFIG !== 'undefined' && OUTILS_METIER_CONFIG.spreadsheetId) {
    exportAllSheets();
    return;
  }
  if (!spreadsheetId || typeof spreadsheetId !== 'string') {
    if (typeof OUTILS_METIER_CONFIG !== 'undefined' && OUTILS_METIER_CONFIG.spreadsheetId) {
      spreadsheetId = OUTILS_METIER_CONFIG.spreadsheetId;
    } else {
      throw new Error('❌ spreadsheetId invalide : ' + spreadsheetId);
    }
  } else {
    spreadsheetId = spreadsheetId.trim();
  }
  if (!sheetName || typeof sheetName !== 'string') {
    throw new Error('❌ sheetName invalide : ' + sheetName);
  }
  if (!githubPath || typeof githubPath !== 'string') {
    throw new Error('❌ githubPath invalide : ' + githubPath);
  }

  const token = PropertiesService
    .getScriptProperties()
    .getProperty('GITHUB_TOKEN');

  if (!token) throw new Error('❌ GITHUB_TOKEN manquant');

  const sheet = SpreadsheetApp
    .openById(spreadsheetId)
    .getSheetByName(sheetName);

  if (!sheet) throw new Error('❌ Feuille "' + sheetName + '" introuvable');

  const data = sheet.getDataRange().getValues();
  if (data.length < 1) {
    Logger.log('⚠️ ' + sheetName + ' vide – export ignoré');
    return;
  }
  if (data.length < 2) {
    Logger.log('⚠️ ' + sheetName + ' : une seule ligne (en-tête) – export tout de même');
  }

  const csv = data
    .map(function(row) {
      return row.map(function(cell) {
        return '"' + String(cell).replace(/"/g, '""') + '"';
      }).join(';');
    })
    .join('\n');

  const contentBase64 = Utilities.base64Encode(csv, Utilities.Charset.UTF_8);

  const apiUrl =
    'https://api.github.com/repos/' + OUTILS_METIER_CONFIG.owner + '/' + OUTILS_METIER_CONFIG.repo + '/contents/' + githubPath;

  var sha = null;
  const res = UrlFetchApp.fetch(apiUrl, {
    headers: { Authorization: 'token ' + token },
    muteHttpExceptions: true,
  });

  if (res.getResponseCode() === 200) {
    sha = JSON.parse(res.getContentText()).sha;
  }

  const payload = {
    message: '🔄 MAJ ' + sheetName + ' – ' + new Date().toLocaleString('fr-FR'),
    content: contentBase64,
    branch: OUTILS_METIER_CONFIG.branch,
  };

  if (sha) payload.sha = sha;

  UrlFetchApp.fetch(apiUrl, {
    method: 'put',
    contentType: 'application/json',
    headers: { Authorization: 'token ' + token },
    payload: JSON.stringify(payload),
  });

  Logger.log('✅ ' + sheetName + ' → ' + githubPath);
}

/** Exporte la feuille "outils métier" vers outils_metier.csv sur GitHub. */
function exportOutilsMetier() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'outils métier',
    'outils_metier.csv'
  );
}

/** Exporte la feuille "sites web" vers sites_web.csv sur GitHub. */
function exportSitesWeb() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'sites web',
    'sites_web.csv'
  );
}

/** Exporte la feuille "Commandes" vers commandes.csv sur GitHub. */
function exportCommandes() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'Commandes',
    'commandes.csv'
  );
}

/** Exporte la feuille "catalogue" vers catalogue.csv sur GitHub. */
function exportCatalogue() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'catalogue',
    'catalogue.csv'
  );
}

/** Exporte la feuille "news" vers news.csv sur GitHub. */
function exportNews() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'news',
    'news.csv'
  );
}

/** Exporte la feuille "videos" vers videos.csv sur GitHub. */
function exportVideos() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'videos',
    'videos.csv'
  );
}

/** Exporte la feuille "CHU" vers chu.csv sur GitHub. */
function exportCHU() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'CHU',
    'chu.csv'
  );
}

/** Exporte la feuille "Centres anti poison" vers centres_anti_poison.csv sur GitHub. */
function exportCentresAntiPoison() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'Centres anti poison',
    'centres_anti_poison.csv'
  );
}

/** Exporte la feuille "Pharmacovigilance" vers pharmacovigilance.csv sur GitHub. */
function exportPharmacovigilance() {
  pushSheetToGitHub(
    OUTILS_METIER_CONFIG.spreadsheetId,
    'Pharmacovigilance',
    'pharmacovigilance.csv'
  );
}

/** Lance l'export des neuf feuilles (outils métier, sites web, Commandes, catalogue, news, videos, CHU, Centres anti poison, Pharmacovigilance) → 9 CSV. */
function exportAllSheets() {
  exportOutilsMetier();
  exportSitesWeb();
  exportCommandes();
  exportCatalogue();
  exportNews();
  exportVideos();
  exportCHU();
  exportCentresAntiPoison();
  exportPharmacovigilance();
}

/** Alias pour compatibilité : lance l'export de toutes les feuilles. */
function exportOutilsMetierEtSitesWeb() {
  exportAllSheets();
}
