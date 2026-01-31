import 'dart:convert'; // LineSplitter
import 'package:http/http.dart' as http;
import '../models/veto_item.dart';

String cleanVetoLabel(String raw) {
  return raw
      .replaceAll('\uFFFD', '')
      .replaceAll('🐾', '')
      .replaceAll('"', '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll("'", '')
      .replaceAllMapped(
        RegExp(r'^\s*\(?\s*VETO\s*\)?\s*', caseSensitive: false),
        (_) => '(VETO) ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<List<VetoItem>> parseVeto(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return [];

  final lines = const LineSplitter().convert(response.body);
  final result = <VetoItem>[];

  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 2) continue;

    final String label = cleanVetoLabel(row[0]);

    // ✅ GTIN propre (chiffres uniquement)
    final String gtin =
        row[1].replaceAll(RegExp(r'\D'), '').trim();
    if (gtin.isEmpty) continue;

    // ✅ URL RCP (optionnelle)
    final String rcpUrl =
        row.length > 2 ? row[2].replaceAll('"', '').trim() : '';

    result.add(
      VetoItem(
        label: label,
        cip13: gtin,        // ✅ GTIN CORRECT
        url: rcpUrl,        // ✅ rcpUrl DÉFINIE
      ),
    );
  }

  return result;
}
