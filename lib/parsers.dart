import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// ─────────────────────────────────────────────
/// MODELS
/// ─────────────────────────────────────────────

class BdmItem {
  final String label;
  final String cip;
  final String url;
  final bool alert;

  BdmItem({
    required this.label,
    required this.cip,
    required this.url,
    required this.alert,
  });
}

class PansementItem {
  final String label;
  final String cip;

  PansementItem({required this.label, required this.cip});
}

class VetoItem {
  final String label;
  final String cip;

  VetoItem({required this.label, required this.cip});
}

/// ─────────────────────────────────────────────
/// CORE LOADER
/// ─────────────────────────────────────────────

Future<List<List<String>>> loadCsvFromUrl(String url) async {
  final res = await http.get(Uri.parse(url));

  if (res.statusCode != 200) {
    throw Exception('Erreur HTTP $url');
  }

  final text = utf8.decode(res.bodyBytes).replaceAll('\uFEFF', '');

  final rows = const CsvToListConverter(
    fieldDelimiter: ';',
    shouldParseNumbers: false,
  ).convert(text);

  debugPrint('→ lignes parsées: ${rows.length}');
  return rows.map((r) => r.map((c) => c.toString()).toList()).toList();
}

/// ─────────────────────────────────────────────
/// PARSE BDM
/// ─────────────────────────────────────────────

Future<List<BdmItem>> parseBDM(String url) async {
  final rows = await loadCsvFromUrl(url);
  final result = <BdmItem>[];

  for (final row in rows) {
    if (row.length < 5) continue;

    final label = row[0].trim();
    final cip = row[1].trim();
    final link = row[4].trim();

    if (label.isEmpty || cip.isEmpty) continue;

    final isAlert = row.length > 18 && row[18].trim().toLowerCase() == 'oui';

    result.add(BdmItem(
      label: label,
      cip: cip,
      url: link,
      alert: isAlert,
    ),);
  }

  return result;
}

/// ─────────────────────────────────────────────
/// PARSE PANSEMENTS
/// ─────────────────────────────────────────────

Future<List<PansementItem>> parsePansements(String url) async {
  final rows = await loadCsvFromUrl(url);
  final result = <PansementItem>[];

  for (final row in rows) {
    if (row.length < 2) continue;

    final label = row[0].trim();
    final cip = row[1].trim();

    if (label.isEmpty || cip.isEmpty) continue;

    result.add(PansementItem(label: label, cip: cip));
  }

  return result;
}

/// ─────────────────────────────────────────────
/// PARSE VETO
/// ─────────────────────────────────────────────

Future<List<VetoItem>> parseVeto(String url) async {
  final rows = await loadCsvFromUrl(url);
  final result = <VetoItem>[];

  for (final row in rows) {
    if (row.length < 2) continue;

    final label = row[0].trim();
    final cip = row[1].trim();

    if (label.isEmpty || cip.isEmpty) continue;

    result.add(VetoItem(label: label, cip: cip));
  }

  return result;
}
