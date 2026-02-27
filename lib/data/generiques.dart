import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:offibox/utils/normalize.dart';
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/composition_bdm_loader.dart';

/// CSV ANSM normalisé (DCI; princeps_nom; princeps_cip; cip13)
const String GENERIQUES_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/refs/heads/main/generiques_ansm.csv';

const String BDM_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_MASTER2026.csv';

/// CSV génériques 2026 : "générique";"princeps A";"princeps B";"CIS"
/// Index 0 = générique (DCI), 1 = princeps A, 2 = princeps B, 3 = CIS. Badge princeps utilise col 1.
const String GENERIQUES_2026_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/g%C3%A9n%C3%A9riques%202026.csv';

/// Info pour un CIS présent dans le CSV génériques 2026 (ligne = princeps).
class Generique2026Info {
  const Generique2026Info({
    required this.genericNameColA,
    required this.princepsUppercase,
    required this.princepsDisplay,
  });
  /// Col A du CSV (nom générique), en majuscules pour affichage.
  final String genericNameColA;
  /// Produit princeps en majuscules (col "princeps A", index 1, ex. TAGAMET 200 MG).
  final String princepsUppercase;
  /// Libellé princeps pour affichage ligne 2 (génériques) : col B et col C en majuscules, séparés par « - » si col C présente (ex. « TAGAMET 200 MG » ou « AZANTAC 150 MG - RANIPLEX 150 MG »).
  final String princepsDisplay;
}

/// Normalise un champ texte du CSV (accents, mojibake, espaces).
String _normalizeCsvField(String s) {
  if (s.isEmpty) return s;
  var t = normalizeText(s);
  // Moji bake fréquent dans le CSV ANSM : "CHLORHYDRATE D" → "CHLORHYDRATE DE"
  t = t.replaceAll('\uFFFD', 'E');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

// =====================================================
// 0️⃣ ENSEMBLE DES CIP13 PRÉSENTS DANS LE FICHIER (référence unique)
// Utilisé pour le filtre « Génériques » et la liste des laboratoires.
// =====================================================
Future<Set<String>> loadGenericCipSet() async {
  final response = await http.get(Uri.parse(GENERIQUES_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final set = <String>{};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 4) continue;

    final cip13 = row[3].replaceAll(RegExp(r'\D'), '');
    if (cip13.length != 13) continue;

    set.add(cip13);
  }

  return set;
}

// =====================================================
// 1️⃣ CIP GÉNÉRIQUE → PRINCEPS
// =====================================================
Future<Map<String, String>> loadGeneriquesByCip() async {
  final response = await http.get(Uri.parse(GENERIQUES_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 3) continue;

    final princepsRaw = _normalizeCsvField(row[1]);
    // CIP13 du générique : colonne 3 (ou 2 si format différent)
    var cip13 = row.length > 3 ? row[3].replaceAll(RegExp(r'\D'), '') : '';
    if (cip13.length != 13 && row.length > 2) cip13 = row[2].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    map[cip13] = normalizePrincepsKey(princepsRaw);
  }

  return map;
}

// =====================================================
// GÉNÉRIQUES 2026 — CSV "générique";"princeps A";"princeps B";"CIS"
// =====================================================

/// Extrait la partie en majuscules de la col B (ex. "TAGAMET 200 mg" → "TAGAMET").
String _princepsUppercaseFromColB(String colB) {
  final t = colB.trim();
  if (t.isEmpty) return '';
  final firstWord = t.split(RegExp(r'\s+')).first.trim();
  return firstWord.toUpperCase();
}

/// CIS → info pour afficher "générique de X" (badge rose) et déplacer RCP/MEDDISPAR en ligne 2.
Future<Map<String, Generique2026Info>> loadGeneriques2026ByCis() async {
  final response = await http.get(Uri.parse(GENERIQUES_2026_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, Generique2026Info> map = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 4) continue;

    final colA = _normalizeCsvField(row[0]);
    final princepsB = (row.length > 1) ? row[1].trim() : '';
    final princepsC = (row.length > 2) ? row[2].trim() : '';
    final cis = row[3].replaceAll(RegExp(r'\D'), '').trim();

    if (colA.isEmpty || princepsB.isEmpty || cis.length < 7) continue;

    final princepsUppercase = princepsB.trim().toUpperCase();
    if (princepsUppercase.isEmpty) continue;

    final princepsDisplay = princepsC.isEmpty
        ? princepsB.trim().toUpperCase()
        : '${princepsB.trim().toUpperCase()} - ${princepsC.trim().toUpperCase()}';

    map[cis] = Generique2026Info(
      genericNameColA: colA.toUpperCase(),
      princepsUppercase: princepsUppercase,
      princepsDisplay: princepsDisplay,
    );
  }

  return map;
}

/// Retourne la partie de la colonne A après " à " (pour afficher "générique : X" sans le préfixe).
String genericNameAfterA(String colA) {
  if (colA.isEmpty) return colA;
  const marker = ' à ';
  final idx = colA.toUpperCase().indexOf(marker);
  if (idx < 0) return colA.trim();
  return colA.substring(idx + marker.length).trim();
}

/// CIS → liste des libellés génériques (col A) pour ce princeps. Pour le badge "Afficher la liste des génériques correspondants".
Future<Map<String, List<String>>> loadGeneriques2026ListByCis() async {
  final response = await http.get(Uri.parse(GENERIQUES_2026_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, List<String>> map = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 4) continue;

    final colA = _normalizeCsvField(row[0]);
    final cis = row[3].replaceAll(RegExp(r'\D'), '').trim();

    if (colA.isEmpty || cis.length < 7) continue;

    map.putIfAbsent(cis, () => []).add(colA.toUpperCase());
  }

  return map;
}

/// Clé = premier mot des col B et C (majuscules, ex. TAGAMET, RANIPLEX). Valeur = col A en majuscules.
/// Permet de reconnaître un princeps si le libellé correspond à col B ou col C (ex. afficher composition seulement si ni générique ni princeps).
Future<Map<String, String>> loadGeneriques2026PrincepsKeyToGenericName() async {
  final response = await http.get(Uri.parse(GENERIQUES_2026_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 2) continue;

    final colA = _normalizeCsvField(row[0]);
    final colB = (row.length > 1) ? row[1].trim() : '';
    final colC = (row.length > 2) ? row[2].trim() : '';

    if (colA.isEmpty) continue;

    if (colB.isNotEmpty) {
      final princepsKeyB = _princepsUppercaseFromColB(colB);
      if (princepsKeyB.isNotEmpty) map[princepsKeyB] = colA.toUpperCase();
    }
    if (colC.isNotEmpty) {
      final princepsKeyC = _princepsUppercaseFromColB(colC);
      if (princepsKeyC.isNotEmpty) map[princepsKeyC] = colA.toUpperCase();
    }
  }

  return map;
}

/// Clé = premier mot de la col A (DCI, ex. ZOLPIDEM). Valeur = col A en majuscules.
/// Pour les produits BDM dont le libellé contient cette DCI en mot entier, afficher "générique : col A".
/// Évite les faux positifs (ex. ALMUS dans "ZOLPIDEM ALMUS" ne doit pas afficher ENALAPRIL).
Future<Map<String, String>> loadGeneriques2026DciToGenericName() async {
  final response = await http.get(Uri.parse(GENERIQUES_2026_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.isEmpty) continue;

    final colA = _normalizeCsvField(row[0]);
    if (colA.isEmpty) continue;

    final dci = colA.toUpperCase().split(RegExp(r'\s+')).first.trim();
    if (dci.isEmpty || dci.length < 3) continue;

    map[dci] = colA.toUpperCase();
  }

  return map;
}

// =====================================================
// 2️⃣ PRINCEPS → NOM GÉNÉRIQUE (DCI) DEPUIS LE CSV ANSM
// =====================================================
Future<Map<String, String>> loadPrincepsToGenericName() async {
  final response = await http.get(Uri.parse(GENERIQUES_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> out = {};
  final Set<String> seen = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 4) continue;

    final dciRaw = _normalizeCsvField(row[0]);
    final princepsRaw = _normalizeCsvField(row[1]);
    if (dciRaw.isEmpty || princepsRaw.isEmpty) continue;

    final princepsKey = normalizePrincepsKey(princepsRaw);
    if (seen.contains(princepsKey)) continue;
    seen.add(princepsKey);

    out[princepsKey] = dciRaw;
  }

  return out;
}

// =====================================================
// 2ter) DCI → PRINCEPS — chaîne : DCI → CIS → CIP13 → nom col A BDM Master → nom normalisé
// (ex. daridorexant → QUIVIVIQ en ligne 1)
// =====================================================
/// Si [dciToCis] est fourni, il est utilisé (évite un double chargement du CSV composition-bdm).
Future<Map<String, String>> loadGenericNameToPrinceps({Map<String, List<String>>? dciToCis}) async {
  // 1) DCI → CIS (composition-bdm)
  final dciMap = dciToCis ?? await loadCompositionBdm();
  if (dciMap.isEmpty) return {};

  final bdmRows = await parseBDM(BDM_URL);
  if (bdmRows.isEmpty) return {};

  // 2) CIS → lignes BDM (chaque ligne a CIP13 et colonne A = dénomination)
  final cisToBdmRows = <String, List<Map<String, dynamic>>>{};
  for (final row in bdmRows) {
    final cis = row['cis']?.toString().replaceAll(RegExp(r'\D'), '').trim();
    if (cis == null || cis.isEmpty) continue;
    cisToBdmRows.putIfAbsent(cis, () => []).add(row);
  }

  final out = <String, String>{};
  for (final entry in dciMap.entries) {
    final dciNorm = entry.key;
    final cisList = entry.value;

    for (final cis in cisList) {
      final rows = cisToBdmRows[cis];
      if (rows == null || rows.isEmpty) continue;

      // 3) Pour ce CIS, ligne princeps = celle dont la col A (dénomination) ne commence pas par le DCI
      Map<String, dynamic>? princepsRow;
      for (final row in rows) {
        final colA = (row['labelRaw'] ?? row['label'] ?? '').toString().trim();
        if (colA.isEmpty) continue;
        if (_firstWordNorm(colA) != dciNorm) {
          princepsRow = row;
          break;
        }
      }
      princepsRow ??= rows.first;

      // 4) Nom du princeps = colonne A de BDM Master (dénomination) → nom normalisé
      final nomPrincepsColA = (princepsRow['labelRaw'] ?? princepsRow['label'] ?? '').toString().trim();
      if (nomPrincepsColA.isEmpty) continue;
      final nomNormalise = normalizePrincepsKey(nomPrincepsColA);
      if (nomNormalise.isEmpty) continue;

      out[dciNorm] = nomNormalise;
      break; // un DCI → un princeps (on garde le premier CIS traité)
    }
  }

  return out;
}

/// Premier mot du libellé BDM, normalisé (pour comparer à un DCI).
String _firstWordNorm(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  return parts.first
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

// =====================================================
// 2bis) PRINCEPS → CIP13 GÉNÉRIQUE (PREMIER DE LA LISTE)
// clé = normalizePrincepsKey(princeps)
// =====================================================
Future<Map<String, String>> loadPrincepsToGenericCip() async {
  final response = await http.get(Uri.parse(GENERIQUES_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);

  final Map<String, String> map = {};
  final Set<String> seen = {};

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 4) continue;

    final princepsRaw = _normalizeCsvField(row[1]);
    final cip13 = row[3].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    final princepsKey = normalizePrincepsKey(princepsRaw);

    // 1er générique uniquement
    if (seen.contains(princepsKey)) continue;
    seen.add(princepsKey);

    map[princepsKey] = cip13;
  }

  return map;
}

// ignore: unused_element - Réservé pour usage futur.
Future<Map<String, String>> _loadBdmLabelByCip() async {
  final response = await http.get(Uri.parse(BDM_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  if (lines.isEmpty) return {};

  // détecte le séparateur sur l’en-tête
  final header = lines.first;
  final sep = _detectSep(header);

  final headers = header
      .split(sep)
      .map((e) => e.replaceAll('"', '').trim())
      .toList();

  int idxCip = headers.indexWhere(
    (h) =>
        h.toUpperCase() == 'CIP13' ||
        h.toUpperCase() == 'CIP 13' ||
        h.toUpperCase() == 'CIP' ||
        h.toUpperCase() == 'CODE CIP',
  );

  int idxLabel = headers.indexWhere(
    (h) =>
        h.toUpperCase() == 'LIBELLÉ' ||
        h.toUpperCase() == 'LIBELLE' ||
        h.toUpperCase() == 'LABEL',
  );

  // fallback si headers bizarres
  if (idxCip < 0) idxCip = 2;
  if (idxLabel < 0) idxLabel = 0;

  final Map<String, String> out = {};

  for (int i = 1; i < lines.length; i++) {
    final cols = lines[i]
        .split(sep)
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (cols.length <= idxCip || cols.length <= idxLabel) continue;

    final cip13 = cols[idxCip].replaceAll(RegExp(r'\D'), '');
    if (cip13.length != 13) continue;

    final label = cols[idxLabel];
    if (label.isEmpty) continue;

    // on garde le premier (ou écrase, peu importe)
    out[cip13] = label;
  }

  return out;
}

String _detectSep(String headerLine) {
  final sc = ';'.allMatches(headerLine).length;
  final cc = ','.allMatches(headerLine).length;
  return sc >= cc ? ';' : ',';
}

// =====================================================
// 🔧 NORMALISATION CLÉ PRINCEPS (même logique que ton main)
// =====================================================
String normalizePrincepsKey(String label) {
  return label
      .toUpperCase()
      .split(',').first
      .split(' - ').first
      .replaceAll(RegExp(r'\b\d+.*'), '')
      .trim();
}

// =====================================================
// 🔧 NETTOYAGE DCI DEPUIS LIBELLÉ BDM GÉNÉRIQUE
// =====================================================
String cleanGenericNameFromBdm(String label) {
  if (label.isEmpty) return '';

  final upper = label.toUpperCase();
  final parts = upper.split(RegExp(r'\s+'));

  // retire la marque (1er mot)
  final withoutBrand = parts.length > 1 ? parts.sublist(1) : parts;

  final kept = <String>[];
  for (final p in withoutBrand) {
    if (RegExp(r'\d').hasMatch(p)) break; // stop dosage
    kept.add(p);
  }

  return kept.join(' ').trim();
}
