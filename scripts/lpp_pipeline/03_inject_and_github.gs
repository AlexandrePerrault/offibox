// @ts-nocheck
/** STEP 3 – Injection Google Sheets : col A = Code LPP, col B = Libellé, col C = URL (reconstruite si vide) */

function getLppFicheUrl_(code) {
  if (!code) return "";
  var tpl = (typeof URL_TEMPLATE !== "undefined" ? URL_TEMPLATE : "http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI");
  return tpl.replace("{CODE}", String(code));
}

function step3_injectToSheet_(data) {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);

  var headers = ["Code LPP", "Libellé", "URL"];
  var rows = data.map(function (r) {
    var url = (r.url && String(r.url).trim() !== "") ? String(r.url).trim() : getLppFicheUrl_(r.code);
    return [r.code || "", r.libelle != null ? String(r.libelle) : "", url];
  });

  var allRows = [headers].concat(rows);
  var numRows = allRows.length;
  var numCols = 3;
  sheet.clear();
  if (numRows > 0) {
    sheet.getRange(1, 1, numRows, numCols).setValues(allRows);
    sheet.getRange(1, 1, 1, numCols).setFontWeight("bold");
  }
  SpreadsheetApp.flush();
  Logger.log("Sheet mis à jour : " + rows.length + " lignes (3 colonnes : Code LPP, Libellé, URL)");
}
