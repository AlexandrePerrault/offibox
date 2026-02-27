// @ts-nocheck
/********************************************************
 * Télécharge génériques 2026.csv (semicolon), parse (générique, princeps A, princeps B, CIS),
 * compare avec J-1, injecte dans le Sheet. Col A = "générique de \"PRINCEPS\" (rose)".
 * Optionnel : met à jour la ligne 2 du BDM master pour les produits contenant le princeps.
 * Retourne { added, removed }.
 ********************************************************/

function fetchCisGenerToSheet() {
  var sheetId = CIS_GENER_CONFIG.SHEET_ID;
  if (!sheetId) throw new Error("CIS_GENER_CONFIG.SHEET_ID manquant");
  var ss = SpreadsheetApp.openById(sheetId);
  var sheet = ss.getSheetByName(CIS_GENER_CONFIG.SHEET_NAME);
  if (!sheet) sheet = ss.insertSheet(CIS_GENER_CONFIG.SHEET_NAME);

  var text = fetchCisGenerFile(CIS_GENER_CONFIG.CIS_GENER_URL);
  var rows = parseCisGenerCsv(text);
  if (rows.length === 0) {
    Logger.log("Aucune ligne parsée");
    return { added: [], removed: [], addedCount: 0, removedCount: 0 };
  }

  var keysToday = {};
  for (var i = 0; i < rows.length; i++) {
    keysToday[rowKey_(rows[i])] = true;
  }
  var prev = readPrevKeysFromSheet_(ss);
  var added = [];
  var removed = [];
  for (var k in keysToday) if (!prev[k]) added.push(k);
  for (var k in prev) if (!keysToday[k]) removed.push(k);
  writePrevKeysToSheet_(ss, keysToday);

  // En-tête + lignes : col A = "générique de \"PRINCEPS_A_MAJ\" (rose)", B = princeps A, C = princeps B, D = CIS
  var data = [["générique", "princeps A", "princeps B", "CIS"]];
  for (var j = 0; j < rows.length; j++) {
    var r = rows[j];
    var princepsAMaj = extractUppercasePrinceps_(r.princepsA);
    var colA = 'générique de "' + princepsAMaj + '" (rose)';
    data.push([colA, r.princepsA, r.princepsB, r.cis]);
  }
  sheet.clear();
  sheet.getRange(1, 1, data.length, 4).setValues(data);
  sheet.getRange(1, 1, 1, 4).setFontWeight("bold");

  if (CIS_GENER_CONFIG.BDM_MASTER_SHEET_ID && String(CIS_GENER_CONFIG.BDM_MASTER_SHEET_ID).trim()) {
    updateBdmMasterLine2_(rows);
  }

  Logger.log("CIS_GENER: " + rows.length + " lignes, ajouts: " + added.length + ", suppressions: " + removed.length);
  return { added: added, removed: removed, addedCount: added.length, removedCount: removed.length };
}

function fetchCisGenerFile(url) {
  var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (resp.getResponseCode() !== 200) throw new Error("Erreur téléchargement: " + url);
  var blob = resp.getBlob();
  var textUtf8 = blob.getDataAsString("UTF-8");
  if (/[\uFFFD]/.test(textUtf8)) {
    return blob.getDataAsString("ISO-8859-1");
  }
  return textUtf8;
}

/**
 * Parse CSV semicolon-separated avec champs entre guillemets. Colonnes : générique, princeps A, princeps B, CIS.
 * Ignore la ligne d'en-tête si la première colonne est "générique".
 */
function parseCisGenerCsv(text) {
  var out = [];
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (!line.trim()) continue;
    var cols = parseCsvLine_(line);
    if (cols.length < 4) continue;
    var firstCol = String(cols[0] || "").trim();
    if (firstCol === "générique") continue; // en-tête
    var generique = normalizeCisGenerText_(firstCol);
    var princepsA = normalizeCisGenerText_(String(cols[1] || "").trim());
    var princepsB = normalizeCisGenerText_(String(cols[2] || "").trim());
    var cis = String(cols[3] || "").trim().replace(/\D/g, "");
    if (!generique || !cis) continue;
    out.push({ generique: generique, princepsA: princepsA, princepsB: princepsB, cis: cis });
  }
  return out;
}

/** Parse une ligne CSV avec champs entre guillemets, séparateur ; */
function parseCsvLine_(line) {
  var out = [];
  var inQuotes = false;
  var cell = "";
  for (var i = 0; i < line.length; i++) {
    var c = line.charAt(i);
    if (c === '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (!inQuotes && c === ";") {
      out.push(cell);
      cell = "";
      continue;
    }
    cell += c;
  }
  out.push(cell);
  return out;
}

/** Extrait la partie en majuscules du princeps A (ex: "TAGAMET 200 mg, comprimé" → "TAGAMET"). */
function extractUppercasePrinceps_(princepsA) {
  if (typeof princepsA !== "string" || !princepsA.length) return "";
  var m = princepsA.match(/^([A-Z][A-Z0-9\s\-]*?)(?=\s+\d|\s*,|$)/);
  if (m) return m[1].trim();
  var firstWord = princepsA.split(/\s+/)[0] || "";
  return firstWord.toUpperCase();
}

/**
 * Normalise le texte : encodage (mojibake), caractère de remplacement (), termes pharmaceutiques courants.
 */
function normalizeCisGenerText_(s) {
  if (typeof s !== "string" || !s.length) return s;
  return s
    .replace(/comprim\uFFFD/g, "comprimé").replace(/comprim\uFFFDs/g, "comprimés")
    .replace(/pellicul\uFFFD/g, "pelliculé").replace(/pellicul\uFFFDs/g, "pelliculés").replace(/pelicul\uFFFD/g, "pelliculé")
    .replace(/g\uFFFDlule/g, "gélule").replace(/g\uFFFDlules/g, "gélules")
    .replace(/s\uFFFDcable/g, "sécable").replace(/lib\uFFFDration/g, "libération").replace(/r\uFFFDsistant/g, "résistant")
    .replace(/prolong\uFFFDe/g, "prolongée").replace(/n\uFFFDbuliseur/g, "nébuliseur")
    .replace(/\uFFFD/g, "é")
    .replace(/Ã©/g, "é").replace(/Ã¨/g, "è").replace(/Ãª/g, "ê").replace(/Ã«/g, "ë")
    .replace(/Ã /g, "à").replace(/Ã¢/g, "â").replace(/Ã®/g, "î").replace(/Ã¯/g, "ï")
    .replace(/Ã´/g, "ô").replace(/Ã¹/g, "ù").replace(/Ã»/g, "û").replace(/Ã§/g, "ç")
    .replace(/Å“/g, "œ").replace(/Å'/g, "Œ")
    .replace(/comprim\?/g, "comprimé").replace(/comprim\?s/g, "comprimés")
    .replace(/g\?lule/g, "gélule").replace(/g\?lules/g, "gélules").replace(/gelule/g, "gélule").replace(/gelules/g, "gélules")
    .replace(/pellicul\?/g, "pelliculé").replace(/pellicul\?s/g, "pelliculés").replace(/pelicul\?/g, "pelliculé")
    .replace(/s\?cable/g, "sécable").replace(/s\?cables/g, "sécables")
    .replace(/r\?sistant/g, "résistant").replace(/lib\?ration/g, "libération")
    .replace(/prolong\?e/g, "prolongée").replace(/prolong\?s/g, "prolongés")
    .replace(/n\?buliseur/g, "nébuliseur").replace(/ solution \? diluer/g, " solution à diluer")
    .replace(/\s\?\s/g, " à ");
}

function rowKey_(row) {
  return (row.cis + "|" + row.generique + "|" + row.princepsA + "|" + row.princepsB);
}

function readPrevKeysFromSheet_(ss) {
  var prev = {};
  var sh = ss.getSheetByName(CIS_GENER_CONFIG.SHEET_NAME_PREV_KEYS);
  if (!sh) return prev;
  var values = sh.getDataRange().getValues();
  for (var i = 0; i < values.length; i++) {
    var k = String(values[i][0] || "").trim();
    if (k) prev[k] = true;
  }
  return prev;
}

function writePrevKeysToSheet_(ss, keysToday) {
  var sh = ss.getSheetByName(CIS_GENER_CONFIG.SHEET_NAME_PREV_KEYS);
  if (!sh) sh = ss.insertSheet(CIS_GENER_CONFIG.SHEET_NAME_PREV_KEYS);
  var keys = [];
  for (var k in keysToday) keys.push(k);
  sh.clear();
  if (keys.length > 0) {
    var data = keys.map(function (k) { return [k]; });
    var batch = 10000;
    for (var start = 0; start < data.length; start += batch) {
      var end = Math.min(start + batch, data.length);
      var numRows = end - start;
      sh.getRange(start + 1, 1, start + numRows, 1).setValues(data.slice(start, end));
    }
  }
}

/**
 * Pour chaque produit du BDM master dont la dénomination contient le princeps (col B du CSV),
 * met en "ligne 2" (colonne configurée) : "générique : [col A du CSV en majuscules]".
 * Note : Déplacer RCP et badge MEDDISPAR à la fin et les retirer de la ligne 3 n'est pas implémenté
 * (les données RCP/MEDDISPAR ne sont pas dans le CSV génériques ; à traiter côté BDM master si besoin).
 */
function updateBdmMasterLine2_(rows) {
  var bdmId = String(CIS_GENER_CONFIG.BDM_MASTER_SHEET_ID).trim();
  var sheetName = CIS_GENER_CONFIG.BDM_MASTER_SHEET_NAME || "BDM_ACTIVE";
  var line2Col = Math.max(1, parseInt(CIS_GENER_CONFIG.BDM_LINE2_COL, 10) || 11);
  if (!bdmId) return;

  var princepsToGeneric = {};
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    var princepsAMaj = extractUppercasePrinceps_(r.princepsA);
    if (!princepsAMaj) continue;
    var genericMaj = (r.generique || "").toUpperCase().trim();
    if (!genericMaj) continue;
    princepsToGeneric[princepsAMaj] = genericMaj;
  }

  var bdmSs = SpreadsheetApp.openById(bdmId);
  var bdmSheet = bdmSs.getSheetByName(sheetName);
  if (!bdmSheet) {
    Logger.log("BDM sheet introuvable: " + sheetName);
    return;
  }

  var values = bdmSheet.getDataRange().getValues();
  var lastRow = values.length;
  if (lastRow < 2) return;

  var updates = [];
  for (var rowIdx = 1; rowIdx < lastRow; rowIdx++) {
    var denom = String(values[rowIdx][0] || "").trim();
    if (!denom) continue;
    var denomUpper = denom.toUpperCase();
    for (var princeps in princepsToGeneric) {
      if (denomUpper.indexOf(princeps) !== -1) {
        var line2Value = "générique : " + princepsToGeneric[princeps];
        updates.push({ row: rowIdx + 1, col: line2Col, value: line2Value });
        break;
      }
    }
  }

  for (var u = 0; u < updates.length; u++) {
    var o = updates[u];
    bdmSheet.getRange(o.row, o.col).setValue(o.value);
  }
  if (updates.length > 0) {
    Logger.log("BDM master: " + updates.length + " lignes mises à jour (ligne 2 = générique)");
  }
}
