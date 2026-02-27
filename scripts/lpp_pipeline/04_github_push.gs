// @ts-nocheck
/** STEP 4 – Push CSV vers GitHub : 3 colonnes = Code LPP, URL, Libellé (séparateur ;) */

var CSV_SEPARATOR = ";";

function getGithubToken_() {
  return PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN") || (typeof GITHUB_TOKEN !== "undefined" ? GITHUB_TOKEN : "");
}

function fetchCurrentCsvFromGithub_() {
  var token = getGithubToken_();
  if (!token) return null;
  var url = "https://api.github.com/repos/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/contents/" + encodeURIComponent(GITHUB_FILE);
  var headers = { "Authorization": "token " + token, "Accept": "application/vnd.github.v3+json" };
  var get = UrlFetchApp.fetch(url, { method: "get", headers: headers, muteHttpExceptions: true });
  if (get.getResponseCode() !== 200) return null;
  var body = JSON.parse(get.getContentText());
  if (!body.content) return null;
  return Utilities.newBlob(Utilities.base64Decode(body.content)).getDataAsString("UTF-8");
}

function parseCsvCodes_(csvText) {
  if (!csvText || !csvText.length) return [];
  var sep = CSV_SEPARATOR || ";";
  var lines = csvText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  var codes = [];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var first = line.indexOf(sep);
    var code = (first === -1 ? line : line.substring(0, first)).trim();
    if (code && code !== "Code LPP" && code !== "lpp") codes.push(code);
  }
  return codes;
}

function getLppChanges_(newData) {
  var currentCsv = fetchCurrentCsvFromGithub_();
  var oldCodes = currentCsv ? parseCsvCodes_(currentCsv) : [];
  var newCodes = newData.map(function (r) { return String(r.code || ""); }).filter(Boolean);
  var oldSet = {};
  for (var i = 0; i < oldCodes.length; i++) oldSet[oldCodes[i]] = true;
  var newSet = {};
  for (var j = 0; j < newCodes.length; j++) newSet[newCodes[j]] = true;
  var added = [], removed = [];
  for (var k = 0; k < newCodes.length; k++) { if (!oldSet[newCodes[k]]) added.push(newCodes[k]); }
  for (var m = 0; m < oldCodes.length; m++) { if (!newSet[oldCodes[m]]) removed.push(oldCodes[m]); }
  return { added: added, removed: removed, hasChanges: added.length > 0 || removed.length > 0 };
}

function sendLppChangeNotification_(added, removed) {
  var to = typeof NOTIFICATION_EMAIL !== "undefined" ? NOTIFICATION_EMAIL : "";
  if (!to) return;
  var subject = "LPP – Mise à jour GitHub (changements détectés)";
  var body = "Codes ajoutés : " + added.length + "\nCodes supprimés : " + removed.length + "\nFichier : " + GITHUB_FILE;
  MailApp.sendEmail(to, subject, body);
}

/** data = [{ code, url, libelle? }]. CSV 3 colonnes. URL reconstruite (fiche Ameli) si vide. */
function getLppFicheUrl_(code) {
  if (!code) return "";
  var tpl = (typeof URL_TEMPLATE !== "undefined" ? URL_TEMPLATE : "http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI");
  return tpl.replace("{CODE}", String(code));
}

function step4_pushToGithub_(data) {
  var token = getGithubToken_();
  if (!token) throw new Error("GITHUB_TOKEN manquant");

  var sep = CSV_SEPARATOR || ";";
  var header = "Code LPP" + sep + "URL" + sep + "Libellé";
  var bodyRows = data.map(function (r) {
    var url = (r.url && String(r.url).trim() !== "") ? String(r.url).trim() : getLppFicheUrl_(r.code);
    var libelle = r.libelle != null ? String(r.libelle) : "";
    return [String(r.code || ""), url, escapeCsvField_(libelle)].join(sep);
  });
  var csv = header + "\n" + bodyRows.join("\n");
  var encoded = Utilities.base64Encode("\uFEFF" + csv, Utilities.Charset.UTF_8);

  var url = "https://api.github.com/repos/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/contents/" + encodeURIComponent(GITHUB_FILE);
  var headers = { "Authorization": "token " + token, "Accept": "application/vnd.github.v3+json" };
  var sha = null;
  var get = UrlFetchApp.fetch(url, { method: "get", headers: headers, muteHttpExceptions: true });
  if (get.getResponseCode() === 200) sha = JSON.parse(get.getContentText()).sha;

  var payload = { message: "Daily LPP update", content: encoded, branch: GITHUB_BRANCH };
  if (sha) payload.sha = sha;
  UrlFetchApp.fetch(url, { method: "put", contentType: "application/json", headers: headers, payload: JSON.stringify(payload) });
  Logger.log("GitHub mis à jour : " + data.length + " lignes → " + GITHUB_FILE);
}

function escapeCsvField_(v) {
  var s = String(v == null ? "" : v);
  if (s.indexOf(";") !== -1 || s.indexOf('"') !== -1 || s.indexOf("\n") !== -1) return '"' + s.replace(/"/g, '""') + '"';
  return s;
}
