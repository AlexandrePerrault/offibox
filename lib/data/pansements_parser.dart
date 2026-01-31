import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pansement_item.dart';

// ─────────────────────────────────────────────
// 🧼 Nettoyage STRICT des libellés pansements
// ─────────────────────────────────────────────
String cleanPansementLabel(String raw) {
  String label = raw;

  // caractère corrompu
  label = label.replaceAll('\uFFFD', '');

  // enlève UNIQUEMENT le pictogramme pansement
  label = label.replaceAll('🩹', '');

  // enlève guillemets / apostrophes
  label = label.replaceAll('"', '').replaceAll("'", '');

  // normalisation des espaces
  label = label.replaceAll(RegExp(r'\s+'), ' ').trim();

  return label;
}

// ─────────────────────────────────────────────
// 🩹 PARSER PANSEMENTS
// ─────────────────────────────────────────────
Future<List<PansementItem>> parsePansements(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    return [];
  }

  final lines = const LineSplitter().convert(response.body);
  final result = <PansementItem>[];

  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 2) continue;

    result.add(
      PansementItem(
        label: cleanPansementLabel(row[0]),
        cip13: row[1].trim(),
        url: row.length > 2 ? row[2].trim() : '',
      ),
    );
  }

  return result;
}
