// @ts-nocheck
/**
 * Config fiches VOC (Voie Orale contre le Cancer) – OMÉDIT.
 * Source : https://www.omedit-fiches-cancer.fr/fiches-voie-orale-contre-le-cancer-voc/
 */

var OMEDIT_VOC_CONFIG = {
  owner: 'AlexandrePerrault',
  repo: 'offiboxdata',
  branch: 'main',
  /** URL de la page des fiches VOC (tableau médicament / fiche pro / fiche patient). */
  sourceUrl: 'https://www.omedit-fiches-cancer.fr/fiches-voie-orale-contre-le-cancer-voc/fiches-voie-orale-contre-le-cancer-voc,6093,13536.html',
  /** Base pour construire les URLs absolues des PDF. */
  baseUrl: 'https://www.omedit-fiches-cancer.fr',
  /** Nom de la feuille dans le Google Sheet (à créer ou utiliser). */
  sheetName: 'VOC',
  /** ID du Google Sheet (à remplacer par le vôtre). */
  spreadsheetId: ''
};
