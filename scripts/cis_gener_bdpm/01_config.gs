// @ts-nocheck
/********************************************************
 * CONFIG – Pipeline CIS_GENER bdpm
 * Import génériques 2026.csv (semicolon) → Sheet (générique, princeps A, princeps B, CIS)
 * Export quotidien GitHub + mail si ajouts/suppressions
 * Optionnel : mise à jour "ligne 2" du BDM master pour produits contenant le princeps.
 * Propriétés du script : GITHUB_TOKEN, EMAIL_ALERT (optionnel)
 ********************************************************/

const CIS_GENER_CONFIG = {
  SHEET_ID: "1CX5jo6nz5x6JivPB9WZRriLJ9czZsS38wSmeh0nsdUc",
  SHEET_NAME: "CIS_GENER_BDPM",
  CIS_GENER_URL: "https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/g%C3%A9n%C3%A9riques%202026.csv",
  GITHUB_OWNER: "AlexandrePerrault",
  GITHUB_REPO: "offiboxdata",
  GITHUB_PATH_CSV: "cis_gener_bdpm.csv",
  GITHUB_BRANCH: "main",
  SHEET_NAME_PREV_KEYS: "CIS_GENER_KEYS_J1",
  EMAIL_ALERT: "perraultalexandre78@gmail.com",
  // BDM master : si défini, met à jour la "ligne 2" pour les produits dont la dénomination contient le princeps (col B)
  BDM_MASTER_SHEET_ID: "1zRpCyJ9yrbqm40tJ-M8jgJfs-jaRoIJhgxKf1R5XRA8",
  BDM_MASTER_SHEET_NAME: "BDM_ACTIVE",
  BDM_LINE2_COL: 11          // colonne 1-based pour "ligne 2" (ex: 11 = K)
};
