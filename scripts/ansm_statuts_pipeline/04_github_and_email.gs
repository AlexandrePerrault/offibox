// @ts-nocheck
/***************************************
 * STEP 4 – Filtre col F < 2 mois, push GitHub, email avec ajouts/suppressions et URL
 * Colonne F = index 5 (6e colonne) = date MAJ. On ne pousse vers GitHub que les lignes dont la date est < 2 mois.
 ***************************************/

var COL_DATE_INDEX = 5;  // colonne F = index 5 (6e colonne) = date MAJ
var COL_URL_INDEX = 6;   // colonne G = URL (ajuster si le TXT a une autre structure)

function getGithubToken_() {
  return PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN") || (typeof GITHUB_TOKEN !== "undefined" ? GITHUB_TOKEN : "");
}

/**
 * Retourne true si la date (chaîne) est dans les 2 derniers mois (par rapport à aujourd'hui).
 * Accepte YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY.
 * @param {string} dateStr
 * @return {boolean}
 */
function isDateWithinTwoMonths_(dateStr) {
  if (!dateStr || dateStr.trim().length === 0) return false;
  var s = dateStr.trim();
  var parts = s.split(/[-\/]/);
  var d = null;
  if (parts.length >= 3) {
    var y = parseInt(parts[0], 10);
    var m = parseInt(parts[1], 10);
    var day = parseInt(parts[2], 10);
    if (y < 100) y += 2000;
    if (m >= 1 && m <= 12 && day >= 1 && day <= 31) {
      d = new Date(y, m - 1, day);
    }
    if (!d && parts[0].length === 4) {
      d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    } else if (!d && parts[2].length === 4) {
      d = new Date(parseInt(parts[2], 10), parseInt(parts[1], 10) - 1, parseInt(parts[0], 10));
    }
  }
  if (!d || isNaN(d.getTime())) return false;
  var twoMonthsAgo = new Date();
  twoMonthsAgo.setMonth(twoMonthsAgo.getMonth() - 2);
  return d >= twoMonthsAgo;
}

/**
 * Filtre les lignes : ne garde que celles dont la colonne F (index 5) est une date < 2 mois.
 * @param {string[][]} rows - première ligne = en-têtes
 * @return {string[][]}
 */
function filterRowsWithinTwoMonths_(rows) {
  if (!rows || rows.length <= 1) return rows || [];
  var out = [rows[0]];
  for (var i = 1; i < rows.length; i++) {
    var row = rows[i];
    var dateCell = row.length > COL_DATE_INDEX ? row[COL_DATE_INDEX] : "";
    if (isDateWithinTwoMonths_(dateCell)) out.push(row);
  }
  return out;
}

/**
 * Clé unique pour une ligne (CIS + CIP ou premières colonnes) pour comparer ajouts/suppressions.
 * @param {string[]} row
 * @return {string}
 */
function rowKey_(row) {
  var a = row.length > 0 ? row[0] : "";
  var b = row.length > 1 ? row[1] : "";
  return (a + "|" + b).trim();
}

/**
 * Convertit des lignes en CSV (virgules, champs entre guillemets si nécessaire).
 * @param {string[][]} rows
 * @return {string}
 */
function rowsToCsv_(rows) {
  if (!rows || rows.length === 0) return "";
  function escape_(v) {
    var s = String(v == null ? "" : v);
    if (s.indexOf(",") !== -1 || s.indexOf('"') !== -1 || s.indexOf("\n") !== -1) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  }
  var lines = [];
  for (var i = 0; i < rows.length; i++) {
    lines.push(rows[i].map(escape_).join(","));
  }
  return lines.join("\n");
}

/**
 * Récupère le CSV actuel sur GitHub.
 * @return {string|null}
 */
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

/**
 * Parse un CSV simple en tableau de lignes (colonnes).
 * @param {string} csvText
 * @return {string[][]}
 */
function parseCsvToRows_(csvText) {
  if (!csvText || !csvText.length) return [];
  var lines = csvText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  var out = [];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.trim().length === 0) continue;
    var row = [];
    var inQuotes = false;
    var cell = "";
    for (var j = 0; j < line.length; j++) {
      var ch = line[j];
      if (ch === '"') {
        inQuotes = !inQuotes;
      } else if (ch === "," && !inQuotes) {
        row.push(cell.trim());
        cell = "";
      } else {
        cell += ch;
      }
    }
    row.push(cell.trim());
    out.push(row);
  }
  return out;
}

/**
 * Compare les lignes filtrées (col F < 2 mois) avec le CSV GitHub. Retourne added/removed avec infos (clé + URL si dispo).
 * @param {string[][]} newFilteredRows - en-tête + données
 * @return {{ added: Array<{key:string, url:string}>, removed: Array<{key:string, url:string}>, hasChanges: boolean }}
 */
function getAnsmStatutsChanges_(newFilteredRows) {
  var currentCsv = fetchCurrentCsvFromGithub_();
  var oldRows = currentCsv ? parseCsvToRows_(currentCsv) : [];
  var oldKeys = {};
  var oldUrlByKey = {};
  for (var i = 1; i < oldRows.length; i++) {
    var k = rowKey_(oldRows[i]);
    oldKeys[k] = true;
    var url = oldRows[i].length > COL_URL_INDEX ? oldRows[i][COL_URL_INDEX] : "";
    oldUrlByKey[k] = url || "";
  }
  var newKeys = {};
  var newUrlByKey = {};
  for (var j = 1; j < newFilteredRows.length; j++) {
    var k = rowKey_(newFilteredRows[j]);
    newKeys[k] = true;
    var url = newFilteredRows[j].length > COL_URL_INDEX ? newFilteredRows[j][COL_URL_INDEX] : "";
    newUrlByKey[k] = url || "";
  }
  var added = [];
  var removed = [];
  for (var ki in newKeys) {
    if (!oldKeys[ki]) added.push({ key: ki, url: newUrlByKey[ki] || "" });
  }
  for (var ko in oldKeys) {
    if (!newKeys[ko]) removed.push({ key: ko, url: oldUrlByKey[ko] || "" });
  }
  return {
    added: added,
    removed: removed,
    hasChanges: added.length > 0 || removed.length > 0
  };
}

/**
 * Envoie l'email quotidien avec ajouts, suppressions et URL correspondantes.
 * @param {{ added: Array<{key:string, url:string}>, removed: Array<{key:string, url:string}> }} changes
 */
function sendAnsmStatutsNotification_(changes) {
  var to = typeof NOTIFICATION_EMAIL !== "undefined" ? NOTIFICATION_EMAIL : "perraultalexandre78@gmail.com";
  var subject = "Statuts ANSM – Mise à jour GitHub (changements détectés)";
  var body = "Le pipeline statuts ANSM a détecté des changements et a mis à jour le dépôt GitHub (lignes avec date col F < 2 mois).\n\n";
  body += "--- AJOUTS (" + (changes.added.length || 0) + ") ---\n";
  for (var i = 0; i < Math.min(changes.added.length, 50); i++) {
    body += changes.added[i].key;
    if (changes.added[i].url) body += " | " + changes.added[i].url;
    body += "\n";
  }
  if (changes.added.length > 50) body += "... et " + (changes.added.length - 50) + " autres\n";
  body += "\n--- SUPPRESSIONS (" + (changes.removed.length || 0) + ") ---\n";
  for (var j = 0; j < Math.min(changes.removed.length, 50); j++) {
    body += changes.removed[j].key;
    if (changes.removed[j].url) body += " | " + changes.removed[j].url;
    body += "\n";
  }
  if (changes.removed.length > 50) body += "... et " + (changes.removed.length - 50) + " autres\n";
  body += "\nFichier : " + GITHUB_FILE + " sur " + GITHUB_OWNER + "/" + GITHUB_REPO;
  MailApp.sendEmail(to, subject, body);
  Logger.log("Email envoyé à " + to + " (ajouts: " + changes.added.length + ", suppressions: " + changes.removed.length + ")");
}

/**
 * Push le CSV (lignes filtrées col F < 2 mois) vers GitHub.
 * @param {string[][]} filteredRows - en-tête + données
 */
function step4_pushToGithub_(filteredRows) {
  var token = getGithubToken_();
  if (!token) throw new Error("GITHUB_TOKEN manquant (Propriétés du script ou 01_config.gs)");
  var csv = rowsToCsv_(filteredRows);
  var encoded = Utilities.base64Encode("\uFEFF" + csv, Utilities.Charset.UTF_8);
  var url = "https://api.github.com/repos/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/contents/" + encodeURIComponent(GITHUB_FILE);
  var headers = { "Authorization": "token " + token, "Accept": "application/vnd.github.v3+json" };
  var sha = null;
  var get = UrlFetchApp.fetch(url, { method: "get", headers: headers, muteHttpExceptions: true });
  if (get.getResponseCode() === 200) {
    sha = JSON.parse(get.getContentText()).sha;
  }
  var payload = { message: "Daily statuts ANSM update (col F < 2 mois)", content: encoded, branch: GITHUB_BRANCH };
  if (sha) payload.sha = sha;
  UrlFetchApp.fetch(url, { method: "put", contentType: "application/json", headers: headers, payload: JSON.stringify(payload) });
  Logger.log("GitHub mis à jour : " + filteredRows.length + " lignes → " + GITHUB_FILE);
}
