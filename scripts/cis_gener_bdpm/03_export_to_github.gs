// @ts-nocheck
/********************************************************
 * Exporte le contenu du Sheet CIS_GENER vers GitHub (CSV).
 ********************************************************/

function exportCisGenerToGithub() {
  var token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("GITHUB_TOKEN manquant (Propriétés du script)");
  var ss = SpreadsheetApp.openById(CIS_GENER_CONFIG.SHEET_ID);
  var sheet = ss.getSheetByName(CIS_GENER_CONFIG.SHEET_NAME);
  if (!sheet) throw new Error("Exécuter d'abord fetchCisGenerToSheet()");
  var values = sheet.getDataRange().getValues();
  if (values.length < 2) throw new Error("Sheet vide. Exécuter fetchCisGenerToSheet().");
  var csv = values.map(function (row) {
    return row.map(function (v) { return '"' + String(v || "").replace(/"/g, '""') + '"'; }).join(";");
  }).join("\n");
  var apiUrl = "https://api.github.com/repos/" + CIS_GENER_CONFIG.GITHUB_OWNER + "/" + CIS_GENER_CONFIG.GITHUB_REPO + "/contents/" + CIS_GENER_CONFIG.GITHUB_PATH_CSV;
  var opts = { headers: { Authorization: "token " + token, Accept: "application/vnd.github.v3+json" }, muteHttpExceptions: true };
  var sha = null;
  var get = UrlFetchApp.fetch(apiUrl, opts);
  if (get.getResponseCode() === 200) sha = JSON.parse(get.getContentText()).sha;
  var payload = { message: "MAJ quotidienne cis_gener_bdpm", content: Utilities.base64Encode(csv, Utilities.Charset.UTF_8), branch: CIS_GENER_CONFIG.GITHUB_BRANCH };
  if (sha) payload.sha = sha;
  UrlFetchApp.fetch(apiUrl, { method: "PUT", headers: opts.headers, contentType: "application/json", payload: JSON.stringify(payload) });
  Logger.log("Export GitHub OK: " + (values.length - 1) + " lignes → " + CIS_GENER_CONFIG.GITHUB_PATH_CSV);
}
