import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/offiboxdata_fetch.dart';

/// Entrée CIP13 → libellé (colonne E) et dosage (colonne C) du CSV BDM_CIP_QUANTITE.
/// Source : https://github.com/AlexandrePerrault/offiboxdata/blob/main/BDM_CIP_QUANTITE.csv
class BdmLibelleEntry {
  const BdmLibelleEntry({required this.libelle, required this.dosage});
  final String libelle;
  final String dosage;
}

/// Cache global des libellés BDM (colonne E de BDM_CIP_QUANTITE.csv).
/// Rempli au démarrage ; utilisé pour afficher le libellé en ligne 1 des résultats médicaments.
class BdmLibelleCache {
  BdmLibelleCache._();
  static final BdmLibelleCache _instance = BdmLibelleCache._();
  static BdmLibelleCache get instance => _instance;

  Map<String, BdmLibelleEntry> _cipToLibelle = {};
  bool _loaded = false;

  Map<String, BdmLibelleEntry> get cipToLibelle => _cipToLibelle;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final response = await OffiboxDataFetch.get(BDM_CIP_QUANTITE_URL);
      if (response.statusCode != 200) return;

      String decoded;
      try {
        decoded = utf8.decode(response.bodyBytes);
      } catch (_) {
        decoded = latin1.decode(response.bodyBytes);
      }

      _cipToLibelle = await compute(_parseSync, decoded);
      _loaded = true;
    } catch (_) {
      // fail soft
    }
  }

  static Map<String, BdmLibelleEntry> _parseSync(String raw) {
    final result = <String, BdmLibelleEntry>{};
    final lines = const LineSplitter().convert(raw);

    for (final line in lines.skip(1)) {
      final row = _parseCsvLine(line);
      if (row.length < 5) continue;

      final cip13 = row[0].replaceAll(RegExp(r'\D'), '');
      if (cip13.length != 13) continue;

      final libelle = row[4].replaceAll('"', '').trim();
      final dosage = row[2].replaceAll('"', '').trim();

      if (libelle.isNotEmpty) {
        result[cip13] = BdmLibelleEntry(libelle: libelle, dosage: dosage);
      }
    }
    return result;
  }

  /// Parse une ligne CSV avec séparateur ; et champs entre guillemets.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        final end = line.indexOf('"', i + 1);
        if (end == -1) {
          result.add(line.substring(i + 1).replaceAll('"', ''));
          break;
        }
        result.add(line.substring(i + 1, end));
        i = end + 1;
        if (i < line.length && line[i] == ';') i++;
      } else {
        final end = line.indexOf(';', i);
        if (end == -1) {
          result.add(line.substring(i).trim());
          break;
        }
        result.add(line.substring(i, end).trim());
        i = end + 1;
      }
    }
    return result;
  }

  BdmLibelleEntry? get(String? cip13) {
    if (cip13 == null) return null;
    final clean = cip13.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 13) return null;
    return _cipToLibelle[clean];
  }
}
