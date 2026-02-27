import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';
import 'package:offibox/models/source_type.dart';







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

 // ==========================================================================
  // ✅ PARSER CERP/SERP (CSV : "nom";"cip";"url")
  // - Recherche par nom (col A) ou CIP7/CIP13 (col B)
  // - Affichage label + badge "PLUS D'INFOS" (clic => url)
  // ==========================================================================
  Future<List<SearchResult>> parseCerp(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final lines = const LineSplitter().convert(response.body);
    final results = <SearchResult>[];

    for (int i = 1; i < lines.length; i++) {
      final row = lines[i]
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();

      if (row.length < 3) continue;

      final name = row[0];
      final cip = row[1].replaceAll(RegExp(r'\D'), '');
      final link = row[2];

      if (name.isEmpty || link.isEmpty) continue;

      results.add(
        SearchResult(
          source: SourceType.cerp,
          label: name,
          labelRaw: name.toUpperCase(),
          cip13: cip.isEmpty ? null : cip,
          url: link,
          nsfp: false,
          hospitalOnly: false,
          laboratory: 'CERP',
          badge1Name: 'PLUS D’INFOS',
          badge1Url: link,
        ),
      );
    }

    return results;
  }
