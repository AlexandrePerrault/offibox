// @ts-nocheck
/**
 * Récupère la page fiches VOC, parse le tableau (médicament, fiche patient, fiche pro),
 * injecte dans la feuille : col 1 = nom médicament, col 2 = URL fiche patient, col 3 = URL fiche pro.
 * À exécuter manuellement ou via déclencheur mensuel (1er du mois).
 */

/**
 * Strip HTML tags and decode common entities.
 * @param {string} html
 * @return {string}
 */
function stripHtml_(html) {
  if (!html || typeof html !== 'string') return '';
  var s = html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
  return s;
}

/**
 * Normalise le libellé médicament : enlève &reg; / ® et décode les entités HTML (é, è, à, ï, etc.).
 * @param {string} str
 * @return {string}
 */
function vocNormalizeMedicationName_(str) {
  if (!str || typeof str !== 'string') return '';
  var s = str
    .replace(/&reg;/gi, '')
    .replace(/\u00AE/g, '')  // ®
    .replace(/&eacute;/gi, '\u00E9')
    .replace(/&egrave;/gi, '\u00E8')
    .replace(/&agrave;/gi, '\u00E0')
    .replace(/&aacute;/gi, '\u00E1')
    .replace(/&ecirc;/gi, '\u00EA')
    .replace(/&iuml;/gi, '\u00EF')
    .replace(/&icirc;/gi, '\u00EE')
    .replace(/&ocirc;/gi, '\u00F4')
    .replace(/&ucirc;/gi, '\u00FB')
    .replace(/&ccedil;/gi, '\u00E7')
    .replace(/&Ccedil;/g, '\u00C7')
    .replace(/&ugrave;/gi, '\u00F9')
    .replace(/\s+/g, ' ')
    .trim();
  return s;
}

/**
 * Télécharge la page HTML des fiches VOC.
 * @return {string}
 */
function vocFetchPage_() {
  var url = typeof OMEDIT_VOC_CONFIG !== 'undefined' && OMEDIT_VOC_CONFIG.sourceUrl
    ? OMEDIT_VOC_CONFIG.sourceUrl
    : 'https://www.omedit-fiches-cancer.fr/fiches-voie-orale-contre-le-cancer-voc/fiches-voie-orale-contre-le-cancer-voc,6093,13536.html';
  var baseUrl = typeof OMEDIT_VOC_CONFIG !== 'undefined' && OMEDIT_VOC_CONFIG.baseUrl
    ? OMEDIT_VOC_CONFIG.baseUrl
    : 'https://www.omedit-fiches-cancer.fr';

  var response = UrlFetchApp.fetch(url, {
    followRedirects: true,
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() !== 200) {
    throw new Error('Erreur téléchargement page VOC : ' + response.getResponseCode());
  }

  var html = response.getContentText('UTF-8');
  return html;
}

/**
 * Extrait les lignes du tableau : pour chaque ligne, { name, urlPatient, urlPro }.
 * On cherche <tr>...</tr>, puis dans chaque ligne les liens /media-files/...pdf (pro vs patient).
 * @param {string} html
 * @return {Array<{name: string, urlPatient: string, urlPro: string}>}
 */
function vocParseTable_(html) {
  var baseUrl = (typeof OMEDIT_VOC_CONFIG !== 'undefined' && OMEDIT_VOC_CONFIG.baseUrl)
    ? OMEDIT_VOC_CONFIG.baseUrl
    : 'https://www.omedit-fiches-cancer.fr';

  var rows = [];
  // Récupérer les lignes du tableau : <tr ...> ... </tr>
  var trRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  var trMatch;
  var isFirst = true;

  while ((trMatch = trRegex.exec(html)) !== null) {
    var rowHtml = trMatch[1];
    // Ignorer la ligne d'en-tête (souvent "Méthodologie" ou première ligne vide)
    if (isFirst) {
      isFirst = false;
      if (/<th[\s>]|Méthodologie|Pour télécharger|rechercher une fiche/i.test(rowHtml)) continue;
    }

    // Première cellule = nom du médicament (texte entre <td> et </td> ou <th> et </th>)
    var firstCellMatch = rowHtml.match(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/i);
    var rawName = firstCellMatch ? stripHtml_(firstCellMatch[1]) : '';
    var name = vocNormalizeMedicationName_(rawName);

    // Tous les liens PDF internes (media-files)
    var hrefRegex = /href=["']([^"']*\/media-files\/[^"']+\.pdf)["']/gi;
    var hrefMatch;
    var allPdfs = [];
    while ((hrefMatch = hrefRegex.exec(rowHtml)) !== null) {
      var href = hrefMatch[1];
      if (href.indexOf('http') !== 0) href = baseUrl + (href.indexOf('/') === 0 ? href : '/' + href);
      allPdfs.push(href);
    }

    // Fiche pro : lien contenant "-pro" ou "pro-" (et pas "patient")
    // Fiche patient FR : lien contenant "patient" (on évite "patient-anglais" ou "Patient-en" pour la version FR)
    var urlPro = '';
    var urlPatient = '';
    for (var i = 0; i < allPdfs.length; i++) {
      var p = allPdfs[i];
      var lower = p.toLowerCase();
      if ((lower.indexOf('-pro') !== -1 || lower.indexOf('pro-') !== -1) && lower.indexOf('patient') === -1 && !urlPro) {
        urlPro = p;
      }
      if (lower.indexOf('patient') !== -1 && (lower.indexOf('anglais') === -1 && lower.indexOf('-en.') === -1) && !urlPatient) {
        urlPatient = p;
      }
    }

    // Si on n'a pas trouvé de "patient" sans "anglais", prendre le premier lien patient
    if (!urlPatient && allPdfs.length >= 2) {
      for (var j = 0; j < allPdfs.length; j++) {
        if (allPdfs[j].toLowerCase().indexOf('patient') !== -1) {
          urlPatient = allPdfs[j];
          break;
        }
      }
    }

    if (name || urlPro || urlPatient) {
      rows.push({
        name: name || '',
        urlPatient: urlPatient || '',
        urlPro: urlPro || ''
      });
    }
  }

  return rows;
}

/**
 * Lance le fetch + parse et injecte dans la feuille "VOC" du spreadsheet configuré.
 * Col 1 = nom médicament, Col 2 = URL fiche patient, Col 3 = URL fiche pro.
 */
function vocFetchAndInjectSheet() {
  var config = typeof OMEDIT_VOC_CONFIG !== 'undefined' ? OMEDIT_VOC_CONFIG : {};
  var spreadsheetId = config.spreadsheetId;
  var sheetName = config.sheetName || 'VOC';

  if (!spreadsheetId || spreadsheetId === '') {
    throw new Error('OMEDIT_VOC_CONFIG.spreadsheetId doit être renseigné (ID du Google Sheet).');
  }

  var html = vocFetchPage_();
  var rows = vocParseTable_(html);

  var ss = SpreadsheetApp.openById(spreadsheetId);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
  }

  sheet.clear();
  var data = [['Médicament', 'URL fiche patient', 'URL fiche professionnel']];
  for (var i = 0; i < rows.length; i++) {
    data.push([rows[i].name, rows[i].urlPatient, rows[i].urlPro]);
  }
  sheet.getRange(1, 1, data.length, 3).setValues(data);
  sheet.autoResizeColumns(1, 3);

  Logger.log('VOC : ' + rows.length + ' lignes injectées dans la feuille "' + sheetName + '"');
  return rows.length;
}
