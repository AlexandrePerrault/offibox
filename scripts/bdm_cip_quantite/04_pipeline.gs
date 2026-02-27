// @ts-nocheck
/********************************************************
 * PIPELINE : enchaîne les 2 étapes
 * Déclencheur quotidien possible
 ********************************************************/

/**
 * Exécute le pipeline complet : fetch → export
 */
function runPipeline() {
  Logger.log("=== Début pipeline BDM_CIP_QUANTITE ===");
  fetchBdmToSheet();
  exportSheetToGithub();
  Logger.log("=== Pipeline terminé ===");
}

/**
 * Installe un déclencheur quotidien à 6h
 */
function installDailyTrigger() {
  ScriptApp.newTrigger("runPipeline")
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();
  Logger.log("Déclencheur quotidien installé (6h)");
}
