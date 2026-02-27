// @ts-nocheck
/***************************************
 * PIPELINE STATUTS ANSM – TXT → Sheet (tout) → GitHub (lignes col F < 2 mois)
 * Trigger quotidien : installDailyTrigger(). Email uniquement si changements (ajouts/suppressions + URL).
 ***************************************/

function runDailyAnsmStatuts() {
  Logger.log("STEP 1 - Téléchargement TXT");
  var rawText = step2_fetchTxt_();

  Logger.log("STEP 2 - Parsing");
  var rows = step2_parseTxt_(rawText);
  Logger.log("Nombre de lignes parsées : " + (rows ? rows.length : 0));

  Logger.log("STEP 3 - Injection feuille " + SHEET_NAME + " (toutes les lignes)");
  step3_injectToSheet_(rows);

  var filtered = filterRowsWithinTwoMonths_(rows);
  Logger.log("Lignes avec col F < 2 mois : " + (filtered ? filtered.length - 1 : 0) + " (hors en-tête)");

  var changes = getAnsmStatutsChanges_(filtered);
  if (changes.hasChanges) {
    Logger.log("STEP 4 - Push vers GitHub (changements détectés)");
    step4_pushToGithub_(filtered);
    sendAnsmStatutsNotification_(changes);
    Logger.log("Pipeline statuts ANSM terminé : GitHub mis à jour, email envoyé.");
  } else {
    Logger.log("Aucun changement (ajout/suppression). Pas de push GitHub ni d'email.");
    Logger.log("Pipeline statuts ANSM terminé.");
  }
}

/**
 * Installe un déclencheur quotidien (tous les jours à 6h).
 */
function installDailyTrigger() {
  ScriptApp.newTrigger("runDailyAnsmStatuts")
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();
  Logger.log("Déclencheur quotidien statuts ANSM installé (tous les jours 6h)");
}
