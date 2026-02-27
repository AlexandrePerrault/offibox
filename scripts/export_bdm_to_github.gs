// @ts-nocheck
/********************************************************
 * EXPORT BDM_ACTIVE → GITHUB
 * Fichier final : BDM_MASTER2026.csv
 * Encodage UTF-8 pour préserver les accents (é, è, à, etc.)
 ********************************************************/
function exportBDMActiveToGithub() {

  // 🔑 TOKEN GITHUB (Script Properties)
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("Token GitHub manquant");

  // 📦 DÉPÔT GITHUB
  const owner  = "AlexandrePerrault";
  const repo   = "offiboxdata";
  const path   = "BDM_MASTER2026.csv";
  const branch = "main";

  // 📄 GOOGLE SHEETS
  const SPREADSHEET_ID = "1zRpCyJ9yrbqm40tJ-M8jgJfs-jaRoIJhgxKf1R5XRA8";
  const SHEET_NAME = "BDM_ACTIVE";

  const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error(`Feuille "${SHEET_NAME}" introuvable`);

  // 📥 LECTURE DES DONNÉES (accents préservés par getValues())
  const values = sheet.getDataRange().getValues();

  // 🔧 Normalise les "?" utilisés comme placeholder pour les accents (é, à, etc.)
  // Aligné avec lib/utils/normalize.dart et lib/data/bdm_parser.dart
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

  // 🧾 CONVERSION CSV (séparateur ;) — normalisation accents + préservation UTF-8
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

  // 🌐 API GITHUB
  const apiUrl = `https://api.github.com/repos/${owner}/${repo}/contents/${path}`;

  // 🔍 RÉCUP SHA SI FICHIER EXISTANT
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

  // 📤 PAYLOAD — encodage UTF-8 explicite pour les accents (é, è, à, ç, etc.)
  const payload = {
    message: "Mise à jour automatique BDM_MASTER2026",
    content: Utilities.base64Encode(csv, Utilities.Charset.UTF_8),
    branch: branch
  };
  if (sha) payload.sha = sha;

  // 🚀 ENVOI GITHUB
  UrlFetchApp.fetch(apiUrl, {
    method: "PUT",
    headers: {
      Authorization: "token " + token,
      Accept: "application/vnd.github.v3+json"
    },
    contentType: "application/json",
    payload: JSON.stringify(payload)
  });

  Logger.log("🚀 Export BDM_ACTIVE → GitHub (BDM_MASTER2026.csv) terminé");
}
