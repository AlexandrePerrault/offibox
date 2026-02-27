import 'dart:convert';
import 'package:http/http.dart' as http;

const String _biosimilaires2026Url =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/biosimilaires%202026.csv';

/// biosimilaireByCip :
/// CIP13 (col D) → PRINCEPS normalisé (col B)
Future<Map<String, String>> loadBiosimilairesByCip() async {
  final response = await http.get(Uri.parse(_biosimilaires2026Url));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length < 4) continue;

    final princepsRaw = cols[1].replaceAll('"', '').trim();
    final cip13 = cols[3].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    final princepsNormalized = normalizePrincepsName(princepsRaw);
    map[cip13] = princepsNormalized;
  }

  return map;
}

/// CIP13 (col D, index 3) → contenu colonne 5 (index 4) pour fenêtre « Infos biosimilaire » (affichage avec puces).
Future<Map<String, String>> loadBiosimilairesInfoByCip() async {
  final response = await http.get(Uri.parse(_biosimilaires2026Url));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length < 5) continue;

    final cip13 = cols[3].replaceAll(RegExp(r'\D'), '');
    final col5 = cols[4].replaceAll('"', '').trim();

    if (cip13.length != 13 || col5.isEmpty) continue;

    map[cip13] = col5;
  }

  return map;
}

/// Découpe une ligne CSV en respectant les guillemets (champs pouvant contenir ';').
List<String> _parseCsvLine(String line) {
  final list = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && c == ';') {
      list.add(current.toString().trim());
      current = StringBuffer();
    } else {
      current.write(c);
    }
  }
  list.add(current.toString().trim());
  return list;
}

/// 🔧 normalisation métier PRINCEPS
String normalizePrincepsName(String label) {
  return label
      .toUpperCase()
      .split(',').first
      .split(' - ').first
      .replaceAll(RegExp(r'\b\d+.*'), '')
      .trim();
}
