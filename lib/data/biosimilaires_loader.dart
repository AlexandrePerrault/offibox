import 'dart:convert';
import 'package:http/http.dart' as http;

/// biosimilaireByCip :
/// CIP13 (col D) → PRINCEPS normalisé (col B)
Future<Map<String, String>> loadBiosimilairesByCip() async {
  const url =
      'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/biosimilaires%202026.csv';

  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final Map<String, String> map = {};

  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;

    final cols = line.split(';');
    if (cols.length < 4) continue;

    final princepsRaw =
        cols[1].replaceAll('"', '').trim();
    final cip13 =
        cols[3].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    final princepsNormalized =
        normalizePrincepsName(princepsRaw);

    map[cip13] = princepsNormalized;
  }

  return map;
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
