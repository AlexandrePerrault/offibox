import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

Future<List<SearchResult>> parseSerp(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Erreur chargement SERP.csv');
  }

  final lines = const LineSplitter().convert(response.body);
  final results = <SearchResult>[];

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.length < 3) continue;

    final label = row[0];
    final cip = row[1].replaceAll(RegExp(r'\D'), '');
    final urlProduit = row[2];

    if (label.isEmpty || urlProduit.isEmpty) continue;

    results.add(
      SearchResult(
        source: SourceType.cerp, // ✅ ICI

        label: label,
        labelRaw: label.toUpperCase(),

        // CIP 7 ou 13 accepté
        cip13: cip.isNotEmpty ? cip : null,

        url: urlProduit,

        nsfp: false,
        hospitalOnly: false,

        laboratory: 'SERP / CERP', // 🔒 obligatoire chez toi
      ),
    );
  }

  return results;
}
