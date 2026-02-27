// @ts-nocheck
/********************************************************
 * EXPORT AMO-AMC (mutuelles) → GITHUB
 * Fichier final : mutuelles_2026.csv
 * Encodage UTF-8 + normalisation accents (é, è, à, etc.)
 ********************************************************/
function exportSheetToGithub() {
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("Token GitHub manquant");

  const owner = "AlexandrePerrault";
  const repo = "offiboxdata";
  const path = "mutuelles_2026.csv";
  const branch = "main";

  const SPREADSHEET_ID = "1RNtA-2GpSa-ZFARgzUle0_51BHMQEsrcNP9c70FKUvI";
  const SHEET_NAME = "AMO-AMC";

  const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error(`Feuille "${SHEET_NAME}" introuvable`);

  const values = sheet.getDataRange().getValues();

  // 🔧 Normalise les "?" utilisés comme placeholder pour les accents (é, à, etc.)
  // Aligné avec lib/utils/normalize.dart et export_bdm_to_github.gs
  function normalizeAccents(s) {
    if (typeof s !== "string") return s;
    return s
      .replace(/comprim\?/g, "comprimé")
      .replace(/comprim\?s/g, "comprimés")
      .replace(/comprim\?\(s\)/g, "comprimé(s)")
      .replace(/pellicul\?/g, "pelliculé")
      .replace(/pellicul\?s/g, "pelliculés")
      .replace(/pelicul\?/g, "pelliculé")
      .replace(/g\?lule/g, "gélule")
      .replace(/g\?lules/g, "gélules")
      .replace(/g\?lule\(s\)/g, "gélule(s)")
      .replace(/s\?curit\?/g, "sécurité")
      .replace(/s\?cable/g, "sécable")
      .replace(/s\?cables/g, "sécables")
      .replace(/lib\?ration/g, "libération")
      .replace(/prolong\?e/g, "prolongée")
      .replace(/prolong\?s/g, "prolongés")
      .replace(/n\?buliseur/g, "nébuliseur")
      .replace(/n\?buliseurs/g, "nébuliseurs")
      .replace(/ solution \? diluer/g, " solution à diluer")
      .replace(/ \? /g, " à ");
  }

  // ✅ CSV classique : séparateur ; — normalisation accents + UTF-8
  const csv = values
    .map(row =>
      row
        .map(v => {
          const str = String(v ?? "");
          const normalized = normalizeAccents(str);
          return `"${normalized.replace(/"/g, '""')}"`;
        })
        .join(";")
    )
    .join("\n");

  const apiUrl = `https://api.github.com/repos/${owner}/${repo}/contents/${path}`;

  let sha = null;
  const existing = UrlFetchApp.fetch(apiUrl, {
    headers: {
      Authorization: "token " + token,
      Accept: "application/vnd.github.v3+json"
    },
    muteHttpExceptions: true
  });

  if (existing.getResponseCode() === 200) {
    sha = JSON.parse(existing.getContentText()).sha;
  }

  const payload = {
    message: "Mise à jour automatique mutuelles 2026",
    content: Utilities.base64Encode(csv, Utilities.Charset.UTF_8),
    branch
  };
  if (sha) payload.sha = sha;

  UrlFetchApp.fetch(apiUrl, {
    method: "PUT",
    headers: {
      Authorization: "token " + token,
      Accept: "application/vnd.github.v3+json"
    },
    contentType: "application/json",
    payload: JSON.stringify(payload)
  });

  Logger.log("🚀 Export CSV (séparateur ;) vers GitHub terminé");
}
