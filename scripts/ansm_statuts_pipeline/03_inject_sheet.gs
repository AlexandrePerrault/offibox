// @ts-nocheck
/***************************************
 * STEP 3 – Injection dans la feuille Google "statuts ANSM"
 * Toutes les lignes du TXT sont écrites (sans filtre date).
 ***************************************/

/**
 * @param {string[][]} rows - Première ligne = en-têtes, suivantes = données
 */
function step3_injectToSheet_(rows) {
  if (!rows || rows.length === 0) {
    Logger.log("Aucune donnée à injecter");
    return;
  }
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  sheet.clear();
  var numCols = 0;
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].length > numCols) numCols = rows[i].length;
  }
  if (numCols === 0) return;
  for (var c = 0; c < rows.length; c++) {
    var row = rows[c];
    while (row.length < numCols) row.push("");
    sheet.getRange(c + 1, 1, 1, numCols).setValues([row]);
    if (c === 0) sheet.getRange(1, 1, 1, numCols).setFontWeight("bold");
  }
  Logger.log("Sheet mis à jour : " + rows.length + " lignes, " + numCols + " colonnes");
}
