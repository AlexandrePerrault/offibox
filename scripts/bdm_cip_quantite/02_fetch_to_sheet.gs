// @ts-nocheck
/********************************************************
 * ÉTAPE 1 : Télécharge CIS + CIS_CIP, parse, écrit dans Google Sheet
 * Colonnes : CIP13, nom, dosage, quantite, libelle
 * Exécution : ~2-4 min selon la taille des fichiers
 ********************************************************/

function fetchBdmToSheet() {
  const sheetId = BDM_CIP_CONFIG.SHEET_ID;
  if (!sheetId) throw new Error("BDM_CIP_CONFIG.SHEET_ID manquant dans 01_config.gs");

  const ss = SpreadsheetApp.openById(sheetId);
  let sheet = ss.getSheetByName(BDM_CIP_CONFIG.SHEET_NAME);
  if (!sheet) sheet = ss.insertSheet(BDM_CIP_CONFIG.SHEET_NAME);

  Logger.log("Téléchargement CIS_bdpm.txt...");
  const cisText = fetchBdmFile(BDM_CIP_CONFIG.CIS_URL);
  const cisMap = parseCisBdpm(cisText);
  Logger.log("CIS chargé: " + Object.keys(cisMap).length + " spécialités");

  Logger.log("Téléchargement CIS_CIP_bdpm.txt...");
  const cipText = fetchBdmFile(BDM_CIP_CONFIG.CIP_URL);
  const rows = parseCisCipBdpm(cipText, cisMap);
  Logger.log("CIP chargé: " + rows.length + " présentations");

  const data = [
    ["CIP13", "nom", "dosage", "quantite", "libelle"],
    ...rows.map(r => [r.cip13, r.nom, r.dosage, r.quantite, r.libelle])
  ];

  sheet.clear();
  sheet.getRange(1, 1, data.length, 5).setValues(data);
  sheet.getRange(1, 1, 1, 5).setFontWeight("bold");

  Logger.log("Étape 1 terminée : " + rows.length + " lignes écrites dans le Sheet");
}

function fetchBdmFile(url) {
  const resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (resp.getResponseCode() !== 200) throw new Error("Erreur téléchargement: " + url);
  const blob = resp.getBlob();
  const textUtf8 = blob.getDataAsString("UTF-8");
  if (/[\uFFFD]/.test(textUtf8)) {
    return blob.getDataAsString("ISO-8859-1");
  }
  return textUtf8;
}

function parseCisBdpm(text) {
  const map = {};
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;
    const cols = line.split("\t");
    if (cols.length >= 2) {
      const cis = String(cols[0]).trim();
      const denomination = String(cols[1] || "").trim();
      if (cis && denomination) map[cis] = denomination;
    }
  }
  return map;
}

function extractDosage(denomination) {
  if (!denomination || typeof denomination !== "string") return "";
  const m = denomination.match(/(\d+(?:[.,]\d+)?)\s*(mg|g|µg|mcg|%|UI|U\.?I\.?|ml|L|ME|mmol)/gi);
  return m ? m[0].trim() : "";
}

function extractQuantiteAndUnit(libelle) {
  const raw = libelle || "";
  const norm = normalizeAccents(raw);
  const patterns = [
    /(?:^|boîte de |de |en |flacon de )(\d+)\s*(comprimés?|gélules?|gelules?|sachets?|suppositoires?|pastilles?|flacons?|ampoules?|tubes?|applicateurs?|pochettes?|unitaires?|doses?)\b/i,
    /(\d+)\s*(comprimés?|gélules?|gelules?|sachets?|suppositoires?|pastilles?)\s*(?:sous|en|en boîte|en blister|,|$)/i,
    /(\d+)\s*(comprimés?|gélules?|gelules?|sachets?)\b/i,
    /(\d+)\s*g[eéèë]?lules?/i,
    /(\d+)\s*comprim[eéèë]s?/i,
    /boîte\s+(?:de\s+)?(\d+)/i,
    /(\d+)\s+en\s+boîte/i,
    /^(\d+)\s+(?:comprimé|gélule|gelule|sachet|flacon|ampoule)/i,
    /^(\d+)\s+/,
    /(\d+)\s*(?:ml|g)\s+(?:en\s+)?(?:flacon|boîte)/i
  ];
  for (const re of patterns) {
    const m = norm.match(re);
    if (m) {
      let unit = (m[2] || "").toLowerCase();
      if (!unit) {
        const frag = (m[0] || "").toLowerCase();
        if (/g[eéèë]?lule/i.test(frag)) unit = "gélule";
        else if (/comprim[eéèë]/i.test(frag)) unit = "comprimé";
        else if (/sachet/i.test(frag)) unit = "sachet";
        else if (/flacon/i.test(frag)) unit = "flacon";
        else if (/ampoule/i.test(frag)) unit = "ampoule";
      }
      return { quantite: m[1], unit: unit };
    }
  }
  return { quantite: "", unit: "" };
}

function normalizeAccents(s) {
  if (typeof s !== "string") return s;
  return s
    .replace(/\uFFFD/g, "")
    .replace(/Ã©/g, "é").replace(/Ã¨/g, "è").replace(/Ãª/g, "ê").replace(/Ã«/g, "ë")
    .replace(/Ã /g, "à").replace(/Ã¢/g, "â").replace(/Ã®/g, "î").replace(/Ã¯/g, "ï")
    .replace(/Ã´/g, "ô").replace(/Ã¹/g, "ù").replace(/Ã»/g, "û").replace(/Ã§/g, "ç")
    .replace(/Å“/g, "œ").replace(/Å'/g, "Œ")
    .replace(/comprim\?/g, "comprimé").replace(/comprim\?s/g, "comprimés")
    .replace(/g\?lule/g, "gélule").replace(/g\?lules/g, "gélules").replace(/gelule/g, "gélule").replace(/gelules/g, "gélules")
    .replace(/pellicul\?/g, "pelliculé").replace(/pellicul\?s/g, "pelliculés").replace(/pelicul\?/g, "pelliculé")
    .replace(/s\?cable/g, "sécable").replace(/s\?cables/g, "sécables")
    .replace(/r\?sistant/g, "résistant").replace(/lib\?ration/g, "libération")
    .replace(/prolong\?e/g, "prolongée").replace(/prolong\?s/g, "prolongés")
    .replace(/n\?buliseur/g, "nébuliseur").replace(/ solution \? diluer/g, " solution à diluer")
    .replace(/\s\?\s/g, " à ");
}

function parseCisCipBdpm(text, cisMap) {
  const rows = [];
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;
    const cols = line.split("\t");
    if (cols.length < 7) continue;
    const cis = String(cols[0]).trim();
    const libelleRaw = String(cols[2] || "").trim();
    const cip13Raw = String(cols[6] || "").replace(/\s/g, "").replace(/\D/g, "");
    if (cip13Raw.length !== 13) continue;
    const nom = normalizeAccents(cisMap[cis] || "");
    const dosage = extractDosage(nom || cisMap[cis] || "");
    const { quantite, unit } = extractQuantiteAndUnit(libelleRaw);
    const libelle = buildLibelle(nom, dosage, quantite, unit);
    rows.push({ cip13: cip13Raw, nom: nom, dosage: dosage, quantite: quantite, libelle: libelle });
  }
  return rows;
}

function buildLibelle(nom, dosage, quantite, unit) {
  const parts = [];
  const nomCourt = extractNomCourt(nom, dosage);
  if (nomCourt) parts.push(nomCourt);
  if (dosage) parts.push(dosage.replace(/\s/g, ""));
  const forme = extractFormeAbregee(nom);
  if (forme) parts.push(forme);
  if (quantite && unit) {
    const u = pluralize(unit, parseInt(quantite, 10));
    parts.push("boîte de " + quantite + " " + u);
  } else if (quantite) {
    parts.push("boîte de " + quantite);
  }
  return parts.join(" ").trim();
}

function extractNomCourt(nom, dosage) {
  if (!nom) return "";
  let s = nom.split(",")[0].trim();
  if (dosage) {
    const escaped = dosage.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s*");
    s = s.replace(new RegExp(escaped, "i"), "").trim();
  }
  s = s.replace(/\s+(comprimé|gélule|sachet|pelliculé|etc\.?).*$/i, "").trim();
  return s ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : "";
}

function extractFormeAbregee(nom) {
  if (!nom) return "";
  if (/libération prolongée|LP|à libération prolongée/i.test(nom)) return "LP";
  if (/gastro-résistant|gastro.resistant|entérique/i.test(nom)) return "GR";
  if (/orodispersible|oro-dispersible/i.test(nom)) return "OD";
  return "";
}

function pluralize(unit, n) {
  const u = (unit || "").toLowerCase();
  const sing = u.replace(/s$/, "");
  const plur = { "comprimé": "comprimés", "gélule": "gélules", "gelule": "gélules", "sachet": "sachets", "suppositoire": "suppositoires", "pastille": "pastilles", "flacon": "flacons", "ampoule": "ampoules", "tube": "tubes" };
  return n <= 1 ? sing : (plur[sing] || u);
}
