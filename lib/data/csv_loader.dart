import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

Future<List<List<String>>> loadCsvFromUrl(String url) async {
  final res = await http.get(Uri.parse(url));

  if (res.statusCode != 200) {
    throw Exception('Erreur HTTP $url');
  }

  final text = utf8
      .decode(res.bodyBytes)
      .replaceAll('\uFEFF', '')
      .trim();

  final rows = const CsvToListConverter(
    fieldDelimiter: ';',
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(text);

  if (kDebugMode) {
    debugPrint('URL: $url');
    debugPrint('→ lignes parsées: ${rows.length}');
  }
  return rows
      .map((r) => r.map((c) => c.toString()).toList())
      .toList();
}
