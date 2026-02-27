// @ts-nocheck
/***************************************
 * STEP 2 – Téléchargement et parsing du fichier TXT
 * Format attendu : tab ou virgule ; colonne F (index 5) = date MAJ
 * Normalisation des libellés (encodage : Remise à disposition, Arrêt de commercialisation).
 ***************************************/

/**
 * Normalise les libellés mal encodés ( → é/à).
 * @param {string} s
 * @return {string}
 */
function normalizeCell_(s) {
  if (!s || typeof s !== "string") return s;
  var t = s
    .replace(/Remise\s*\uFFFD\s*disposition/gi, "Remise à disposition")
    .replace(/Remise\s+disposition/gi, "Remise à disposition")
    .replace(/Ar\uFFFDt/gi, "Arrêt")
    .replace(/Arrt(\s+de)?/gi, "Arrêt$1")
    .replace(/\uFFFD/g, " ");
  return t.trim();
}

/**
 * Télécharge le fichier TXT et retourne le contenu brut.
 * Essai UTF-8 puis ISO-8859-1 si besoin.
 * @return {string}
 */
function step2_fetchTxt_() {
  var response = UrlFetchApp.fetch(SOURCE_TXT_URL, {
    followRedirects: true,
    headers: { "User-Agent": "Mozilla/5.0" },
    muteHttpExceptions: true
  });
  if (response.getResponseCode() !== 200) {
    throw new Error("Erreur téléchargement CIS_CIP_Dispo_Spec.txt : " + response.getResponseCode());
  }
  var blob = response.getBlob();
  var text = blob.getDataAsString("UTF-8");
  if (text.indexOf("\uFFFD") !== -1) {
    text = blob.getDataAsString("ISO-8859-1");
  }
  return text;
}

/**
 * Parse le contenu TXT en tableau de lignes (chaque ligne = tableau de colonnes).
 * Séparateur : tabulation si présente, sinon virgule. Chaque cellule est normalisée.
 * @param {string} rawText
 * @return {string[][]} [ headerRow, ...dataRows ]
 */
function step2_parseTxt_(rawText) {
  if (!rawText || rawText.length < 2) return [];
  var lines = rawText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  var out = [];
  var sep = rawText.indexOf("\t") !== -1 ? "\t" : ",";
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.trim().length === 0) continue;
    var row = line.split(sep).map(function (cell) { return normalizeCell_((cell || "").trim()); });
    out.push(row);
  }
  return out;
}
