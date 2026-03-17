import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:csv/csv.dart';
import 'package:offibox/data/data_sources.dart';

/// Service BAL MSSanté (personnelle) pour enrichir les hits RPPS.
/// Charge le CSV RPPS→email depuis offiboxdata (pipeline annuaire_mssante_pipeline).
class AnnuaireSanteMssanteService {
  AnnuaireSanteMssanteService();

  Map<String, String>? _rppsToEmail;

  /// Retourne la map RPPS → email pour les RPPS demandés.
  /// Le CSV est chargé une fois puis mis en cache.
  Future<Map<String, String>> fetchPreferredPersonalByRppsList(
    List<String> rppsList,
  ) async {
    if (rppsList.isEmpty) return {};
    final wanted = rppsList.toSet();
    try {
      _rppsToEmail ??= await _loadMssanteCsv();
      if (_rppsToEmail == null || _rppsToEmail!.isEmpty) return {};
      final out = <String, String>{};
      for (final rpps in wanted) {
        final email = _rppsToEmail![rpps];
        if (email != null && email.isNotEmpty) {
          out[rpps] = email;
        }
      }
      return out;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Offibox] MSSanté CSV: $e');
        debugPrint(st.toString());
      }
      return {};
    }
  }

  Future<Map<String, String>?> _loadMssanteCsv() async {
    final res = await http.get(Uri.parse(ANNUAIRE_MSSANTE_CSV_URL));
    if (res.statusCode != 200) return null;
    final text = utf8
        .decode(res.bodyBytes)
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final parsed = const CsvToListConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    if (parsed.isEmpty || parsed.length < 2) return null;
    final header = (parsed[0] as List).map((c) => c.toString().toLowerCase()).toList();
    final idxRpps = header.indexOf('rpps');
    final idxEmail = header.indexOf('email');
    if (idxRpps < 0 || idxEmail < 0) return null;
    final map = <String, String>{};
    for (var i = 1; i < parsed.length; i++) {
      final row = parsed[i] as List;
      if (row.length <= idxRpps || row.length <= idxEmail) continue;
      final rpps = (row[idxRpps]?.toString() ?? '').trim();
      final email = (row[idxEmail]?.toString() ?? '').trim();
      if (rpps.isEmpty || email.isEmpty || !email.contains('@')) continue;
      map[rpps] = email;
    }
    return map;
  }

  void dispose() {
    _rppsToEmail = null;
  }
}
