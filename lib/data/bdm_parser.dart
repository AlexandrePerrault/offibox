import 'dart:convert'; // ← OBLIGATOIRE
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:offibox/utils/normalize.dart';

import 'offiboxdata_fetch.dart';

// ============================================================================
// 📥 LOAD BDM
// ============================================================================
Future<List<Map<String, dynamic>>> parseBDM(String url) async {
  final response = await OffiboxDataFetch.get(url);
  if (response.statusCode != 200) return [];

  // ✅ UTF-8 (export script) ou fallback Latin-1
  String decoded;
  try {
    decoded = utf8.decode(response.bodyBytes);
  } catch (_) {
    decoded = latin1.decode(response.bodyBytes);
  }
  return compute(parseBdmSync, decoded);
}



String fixEncoding(String input) {
  try {
    // Tentative de réparation mojibake classique
    return utf8.decode(latin1.encode(input));
  } catch (_) {
    return input;
  }
}



// ============================================================================
// 🔒 UTF-16 SAFE
// ============================================================================
String removeInvalidUtf16(String input) {
  final buffer = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 < input.length) {
        final next = input.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(c);
          buffer.writeCharCode(next);
          i++;
        }
      }
      continue;
    }
    if (c >= 0xDC00 && c <= 0xDFFF) continue;
    buffer.writeCharCode(c);
  }
  return buffer.toString();
}
// ============================================================================
// 🧼 LABEL PREPROCESSING
// ============================================================================


// Fonction de normalisation des accents (si tu n’as pas normalizeText)
String normalizeFrenchChars(String input) {
  return input
      .replaceAll('Ã©', 'é')
      .replaceAll('Ã¨', 'è')
      .replaceAll('Ãª', 'ê')
      .replaceAll('Ã«', 'ë')
      .replaceAll('Ã ', 'à')
      .replaceAll('Ã¢', 'â')
      .replaceAll('Ã´', 'ô')
      .replaceAll('Ã»', 'û')
      .replaceAll('Ã¹', 'ù')
      .replaceAll('Ã®', 'î')
      .replaceAll('Ã¯', 'ï')
      .replaceAll('Ã§', 'ç');
}

/// Remplace les "?" utilisés comme placeholder pour les lettres accentuées
/// (ex. comprim? → comprimé, s?cable → sécable) dans le CSV BDM.
String normalizeQuestionMarkAccents(String input) {
  return input
      .replaceAll('comprim?', 'comprimé')
      .replaceAll('comprim?s', 'comprimés')
      .replaceAll('comprim?(s)', 'comprimé(s)')
      .replaceAll('pellicul?', 'pelliculé')
      .replaceAll('pellicul?s', 'pelliculés')
      .replaceAll('g?lule', 'gélule')
      .replaceAll('g?lules', 'gélules')
      .replaceAll('g?lule(s)', 'gélule(s)')
      .replaceAll('s?cable', 'sécable')
      .replaceAll('s?cables', 'sécables')
      .replaceAll('lib?ration', 'libération')
      .replaceAll('prolong?e', 'prolongée')
      .replaceAll('prolong?s', 'prolongés')
      .replaceAll('n?buliseur', 'nébuliseur')
      .replaceAll('n?buliseurs', 'nébuliseurs')
      .replaceAll(' solution ? diluer', ' solution à diluer')
      .replaceAll(RegExp(r'\s\?\s'), ' à ');
}

/// Normalise la colonne COMPOSITION du CSV composition-bdm (CIS;COMPOSITION).
/// Remplace les ? utilisés comme placeholder pour é, è, ê, à, etc.
String normalizeComposition(String input) {
  if (input.isEmpty) return input;
  String s = normalizeFrenchChars(input);
  s = normalizeQuestionMarkAccents(s);
  // ? entre deux lettres = souvent é (DUTAST?RIDE, PARAC?TAMOL, L?VO, etc.)
  s = s.replaceAllMapped(RegExp(r'([A-Za-zÀ-ÿ])\?([A-Za-zÀ-ÿ])'), (m) => '${m[1]}é${m[2]}');
  // ? en fin de mot (H?MIHYDRAT?, DIHYDRAT?, HEXAHYDRAT?)
  s = s.replaceAllMapped(RegExp(r'([A-Za-zÀ-ÿ])\?(\s|$|,)'), (m) => '${m[1]}é${m[2]}');
  // Espace ? espace = à (pommade ? 1 %)
  s = s.replaceAll(RegExp(r'\s\?\s'), ' à ');
  return s.trim();
}

// Enlève guillemet/point d'interrogation en tête, puis normalise les accents
String preprocessRawLabel(String raw) {
  String cleaned = raw.trim();
  if (cleaned.startsWith('"')) cleaned = cleaned.substring(1).trim();
  if (cleaned.startsWith('?')) cleaned = cleaned.substring(1).trim();
  cleaned = normalizeFrenchChars(cleaned);
  cleaned = normalizeQuestionMarkAccents(cleaned);
  return cleaned;
}

// Fonction de nettoyage du label — utilise normalizeText (accents, ?, mojibake)
String cleanLabel(String raw) {
  String processed = raw.trim();
  if (processed.startsWith('"')) processed = processed.substring(1).trim();
  processed = normalizeText(processed);
  processed = removeInvalidUtf16(processed);
  return processed
      .replaceAll('\uFFFD', '')
      .replaceAll(RegExp(r'[💊🩹🐾📘⛔❌⚠️🔴🟦🟩🟥]'), '')
      .replaceAll(RegExp(r'\(STUP\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(HOP\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(EXCEPTION\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(OTC\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(BIOSIMILAIRE\)', caseSensitive: false), '')
      .replaceAll('"', '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
// ============================================================================
// 📅 DATE JS → FR
// ============================================================================
String? formatJsDateToFr(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final reg = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
  final match = reg.firstMatch(raw);
  if (match == null) return raw;
  const months = {
    'Jan': '01',
    'Feb': '02',
    'Mar': '03',
    'Apr': '04',
    'May': '05',
    'Jun': '06',
    'Jul': '07',
    'Aug': '08',
    'Sep': '09',
    'Oct': '10',
    'Nov': '11',
    'Dec': '12',
  };
  final month = months[match.group(1)];
  if (month == null) return raw;
  return '${match.group(2)!.padLeft(2, '0')}/$month/${match.group(3)}';
}

// ============================================================================
// 🧠 PARSER BDM
// ============================================================================
List<Map<String, dynamic>> parseBdmSync(String raw) {
  final lines = const LineSplitter().convert(raw);
  final result = <Map<String, dynamic>>[];
  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 14) continue; // CSV 2026: min 14 colonnes

    final rawLabel = row[0];
    final upper = rawLabel.toUpperCase();

    // CSV 2026: 0=Dénomination, 1=CIP7, 2=CIP13, 3=CIS, 4=Date, 5=URL BDPM, 6=Libre-accès, 7=NSFP, 8=URL EXTERNES, 9=URL MEDDISPAR, 10=Biosimilaire, 11=Libellé rupture, 12=Date rupture, 13=Mise à jour ANSM, 14=URL ANSM
    final rawNsfpFlag = row.length > 7 ? row[7].replaceAll('"', '').trim().toLowerCase() : '';
    final rawNsfpDate = row.length > 12 ? row[12].replaceAll('"', '').trim() : '';
    final bool nsfp = rawNsfpFlag == 'oui';
    final String? nsfpDate = nsfp ? (formatJsDateToFr(rawNsfpDate) ?? (rawNsfpDate.isNotEmpty ? rawNsfpDate : null)) : null;

    final cip7 = row[1].replaceAll(RegExp(r'\D'), '');
    final cip13 = row[2].replaceAll(RegExp(r'\D'), '');
    final cis = row.length > 3 ? row[3].replaceAll(RegExp(r'\D'), '').trim() : '';
    if (cip7.length != 7 || cip13.length != 13) continue;

    final String rawMeddispar = row.length > 9 ? row[9].replaceAll('"', '').trim() : '';
    final String? meddisparUrl = rawMeddispar.isNotEmpty ? rawMeddispar : null;

    const bloodCips = {
      '3400932892198',
      '3400936397194',
      '3400936397026',
    };
    final bool isMds = bloodCips.contains(cip13);

    final bool liste1 = RegExp(r'\bLISTE\s*(I|1)\b', caseSensitive: false).hasMatch(rawLabel);
    final bool liste2 = RegExp(r'\bLISTE\s*(II|2)\b', caseSensitive: false).hasMatch(rawLabel);
    // Stupéfiant : libellé contient (STUP) ou liste I / liste II
    final bool isStup = upper.contains('(STUP)') || liste1 || liste2;
    // Exception : libellé contient (EXCEPTION)
    final bool isException = upper.contains('(EXCEPTION)');
    // OTC : colonne 6 "Libre-accès" = oui OU libellé contient (OTC)
    final String libreAcces = row.length > 6 ? row[6].replaceAll('"', '').trim().toLowerCase() : '';
    final bool isOtc = libreAcces == 'oui' || upper.contains('(OTC)');

    final String biosimilaireCol = row.length > 10 ? row[10].replaceAll('"', '').trim() : '';
    result.add({
      'labelRaw': rawLabel,
      'label': cleanLabel(rawLabel), // ← Ici, le label est déjà pré-traité
      'cip7': cip7,
      'cip13': cip13,
      'cis': cis.isNotEmpty ? cis : null,
      'urlBdpm': row.length > 5 ? row[5].trim() : '',
      'isStup': isStup,
      'isMds': isMds,
      'isException': isException,
      'isOtc': isOtc,
      'liste1': liste1,
      'liste2': liste2,
      'nsfp': nsfp,
      'nsfpDate': nsfpDate,
      'biosimilaire': biosimilaireCol.isNotEmpty ? biosimilaireCol : null,
      'ansmStatut': row.length > 11 ? row[11].trim() : '',
      'ansmDate': row.length > 12 ? row[12].trim() : '',
      'ansmUrl': row.length > 14 ? row[14].trim() : '',
      'meddisparUrl': meddisparUrl,
    });
  }
  return result;
}
