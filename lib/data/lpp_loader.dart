import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:offibox/models/search_result.dart';
import 'package:offibox/data/lpp_index.dart';
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;

/// Charge les résultats LPP depuis le CSV GitHub (même règles que les autres parsers).
/// Format pipeline Apps Script : en-tête "Code LPP;URL;Libellé", séparateur ;, col A=code, B=url, C=libellé.
Future<List<SearchResult>> loadLppResults() async {
  final response = await http.get(Uri.parse(LPP_URL));
  if (response.statusCode != 200) return [];

  final lines = const LineSplitter().convert(response.body);
  final results = <SearchResult>[];

  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 2) continue;

    final code = row[0].replaceAll('"', '').trim();
    final codeDigits = code.replaceAll(RegExp(r'\D'), '');
    if (codeDigits.length != 7) continue;

    final url = row[1].replaceAll('"', '').trim();
    if (url.isEmpty) continue;

    final libelle = row.length > 2
        ? row.sublist(2).join(';').replaceAll('"', '').trim()
        : null;
    final libelleOrEmpty = (libelle != null && libelle.isNotEmpty) ? libelle : null;

    lppIndex[codeDigits] = url;
    results.add(mapper.fromLppCode(
      codeDigits,
      url,
      libelle: libelleOrEmpty,
    ),);
  }

  return results;
}
