// Exporte la feuille "medicaments d'exception" vers GitHub (CSV).
// Nécessite une fonction pushSheetToGitHub(sheetId, sheetName, githubFileName) définie ailleurs.

function exportKeywords() {
  pushSheetToGitHub(
    '1YEYi3n9L0nvgP9_Eo8Yla5sfxEwcf5gfgc5q2DxA4iE',  // ID
    "medicaments d'exception",                         // nom exact de la feuille
    "medicaments d'exception.csv"                      // fichier GitHub
  );
}
