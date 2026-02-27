// @ts-nocheck
// Exporte CSV + ansm_new_groups.json vers GitHub

function exportAnsmToGithub(newGroups) {
  var token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("GITHUB_TOKEN manquant (Propriétés du script)");
  var ss = SpreadsheetApp.openById(ANSM_CONFIG.SHEET_ID);
  var sheet = ss.getSheetByName(ANSM_CONFIG.SHEET_NAME);
  if (!sheet) throw new Error("Exécuter d'abord fetchAnsmToSheet()");
  var values = sheet.getDataRange().getValues();
  if (values.length < 2) throw new Error("Sheet vide. Exécuter fetchAnsmToSheet().");
  var csv = values.map(function (row) {
    return row.map(function (v) { return '"' + String(v || "").replace(/"/g, '""') + '"'; }).join(";");
  }).join("\n");
  var opts = { headers: { Authorization: "token " + token, Accept: "application/vnd.github.v3+json" }, muteHttpExceptions: true };
  function putFile(path, content, message) {
    var apiUrl = "https://api.github.com/repos/" + ANSM_CONFIG.GITHUB_OWNER + "/" + ANSM_CONFIG.GITHUB_REPO + "/contents/" + path;
    var get = UrlFetchApp.fetch(apiUrl, opts);
    var sha = null;
    if (get.getResponseCode() === 200) sha = JSON.parse(get.getContentText()).sha;
    var payload = { message: message, content: Utilities.base64Encode(content, Utilities.Charset.UTF_8), branch: ANSM_CONFIG.GITHUB_BRANCH };
    if (sha) payload.sha = sha;
    UrlFetchApp.fetch(apiUrl, { method: "PUT", headers: opts.headers, contentType: "application/json", payload: JSON.stringify(payload) });
  }
  putFile(ANSM_CONFIG.GITHUB_PATH_CSV, csv, "MAJ quotidienne generiques_ansm (ANSM)");
  var jsonPayload = JSON.stringify({ date: new Date().toISOString().slice(0, 10), newGroups: newGroups || [], count: (newGroups || []).length });
  putFile(ANSM_CONFIG.GITHUB_PATH_JSON, jsonPayload, "ANSM nouveaux groupes " + (newGroups || []).length);
  Logger.log("Export GitHub OK. Nouveaux groupes: " + (newGroups ? newGroups.length : 0));
}
