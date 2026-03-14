import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../models/search_result.dart';
import 'package:offibox/models/source_type.dart';

import 'offiboxdata_fetch.dart';

const String _kCoEtPharmCommanderUrl = 'https://www.coetpharm.com/';







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
  // ✅ PARSER CERP (CERP.csv — Madouest) : col1=nom, col2=CIP 13 ou 7, col3=URL
  // - Recherche par CIP ou par bloc du nom (libellé)
  // - Badge "page Madouest" (affiché en 2e ligne) → URL col 3
  // ==========================================================================
  Future<List<SearchResult>> parseCerp(String url) async {
    final response = await OffiboxDataFetch.get(url);
    if (response.statusCode != 200) return [];

    final body = response.body.replaceAll('\uFEFF', '').trim();
    final lines = const LineSplitter().convert(body);
    final results = <SearchResult>[];

    for (int i = 1; i < lines.length; i++) {
      final row = lines[i]
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();

      if (row.length < 3) continue;

      final name = row[0].trim();
      final cip = row[1].replaceAll(RegExp(r'\D'), '').trim();
      final link = row[2].trim();

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
          laboratory: 'Madouest',
          badge1Name: 'page Madouest',
          badge1Url: link,
        ),
      );
    }

    return results;
  }

/// ==========================================================================
/// ✅ PARSER CO&PHARM 2026 (CSV : col1=Code CIP, col2=Libellé, col3=URL PDF, col4=URL logo optionnel)
/// - Recherche par CIP13 ou par nom (libellé)
/// - Badge "conditions Co&Pharm" → URL col 3 (clic = ouverture PDF)
/// ==========================================================================
Future<List<SearchResult>> parseCoetpharm2026(String url) async {
  final response = await OffiboxDataFetch.get(url);
  if (response.statusCode != 200) return [];

  final body = response.body.replaceAll('\uFEFF', '').trim();
  final results = <SearchResult>[];
  List<List<dynamic>> rows;
  try {
    rows = const CsvToListConverter().convert(body);
  } catch (_) {
    return results;
  }

  for (int i = 1; i < rows.length; i++) {
    final row = rows[i].map((e) => e.toString().replaceAll('"', '').trim()).toList();
    if (row.length < 3) continue;

    final cip = row[0].replaceAll(RegExp(r'\D'), '').trim();
    final libelle = row[1].trim();
    final pdfUrl = row.length > 2 ? row[2].trim() : '';
    final logoUrl = row.length > 3 ? row[3].trim() : '';

    if (cip.isEmpty || libelle.isEmpty) continue;

    results.add(
      SearchResult(
        source: SourceType.cerp,
        label: libelle,
        labelRaw: libelle.toUpperCase(),
        cip13: cip,
        laboratory: 'Co&Pharm',
        iconUrl: logoUrl.isNotEmpty ? logoUrl : null,
        catalogueUrl: pdfUrl.isNotEmpty ? pdfUrl : null,
        url: pdfUrl.isNotEmpty ? pdfUrl : _kCoEtPharmCommanderUrl,
        badge1Name: 'commande',
        badge1Url: _kCoEtPharmCommanderUrl,
        badge2Name: 'conditions Co&Pharm',
        badge2Url: pdfUrl.isNotEmpty ? pdfUrl : null,
        nsfp: false,
        hospitalOnly: false,
      ),
    );
  }

  return results;
}
