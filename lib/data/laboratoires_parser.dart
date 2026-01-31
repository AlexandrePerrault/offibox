import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

Future<List<SearchResult>> parseLaboratoires(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Erreur chargement LABORATOIRES.csv');
  }

  final lines = const LineSplitter().convert(response.body);
  final results = <SearchResult>[];

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    if (row.isEmpty || row[0].isEmpty) continue;

    final raw = row[0].toUpperCase();

    // 🔑 NORMALISATION PDF (clé du bug)
    final rawCatalogue = _v(row, 5);
    final String? catalogue = rawCatalogue != null
    ? rawCatalogue.split('?').first.trim()
    : null;

    results.add(
      SearchResult(
        labelRaw: raw,
        label: raw,

        cip13: null,
        cis: null,

        source: SourceType.catalogue,

        nsfp: false,
        hospitalOnly: false,

        iconUrl: _v(row, 1),
        phone: _v(row, 2),
        fax: _v(row, 3),
        email: _v(row, 4),

        // 📘 catalogue PDF
        catalogueUrl: catalogue,
        url: catalogue, // ✅ isPdf = TRUE

        badge1Name: _v(row, 6),
        badge1Url: _v(row, 7),

        badge2Name: _v(row, 8) ?? 'AUTRE SITE',
        badge2Url: _v(row, 9),

        badge3Name: _v(row, 10),
        badge3Url: _v(row, 11),

        laboratory: raw,
        meddisparUrl: null,
      ),
    );
  }

  return results;
}

String? _v(List<String> row, int index) {
  if (index >= row.length) return null;
  return row[index].isEmpty ? null : row[index];
}
