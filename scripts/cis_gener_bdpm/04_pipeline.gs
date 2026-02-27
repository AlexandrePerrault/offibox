// @ts-nocheck
/********************************************************
 * Pipeline : fetch + inject → export GitHub → mail si ajouts/suppressions.
 * Déclencheur quotidien possible.
 ********************************************************/

function runCisGenerPipeline() {
  Logger.log("=== Début pipeline CIS_GENER bdpm ===");
  var result = fetchCisGenerToSheet();
  exportCisGenerToGithub();
  var hasChanges = (result.addedCount || 0) + (result.removedCount || 0) > 0;
  if (hasChanges && CIS_GENER_CONFIG.EMAIL_ALERT) {
    var subject = "[Offibox] CIS_GENER bdpm – " + result.addedCount + " ajout(s), " + result.removedCount + " suppression(s)";
    var body = "Comparaison J / J-1.\n\nAjouts : " + result.addedCount + "\nSuppressions : " + result.removedCount + "\n\n";
    if (result.added.length) body += "Clés ajoutées (max 30) : " + result.added.slice(0, 30).join(", ") + (result.added.length > 30 ? "…" : "") + "\n\n";
    if (result.removed.length) body += "Clés supprimées (max 30) : " + result.removed.slice(0, 30).join(", ") + (result.removed.length > 30 ? "…" : "") + "\n\n";
    body += "Fichier " + CIS_GENER_CONFIG.GITHUB_PATH_CSV + " mis à jour sur " + CIS_GENER_CONFIG.GITHUB_OWNER + "/" + CIS_GENER_CONFIG.GITHUB_REPO + ".";
    MailApp.sendEmail({ to: CIS_GENER_CONFIG.EMAIL_ALERT, subject: subject, body: body });
    Logger.log("Mail envoyé à " + CIS_GENER_CONFIG.EMAIL_ALERT);
  }
  Logger.log("=== Pipeline CIS_GENER terminé ===");
}

function installCisGenerDailyTrigger() {
  ScriptApp.newTrigger("runCisGenerPipeline").timeBased().everyDays(1).atHour(6).create();
  Logger.log("Déclencheur quotidien CIS_GENER installé (6h)");
}
