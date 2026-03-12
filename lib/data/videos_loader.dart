import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data_sources.dart';
import 'offiboxdata_fetch.dart';

/// Charge le CSV videos (col B = CIP13, col C = URL). Retourne CIP13 normalisé (chiffres seulement) → URL.
Future<Map<String, String>> loadVideosByCip13() async {
  final map = <String, String>{};
  try {
    final response = await OffiboxDataFetch.get(VIDEOS_CSV_URL);
    if (response.statusCode != 200) {
      if (kDebugMode) debugPrint('[Offibox] Vidéos non disponibles (HTTP ${response.statusCode})');
      return map;
    }
    final lines = const LineSplitter().convert(response.body);
    // Ligne 0 = en-tête ; col B = index 1, col C = index 2 (séparateur ;)
    for (final line in lines.skip(1)) {
      final row = line
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
      if (row.length >= 3) {
        final cip13 = row[1].replaceAll(RegExp(r'\D'), '');
        final url = row[2];
        if (cip13.isNotEmpty && url.isNotEmpty) {
          map[cip13] = url;
        }
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] Vidéos erreur: $e');
  }
  return map;
}
