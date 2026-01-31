import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

import 'models/search_result.dart';

class CsvRepository {
  final List<String> csvUrls;

  CsvRepository(this.csvUrls);

  final List<List<String>> _rows = [];

  Future<void> loadAll() async {
    _rows.clear();

    for (final url in csvUrls) {
      final res = await http.get(Uri.parse(url));
      print('URL: $url → ${res.bodyBytes.length} bytes');

      if (res.statusCode != 200) continue;

      String text;
      try {
        text = utf8.decode(res.bodyBytes);
      } catch (_) {
        text = latin1.decode(res.bodyBytes);
      }

      text = text.replaceAll('\uFEFF', '');
      text = text.replaceAll('\r\n', '\n');
      text = text.replaceAll('\r', '\n');

      final parsed = CsvToListConverter(
        fieldDelimiter: ';',
        textDelimiter: '"',
        shouldParseNumbers: false,
      ).convert(text);

      print('→ lignes parsées: ${parsed.length}');

      for (final row in parsed) {
        if (row.isEmpty) continue;
        if (row.every((c) => c.toString().trim().isEmpty)) continue;

        _rows.add(row.map((c) => c.toString()).toList());
      }
    }

    print('📦 Lignes chargées : ${_rows.length}');
  }

  List<SearchResult> searchMedicaments(String query, {int limit = 20}) {
    if (query.isEmpty) return [];

    final q = query.toLowerCase().trim();
    final List<SearchResult> results = [];

    for (final row in _rows) {
      if (row.isEmpty) continue;

      final label = row[0].toLowerCase();
      final cip = row.length > 1 ? row[1].toLowerCase() : '';

      if (!label.contains(q) && !cip.contains(q)) continue;

      results.add(
        SearchResult(
          label: row[0],
          cip13: row.length > 1 ? row[1] : '',
          url: row.length > 4 ? row[4] : '',
          isBDMAlert:
              row.length > 18 && row[18].toString().toLowerCase() == 'oui',
        ),
      );

      if (results.length >= limit) break;
    }

    return results;
  }

  int get rowsCount => _rows.length;
}
