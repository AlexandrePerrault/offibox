import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';

/// Élément affiché dans la barre d’info : arrêt de commercialisation (NSFP) pendant 7 jours.
class NsfpAlertItem {
  const NsfpAlertItem({required this.label, required this.date});
  final String label;
  final String date; // jj/mm/aaaa
}

const String _prefsKey = 'nsfp_alerts';
const int _displayDays = 7;

/// Détecte les médicaments NSFP (arrêt de commercialisation) et garde en mémoire
/// ceux à afficher pendant 7 jours dans la barre d’info.
class NsfpAlertService {
  /// Met à jour la liste persistée à partir des résultats BDM, puis retourne
  /// les alertes à afficher (date d’arrêt dans les 7 derniers jours).
  static Future<List<NsfpAlertItem>> updateFromResults(
    List<SearchResult> allResults,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: _displayDays));

    final nsfpItems = allResults
        .where((r) =>
            r.source == SourceType.bdm &&
            r.isNsfpEffective == true &&
            r.cip13 != null &&
            r.cip13!.length == 13,)
        .toList();

    List<Map<String, String>> stored = [];
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>?;
        if (decoded != null) {
          stored = decoded
              .map((e) => Map<String, String>.from(e as Map))
              .where((m) =>
                  m['cip13'] != null &&
                  m['date'] != null &&
                  _parseStoredDate(m['date']!).isAfter(cutoff),)
              .toList();
        }
      }
    } catch (_) {}

    final byCip = <String, Map<String, String>>{
      for (final e in stored) e['cip13']!: e,
    };

    final todayStr = _toStorageDate(now);
    for (final r in nsfpItems) {
      final cip = r.cip13!;
      final existing = byCip[cip];
      final label = _shortLabel(r.label);
      if (existing == null) {
        byCip[cip] = {
          'cip13': cip,
          'label': label,
          'date': todayStr,
        };
      }
      // Si déjà présent, on garde la date de première détection (ne pas mettre à jour)
    }

    final toStore = byCip.values
        .where((m) => _parseStoredDate(m['date']!).isAfter(cutoff),)
        .toList();
    await prefs.setString(_prefsKey, jsonEncode(toStore));

    return toStore
        .map((m) => NsfpAlertItem(
              label: m['label'] ?? '',
              date: _storageToDisplayDate(m['date']!),
            ),)
        .toList();
  }

  static String _shortLabel(String label) {
    const maxLen = 80;
    final t = label.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen)}…';
  }

  static String _toStorageDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseStoredDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return DateTime(2000);
    final y = int.tryParse(parts[0]) ?? 2000;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    return DateTime(y, m, d);
  }

  static String _storageToDisplayDate(String storage) {
    final d = _parseStoredDate(storage);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
