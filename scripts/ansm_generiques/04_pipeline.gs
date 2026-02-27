// @ts-nocheck
// Pipeline : fetch → export → mail si nouveaux groupes. Déclencheur quotidien.

function runAnsmPipeline() {
  Logger.log("=== Début pipeline ANSM génériques ===");
  var result = fetchAnsmToSheet();
  exportAnsmToGithub(result.newGroups);
  if (result.newGroupsCount > 0 && ANSM_CONFIG.EMAIL_ALERT) {
    MailApp.sendEmail({
      to: ANSM_CONFIG.EMAIL_ALERT,
      subject: "[Offibox] " + result.newGroupsCount + " nouveau(x) groupe(s) génériques ANSM",
      body: "Comparaison J / J-1 : " + result.newGroupsCount + " nouveau(x) groupe(s) détecté(s).\n\nCodes groupe : " + result.newGroups.join(", ") + "\n\nFichier ansm_new_groups.json mis à jour sur GitHub (offiboxdata)."
    });
    Logger.log("Mail envoyé à " + ANSM_CONFIG.EMAIL_ALERT);
  }
  Logger.log("=== Pipeline ANSM terminé ===");
}

function installAnsmDailyTrigger() {
  ScriptApp.newTrigger("runAnsmPipeline").timeBased().everyDays(1).atHour(6).create();
  Logger.log("Déclencheur quotidien ANSM installé (6h)");
}
