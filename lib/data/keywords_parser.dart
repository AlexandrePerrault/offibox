import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

Future<List<SearchResult>> parseKeywords(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return [];

  final lines = const LineSplitter().convert(response.body);
  if (lines.length <= 1) return [];

  final results = <SearchResult>[];

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final sep = trimmed.contains(';') ? ';' : ',';
    final row = trimmed.split(sep);

    if (row.length < 2) continue;

    final keyword =
        row[0].replaceAll('"', '').replaceAll("'", '').trim();
    final keywordUrl =
        row[1].replaceAll('"', '').replaceAll("'", '').trim();

    if (keyword.isEmpty || keywordUrl.isEmpty) continue;

    results.add(
      SearchResult(
        source: SourceType.keyword,

        labelRaw: keyword.toUpperCase(),
        label: keyword.toUpperCase(),

        cip13: null,
        cis: null,

        url: keywordUrl,
        isPdf: keywordUrl.toLowerCase().endsWith('.pdf'),

        nsfp: false,            // ✅ OBLIGATOIRE
        hospitalOnly: false,    // ✅ OBLIGATOIRE
        laboratory: '', // 🔴 OBLIGATOIRE
        meddisparUrl: null,
      ),
    );
  }

  return results;
}
