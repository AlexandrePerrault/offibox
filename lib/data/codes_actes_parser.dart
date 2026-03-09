import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

/// CSV codes actes pharmacie : Col 0 = Code Acte, Col 1 = Libellé, Col 2 = Tarif. Séparateur ;, guillemets.
Future<List<SearchResult>> parseCodesActesPharmacie(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return [];

  final lines = const LineSplitter().convert(response.body);
  if (lines.length <= 1) return [];

  final results = <SearchResult>[];

  String cellAt(List<String> row, int i) {
    if (i >= row.length) return '';
    final s = row[i].trim();
    if (s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1).replaceAll('""', '"').trim();
    }
    return s.replaceAll('"', '').trim();
  }

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final row = _parseCsvLine(trimmed, ';');
    final codeActe = cellAt(row, 0);
    final libelle = cellAt(row, 1);
    final tarif = cellAt(row, 2);

    if (codeActe.isEmpty && libelle.isEmpty) continue;

    final codeNorm = normalizeText(codeActe);
    final libelleNorm = normalizeText(libelle);
    final searchRaw = '$codeNorm $libelleNorm'.trim();
    if (searchRaw.isEmpty) continue;

    final displayLabel = [codeActe.trim(), libelle.trim(), if (tarif.isNotEmpty) tarif.trim()].join(' — ');

    results.add(SearchResult(
      source: SourceType.codesActes,
      labelRaw: searchRaw.toUpperCase(),
      label: displayLabel,
      laboratory: tarif.trim(),
      commentaire: tarif.trim(),
      cip13: null,
      cis: null,
      url: null,
      nsfp: false,
      hospitalOnly: false,
    ),);
  }

  return results;
}

List<String> _parseCsvLine(String line, String sep) {
  final row = <String>[];
  int i = 0;
  while (i < line.length) {
    if (line[i] == '"') {
      final end = line.indexOf('"', i + 1);
      if (end == -1) {
        row.add(line.substring(i + 1).replaceAll('""', '"'));
        break;
      }
      row.add(line.substring(i + 1, end).replaceAll('""', '"'));
      i = end + 1;
      if (i < line.length && line[i] == sep) i++;
    } else {
      final end = line.indexOf(sep, i);
      if (end == -1) {
        row.add(line.substring(i).replaceAll('"', ''));
        break;
      }
      row.add(line.substring(i, end).replaceAll('"', ''));
      i = end + 1;
    }
  }
  return row;
}
