// @ts-nocheck
/** STEP 2 – Extraire les codes à 7 chiffres depuis les valeurs d'une feuille (col A), construire l'URL, optionnellement récupérer le libellé (Désignation) depuis la page Ameli. */

var URL_TEMPLATE_FALLBACK = "http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI";

/** Délai en ms entre deux requêtes HTTP (éviter surcharge du serveur Ameli). */
var FETCH_DESIGNATION_DELAY_MS = 150;

/**
 * Extrait le code à 7 chiffres d'une chaîne (ex. "(CODE LPP) 1100028" ou "1100028").
 * @param {string} cellValue - Valeur d'une cellule (col A de la feuille source)
 * @return {string|null} - Code à 7 chiffres ou null
 */
function extractSevenDigitCode_(cellValue) {
  if (cellValue == null || typeof cellValue !== "string") return null;
  var s = cellValue.trim();
  // "(CODE LPP) 1100028" → 1100028
  var match = s.match(/(\d{7})\b/);
  if (match) return match[1];
  if (/^\d{7}$/.test(s)) return s;
  return null;
}

/**
 * Récupère le libellé (Désignation) depuis la page Ameli pour une URL donnée.
 * Ex. "EPAULE, TIGE HUMERALE STANDARD, MODULAIRE,ZIMMER BIOMET"
 * @param {string} url - URL de la fiche LPP (cgi-fiche?p_code_tips=...)
 * @return {string} - Libellé ou chaîne vide si non trouvé / erreur
 */
function fetchDesignationFromUrl_(url) {
  try {
    var response = UrlFetchApp.fetch(url, {
      muteHttpExceptions: true,
      followRedirects: true,
      headers: { "User-Agent": "Mozilla/5.0 (compatible; Offibox LPP pipeline)" }
    });
    if (response.getResponseCode() !== 200) return "";
    var html = response.getContentText("UTF-8");
    if (!html || html.length < 50) return "";
    // Page : ligne type "Désignation | : | EPAULE, TIGE HUMERALE..."
    // En HTML : <td>Désignation</td><td>:</td><td>VALUE</td> ou similaire
    var m = html.match(/Désignation\s*<\/t[dh]>\s*<t[dh][^>]*>[\s\S]*?<\/t[dh]>\s*<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/i);
    if (!m || !m[1]) {
      // Fallback : après "Désignation" puis ":", prendre le texte jusqu'au prochain <
      m = html.match(/Désignation[\s\S]*?:\s*([^<]+)/i);
    }
    if (!m || !m[1]) return "";
    var libelle = m[1].replace(/\s+/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').trim();
    return libelle;
  } catch (e) {
    Logger.log("fetchDesignationFromUrl_ error: " + e.toString());
    return "";
  }
}

/**
 * Enrichit les entrées [{ code, url }] avec le champ libelle en interrogeant chaque URL.
 * Limite optionnelle pour ne pas dépasser le quota / temps d'exécution (ex. 500).
 * @param {Array<{code: string, url: string}>} data
 * @param {number} [maxToFetch] - Nombre max d'URL à appeler (défaut : toutes)
 * @return {Array<{code: string, url: string, libelle: string}>}
 */
function step2b_enrichWithDesignation_(data, maxToFetch) {
  var limit = (typeof maxToFetch === "number" && maxToFetch > 0) ? Math.min(maxToFetch, data.length) : data.length;
  var delay = (typeof FETCH_DESIGNATION_DELAY_MS === "number" && FETCH_DESIGNATION_DELAY_MS > 0) ? FETCH_DESIGNATION_DELAY_MS : 100;
  for (var i = 0; i < data.length; i++) {
    if (!data[i].libelle) data[i].libelle = "";
    if (i >= limit) continue;
    data[i].libelle = fetchDesignationFromUrl_(data[i].url);
    if (delay > 0 && i < data.length - 1) Utilities.sleep(delay);
  }
  return data;
}

/**
 * À partir des valeurs de la colonne A (feuille source), retourne [{ code, url [, libelle ] }].
 * Déduplique par code. Ne récupère pas le libellé ici (appeler step2b_enrichWithDesignation_ après si besoin).
 * @param {string[]} columnAValues - Tableau des valeurs de la colonne A
 * @return {Array<{code: string, url: string, libelle?: string}>}
 */
function step2_extractCodesAndUrls_(columnAValues) {
  var urlTpl = (typeof URL_TEMPLATE !== "undefined" ? URL_TEMPLATE : URL_TEMPLATE_FALLBACK);
  var seen = {};
  var out = [];
  for (var i = 0; i < columnAValues.length; i++) {
    var code = extractSevenDigitCode_(columnAValues[i]);
    if (code && !seen[code]) {
      seen[code] = true;
      out.push({
        code: code,
        url: urlTpl.replace("{CODE}", code),
        libelle: ""
      });
    }
  }
  return out;
}
