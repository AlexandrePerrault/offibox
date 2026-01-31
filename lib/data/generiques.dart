import 'dart:convert';
import 'package:http/http.dart' as http;

const String GENERIQUES_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/g%C3%A9n%C3%A9riques%202026.csv';

const String BDM_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_MASTER2026.csv';

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

    if (row.length < 4) continue;

    final princepsRaw = row[1];
    final cip13 = row[3].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    map[cip13] = normalizePrincepsKey(princepsRaw);
  }

  return map;
}





// =====================================================
// 2️⃣ PRINCEPS → NOM GÉNÉRIQUE (DCI) VIA CIP GÉNÉRIQUE → BDM
// =====================================================
Future<Map<String, String>> loadPrincepsToGenericName() async {
  // 1) princeps -> premier CIP générique (col D)
  final princepsToGenericCip = await loadPrincepsToGenericCip();
  if (princepsToGenericCip.isEmpty) return {};

  // 2) map CIP13 -> libellé BDM (pour retrouver le nom du générique)
  final bdmLabelByCip = await _loadBdmLabelByCip();
  if (bdmLabelByCip.isEmpty) return {};

  // 3) build : princepsKey -> DCI générique
  final Map<String, String> out = {};

  princepsToGenericCip.forEach((princepsKey, genericCip13) {
    final bdmLabel = bdmLabelByCip[genericCip13];
    if (bdmLabel == null || bdmLabel.isEmpty) return;

    final dci = cleanGenericNameFromBdm(bdmLabel);
    if (dci.isEmpty) return;

    out[princepsKey] = dci;
  });

  return out;
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

    final princepsRaw = row[1];
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

// =====================================================
// BDM : CIP13 -> LIBELLÉ
// (simple et robuste : détecte ; ou ,)
// =====================================================
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

  int idxCip = headers.indexWhere((h) =>
      h.toUpperCase() == 'CIP13' ||
      h.toUpperCase() == 'CIP 13' ||
      h.toUpperCase() == 'CIP' ||
      h.toUpperCase() == 'CODE CIP');

  int idxLabel = headers.indexWhere((h) =>
      h.toUpperCase() == 'LIBELLÉ' ||
      h.toUpperCase() == 'LIBELLE' ||
      h.toUpperCase() == 'LABEL');

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
