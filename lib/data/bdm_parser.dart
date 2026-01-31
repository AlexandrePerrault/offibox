import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// ============================================================================
// 📥 LOAD BDM
// ============================================================================
Future<List<Map<String, dynamic>>> parseBDM(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return [];
  return compute(parseBdmSync, response.body);
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
// 🧼 LABEL (AFFICHAGE UNIQUEMENT)
// ============================================================================
String cleanLabel(String raw) {
  return removeInvalidUtf16(raw)
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
// 🧠 PARSER BDM (CSV BRUT → MAP)
// ============================================================================
List<Map<String, dynamic>> parseBdmSync(String raw) {
  final lines = const LineSplitter().convert(raw);
  final result = <Map<String, dynamic>>[];

  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 14) continue;

    final rawLabel = row[0];
    final upper = rawLabel.toUpperCase();

// ───── NSFP — règles métier BLINDÉES
// ───── NSFP — règle volontairement NON stricte
final String rawNsfpFlag =
    row[6].replaceAll('"', '').trim().toLowerCase(); // "oui"
final String rawNsfpDate =
    row[7].replaceAll('"', '').trim();               // JS date

final bool nsfp = rawNsfpFlag == 'oui';
final String? nsfpDate =
    nsfp ? formatJsDateToFr(rawNsfpDate) : null;

 

   result.add({
      // ───── Labels
      'labelRaw': rawLabel,
      'label': cleanLabel(rawLabel),

      // ───── Codes
      'cip13': row[2].replaceAll(RegExp(r'\D'), '').trim(),
      'urlBdpm': row[4].trim(),

      // ───── Statuts
      'isStup': upper.contains('(STUP)'),
      'isException': upper.contains('(EXCEPTION)'),
      'isOtc': upper.contains('(OTC)'),

      // ───── Listes
      'liste1': RegExp(r'\bLISTE\s*(I|1)\b', caseSensitive: false)
          .hasMatch(rawLabel),
      'liste2': RegExp(r'\bLISTE\s*(II|2)\b', caseSensitive: false)
          .hasMatch(rawLabel),

      // ───── NSFP
     'nsfp': nsfp,
     'nsfpDate': nsfpDate,



      // ───── ANSM
      'ansmStatut': row[10].trim(),
      'ansmDate': row[12].trim(),
      'ansmUrl': row[13].trim(),

      // ───── Meddispar
      'meddisparUrl': row[8].trim(),
    });
  }

  return result;
}
