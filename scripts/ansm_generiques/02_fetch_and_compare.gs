// @ts-nocheck
// Télécharge fic01/fic02/fic03, parse, construit CSV, compare J/J-1 (nouveaux groupes)

function fetchAnsmToSheet() {
  var sheetId = ANSM_CONFIG.SHEET_ID;
  if (!sheetId) throw new Error("ANSM_CONFIG.SHEET_ID manquant");
  var ss = SpreadsheetApp.openById(sheetId);
  var sheet = ss.getSheetByName(ANSM_CONFIG.SHEET_NAME);
  if (!sheet) sheet = ss.insertSheet(ANSM_CONFIG.SHEET_NAME);

  var fic01Text = fetchAnsmFile(ANSM_CONFIG.FIC01_URL);
  var dciById = parseFic01Den(fic01Text);
  var fic02Text = fetchAnsmFile(ANSM_CONFIG.FIC02_URL);
  var grpRows = parseFic02Grp(fic02Text);
  var codeGrpSetToday = {};
  var denByGrp = {};
  for (var i = 0; i < grpRows.length; i++) {
    var r = grpRows[i];
    codeGrpSetToday[r.code_grp] = true;
    if (!denByGrp[r.code_grp]) denByGrp[r.code_grp] = r.code_den;
  }
  var fic03Text = fetchAnsmFile(ANSM_CONFIG.FIC03_URL);
  var speRows = parseFic03Spe(fic03Text);

  var newGroups = [];
  var props = PropertiesService.getScriptProperties();
  var prevJson = props.getProperty(ANSM_CONFIG.PROP_PREV_GROUPS);
  if (prevJson) {
    try {
      var prev = JSON.parse(prevJson);
      for (var cg in codeGrpSetToday) if (!prev[cg]) newGroups.push(cg);
    } catch (e) {}
  }
  props.setProperty(ANSM_CONFIG.PROP_PREV_GROUPS, JSON.stringify(codeGrpSetToday));

  var csvRows = buildCsvRows(dciById, denByGrp, speRows);
  var data = [["DCI", "princeps_nom", "princeps_cip", "cip13"]];
  for (var j = 0; j < csvRows.length; j++) {
    var r = csvRows[j];
    data.push([r.dci, r.princeps_nom, r.princeps_cip, r.cip13]);
  }
  sheet.clear();
  if (data.length > 0) {
    sheet.getRange(1, 1, data.length, 4).setValues(data);
    sheet.getRange(1, 1, 1, 4).setFontWeight("bold");
  }
  return { newGroups: newGroups, newGroupsCount: newGroups.length };
}

function fetchAnsmFile(url) {
  var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (resp.getResponseCode() !== 200) throw new Error("Erreur: " + url);
  var blob = resp.getBlob();
  try { return blob.getDataAsString("UTF-8"); } catch (e) { return blob.getDataAsString("ISO-8859-1"); }
}

function parseFic01Den(text) {
  var map = {};
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].trim().match(/^(\d+)\s+(.+)$/);
    if (m) map[m[1]] = m[2].trim();
  }
  return map;
}

function parseFic02Grp(text) {
  var rows = [];
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var p = lines[i].trim().split(/\s+/);
    if (p.length >= 2) rows.push({ code_den: p[0], code_grp: p[1] });
  }
  return rows;
}

function parseFic03Spe(text) {
  var rows = [];
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var p = lines[i].trim().split(/\s+/, 4);
    if (p.length >= 4 && /^[GRS]$/i.test(p[2]))
      rows.push({ code_spe: p[0], cip8: p[1].replace(/\D/g, ""), type: p[2].toUpperCase(), label: p[3] || "" });
  }
  return rows;
}

function cip8ToCip13(cip8) {
  return (String(cip8).length === 8) ? "34009" + cip8 : null;
}

function buildCsvRows(dciById, denByGrp, speRows) {
  var byCode = {};
  for (var i = 0; i < speRows.length; i++) {
    var r = speRows[i], cip13 = cip8ToCip13(r.cip8);
    if (!cip13) continue;
    var c = r.code_spe;
    if (!byCode[c]) byCode[c] = { refs: [], gens: [] };
    if (r.type === "R") byCode[c].refs.push({ cip13: cip13, label: r.label });
    else if (r.type === "G") byCode[c].gens.push({ cip13: cip13, label: r.label });
  }
  var out = [];
  for (var codeSpe in byCode) {
    var grp = byCode[codeSpe], dci = denByGrp[codeSpe] && dciById[denByGrp[codeSpe]] ? dciById[denByGrp[codeSpe]] : "";
    var pCip = grp.refs[0] ? grp.refs[0].cip13 : "", pNom = grp.refs[0] ? grp.refs[0].label : "";
    for (var g = 0; g < grp.gens.length; g++)
      out.push({ dci: dci, princeps_nom: pNom, princeps_cip: pCip, cip13: grp.gens[g].cip13 });
    for (var r = 0; r < grp.refs.length; r++)
      out.push({ dci: dci, princeps_nom: grp.refs[r].label, princeps_cip: grp.refs[r].cip13, cip13: grp.refs[r].cip13 });
  }
  return out;
}
