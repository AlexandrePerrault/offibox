// Export des feuilles "outils métier", "sites web", "Commandes", "catalogue", "news", "videos" vers GitHub (6 CSV).
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

  var maxAttempts = 3;
  var lastError = null;

  while (maxAttempts-- > 0) {
    var sha = null;
    var res = UrlFetchApp.fetch(apiUrl, {
      headers: { Authorization: 'token ' + token },
      muteHttpExceptions: true,
    });

    if (res.getResponseCode() === 200) {
      sha = JSON.parse(res.getContentText()).sha;
    }

    var payload = {
      message: '🔄 MAJ ' + sheetName + ' – ' + new Date().toLocaleString('fr-FR'),
      content: contentBase64,
      branch: OUTILS_METIER_CONFIG.branch,
    };
    if (sha) payload.sha = sha;

    res = UrlFetchApp.fetch(apiUrl, {
      method: 'put',
      contentType: 'application/json',
      headers: { Authorization: 'token ' + token },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true,
    });

    var code = res.getResponseCode();
    if (code === 200 || code === 201) {
      Logger.log('✅ ' + sheetName + ' → ' + githubPath);
      return;
    }
    if (code === 409) {
      // Référence ou fichier modifié entre GET et PUT (autre push ou export précédent) → refaire un GET puis PUT.
      lastError = res.getContentText();
      Logger.log('⚠️ 409 sur ' + githubPath + ', nouvel essai… (' + maxAttempts + ' restants)');
      continue;
    }
    throw new Error('Erreur GitHub ' + code + ' pour ' + githubPath + ': ' + res.getContentText());
  }

  throw new Error('Échec après 3 essais (409 conflit) pour ' + githubPath + ': ' + lastError);
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

/** Lance l'export des six feuilles (outils métier, sites web, Commandes, catalogue, news, videos) → 6 CSV. */
function exportAllSheets() {
  exportOutilsMetier();
  exportSitesWeb();
  exportCommandes();
  exportCatalogue();
  exportNews();
  exportVideos();
}

/** Alias pour compatibilité : lance l'export de toutes les feuilles. */
function exportOutilsMetierEtSitesWeb() {
  exportAllSheets();
}
