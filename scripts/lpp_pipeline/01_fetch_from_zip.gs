// @ts-nocheck
/**
 * STEP 1 – Récupère le ZIP LPPTOT depuis l'URL, extrait le contenu, parse les blocs pour
 * retrouver le code LPP (7 derniers chiffres du bloc initial) et le libellé, insère en col B.
 *
 * Format attendu dans le fichier (ex. décodé cp1252) :
 * 10101011203248 SIEGE DE SERIE, SIEGE MODULABLE ET EVOLUTIF, TABLETTE AMOVIBLE. 101020100000000000AO...
 * → code LPP = 1203248 (7 derniers chiffres de 10101011203248)
 * → libellé = SIEGE DE SERIE, SIEGE MODULABLE ET EVOLUTIF, TABLETTE AMOVIBLE.
 *
 * @return {Array<{code: string, url: string, libelle: string}>}
 */
function step1_fetchAndParseFromZip_() {
  var zipUrl = typeof LPP_ZIP_URL !== "undefined" ? LPP_ZIP_URL : "http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip";
  var urlTpl = typeof URL_TEMPLATE !== "undefined" ? URL_TEMPLATE : "https://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI";

  var response = UrlFetchApp.fetch(zipUrl, {
    muteHttpExceptions: true,
    headers: { "User-Agent": "Mozilla/5.0 (compatible; Offibox LPP pipeline)" }
  });
  if (response.getResponseCode() !== 200) {
    throw new Error("Erreur fetch ZIP LPP : " + response.getResponseCode());
  }

  var zipBlob = response.getBlob();
  zipBlob.setContentType("application/zip");
  var files = Utilities.unzip(zipBlob);
  if (!files || files.length === 0) throw new Error("ZIP LPP vide");

  var firstBlob = files[0];
  // Lecture directe (sans charset : UTF-8 par défaut). Si le fichier est en Latin-1, les accents peuvent être mal lus.
  var text = firstBlob.getDataAsString();

  // Regex : bloc digits (10+), espace, libellé (lettres/accents/ponctuation), puis espace(s) et prochain bloc digits
  // Ex: 10101011203248 SIEGE DE SERIE, ... TABLETTE AMOVIBLE. 10102010000000...
  var re = /(\d{10,})\s+([A-Za-z\u00C0-\u00FF][\s\S]*?)\s+\d{10,}/g;
  var seen = {};
  var out = [];
  var m;

  while ((m = re.exec(text)) !== null) {
    var digitsBlock = m[1];
    var libelle = (m[2] || "").replace(/\s+/g, " ").trim();
    if (libelle.length < 3) continue;

    // Code LPP = 7 derniers chiffres du bloc
    var code = digitsBlock.length >= 7 ? digitsBlock.slice(-7) : null;
    if (!code || !/^\d{7}$/.test(code)) continue;
    if (seen[code]) continue;
    seen[code] = true;

    out.push({
      code: code,
      url: urlTpl.replace("{CODE}", code),
      libelle: libelle
    });
  }

  Logger.log("step1_fetchAndParseFromZip_ : " + out.length + " entrées extraites du ZIP");
  return out;
}
