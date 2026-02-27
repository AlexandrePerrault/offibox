// @ts-nocheck
/********************************************************
 * CONFIG – Pipeline ANSM génériques (fic01 + fic02 + fic03)
 * MAJ quotidienne, export GitHub, comparaison J/J-1, mail si nouveau groupe
 * Propriétés du script : GITHUB_TOKEN
 * EMAIL_ALERT : destinataire des alertes nouveau groupe
 ********************************************************/

const ANSM_CONFIG = {
  SHEET_ID: "1CX5jo6nz5x6JivPB9WZRriLJ9czZsS38wSmeh0nsdUc",
  SHEET_NAME: "ANSM_GENERIQUES",
  SHEET_PREV_GROUPS: "ANSM_GROUPS_PREV",
  FIC01_URL: "https://ansm.sante.fr/uploads/2026/01/20/fic01den.txt",
  FIC02_URL: "https://ansm.sante.fr/uploads/2026/01/20/fic02grp.txt",
  FIC03_URL: "https://ansm.sante.fr/uploads/2026/01/20/fic03spe.txt",
  GITHUB_OWNER: "AlexandrePerrault",
  GITHUB_REPO: "offiboxdata",
  GITHUB_PATH_CSV: "generiques_ansm.csv",
  GITHUB_PATH_JSON: "ansm_new_groups.json",
  GITHUB_BRANCH: "main",
  PROP_PREV_GROUPS: "ANSM_GROUPS_J1",
  EMAIL_ALERT: "perraultalexandre78@gmail.com"
};
