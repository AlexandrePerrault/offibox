// @ts-nocheck
/** PIPELINE LPP – Fetch ZIP LPPTOT867 → parse code + libellé → Sheet (Code LPP, URL, Libellé) + optionnel GitHub */

/**
 * Lit la colonne A de la feuille source (nomenclature LPP). Conservé pour compatibilité manuelle.
 * @return {string[]} Valeurs de la colonne A
 */
function step1_readSourceColumnA_() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SOURCE_SHEET_NAME);
  if (!sheet) throw new Error("Feuille source introuvable : " + SOURCE_SHEET_NAME);
  var range = sheet.getRange("A:A");
  var values = range.getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    var v = values[i][0];
    if (v != null && String(v).trim() !== "") out.push(String(v));
  }
  return out;
}

/**
 * Exécute le pipeline LPP : fetch ZIP → parse code + libellé → injection Sheet → GitHub si changements
 */
function runDailyLPP() {
  var data = step1_fetchAndParseFromZip_();
  Logger.log("Entrées extraites du ZIP : " + data.length);

  if (data.length === 0) {
    Logger.log("Aucune donnée extraite, arrêt du pipeline.");
    return;
  }

  step3_injectToSheet_(data);

  var changes = getLppChanges_(data);
  if (changes.hasChanges) {
    step4_pushToGithub_(data);
    sendLppChangeNotification_(changes.added, changes.removed);
  }
}

/** Pour compatibilité : appelle runDailyLPP. */
function runWeeklyLPP() {
  runDailyLPP();
}

/**
 * Installe un déclencheur quotidien (tous les jours à 6h).
 * À exécuter une fois dans l'éditeur Apps Script.
 */
function installDailyTrigger() {
  ScriptApp.newTrigger("runDailyLPP")
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();
  Logger.log("Déclencheur quotidien LPP installé (tous les jours 6h)");
}

/**
 * Installe un déclencheur hebdomadaire (dimanche 6h). Pour compatibilité.
 */
function installWeeklyTrigger() {
  ScriptApp.newTrigger("runDailyLPP")
    .timeBased()
    .onWeekDay(ScriptApp.WeekDay.SUNDAY)
    .atHour(6)
    .create();
  Logger.log("Déclencheur hebdomadaire LPP installé (dimanche 6h)");
}
