// @ts-nocheck
/********************************************************
 * ÉTAPE 2 : Lit le Sheet, génère CSV UTF-8, pousse vers GitHub
 * Colonnes : CIP13;nom;dosage;quantite;libelle
 * Exécution : ~10-30 s
 ********************************************************/

function exportSheetToGithub() {
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("GITHUB_TOKEN manquant (Propriétés du script)");

  const sheetId = BDM_CIP_CONFIG.SHEET_ID;
  if (!sheetId) throw new Error("BDM_CIP_CONFIG.SHEET_ID manquant dans 01_config.gs");

  const ss = SpreadsheetApp.openById(sheetId);
  const sheet = ss.getSheetByName(BDM_CIP_CONFIG.SHEET_NAME);
  if (!sheet) throw new Error("Feuille " + BDM_CIP_CONFIG.SHEET_NAME + " introuvable. Exécuter d'abord fetchBdmToSheet().");

  const values = sheet.getDataRange().getValues();
  if (values.length < 2) throw new Error("Sheet vide ou sans données. Exécuter d'abord fetchBdmToSheet().");

  const csv = buildCsvFromValues(values);

  const apiUrl = `https://api.github.com/repos/${BDM_CIP_CONFIG.GITHUB_OWNER}/${BDM_CIP_CONFIG.GITHUB_REPO}/contents/${BDM_CIP_CONFIG.GITHUB_PATH}`;
  let sha = null;
  const existing = UrlFetchApp.fetch(apiUrl, {
    headers: { Authorization: "token " + token, Accept: "application/vnd.github.v3+json" },
    muteHttpExceptions: true
  });
  if (existing.getResponseCode() === 200) {
    sha = JSON.parse(existing.getContentText()).sha;
  }

  const payload = {
    message: "Mise à jour automatique BDM_CIP_QUANTITE (quotidienne)",
    content: Utilities.base64Encode(csv, Utilities.Charset.UTF_8),
    branch: BDM_CIP_CONFIG.GITHUB_BRANCH
  };
  if (sha) payload.sha = sha;

  UrlFetchApp.fetch(apiUrl, {
    method: "PUT",
    headers: { Authorization: "token " + token, Accept: "application/vnd.github.v3+json" },
    contentType: "application/json",
    payload: JSON.stringify(payload)
  });

  Logger.log("Étape 2 terminée : " + (values.length - 1) + " lignes exportées vers GitHub");
}

function buildCsvFromValues(values) {
  const escape = v => `"${String(v ?? "").replace(/"/g, '""')}"`;
  return values.map(row => row.map(escape).join(";")).join("\n");
}
