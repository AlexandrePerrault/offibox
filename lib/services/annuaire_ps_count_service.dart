import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/generated/annuaire_ps_count.dart';

/// Clé préférences : nombre de professionnels (Annuaire PS) en cache.
const String _kPrefsCount = 'offibox_annuaire_ps_count';
/// Clé préférences : date du dernier recalcul (ISO 8601, ex. 2026-03-12).
const String _kPrefsDate = 'offibox_annuaire_ps_count_date';

/// Durée de validité du cache : 1 mois (30 jours). Recalcul après ce délai.
const int _kCacheValidityDays = 30;

const String _datasetSlug =
    'annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante';
const String _apiBase = 'https://www.data.gouv.fr/api/1';

/// Récupère le nombre de professionnels de santé (Annuaire PS, data.gouv.fr).
/// Recalcule au plus une fois par mois ; entre deux recalculs retourne le cache.
/// En échec API ou réseau : conserve la dernière valeur en cache, sinon [kAnnuairePsTotalHorsAppli].
Future<int> getAnnuairePsCount() async {
  final prefs = await SharedPreferences.getInstance();
  final savedDate = prefs.getString(_kPrefsDate);
  final savedCount = prefs.getInt(_kPrefsCount);

  if (savedDate != null && savedCount != null && savedCount > 0) {
    final cached = DateTime.tryParse(savedDate);
    if (cached != null) {
      final now = DateTime.now();
      final diff = now.difference(cached).inDays;
      if (diff < _kCacheValidityDays) {
        return savedCount;
      }
    }
  }

  int count = 0;
  try {
    count = await _fetchCountFromApi();
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] Annuaire PS count API: $e');
  }

  if (count <= 0 && savedCount != null && savedCount > 0) {
    return savedCount;
  }
  if (count <= 0) {
    return kAnnuairePsTotalHorsAppli;
  }

  await prefs.setInt(_kPrefsCount, count);
  await prefs.setString(_kPrefsDate, DateTime.now().toIso8601String());
  return count;
}

/// Appel API data.gouv.fr : dataset par slug puis extras.total_professionnels ou total_ps.
Future<int> _fetchCountFromApi() async {
  final listUri = Uri.parse('$_apiBase/datasets/').replace(
    queryParameters: {'slug': _datasetSlug},
  );
  final listRes = await http.get(
    listUri,
    headers: {'User-Agent': 'Offibox/1.0'},
  );
  if (listRes.statusCode != 200) return 0;

  final listJson = jsonDecode(listRes.body) as Map<String, dynamic>;
  final data = listJson['data'] as List<dynamic>?;
  if (data == null || data.isEmpty) return 0;

  final datasetId = (data.first as Map<String, dynamic>)['id'] as String?;
  if (datasetId == null) return 0;

  final datasetUri = Uri.parse('$_apiBase/datasets/$datasetId/');
  final dsRes = await http.get(
    datasetUri,
    headers: {'User-Agent': 'Offibox/1.0'},
  );
  if (dsRes.statusCode != 200) return 0;

  final dsJson = jsonDecode(dsRes.body) as Map<String, dynamic>;
  final extras = dsJson['extras'] as Map<String, dynamic>?;
  if (extras != null) {
    final total = extras['total_professionnels'] as int?;
    if (total != null && total > 0) return total;
    final totalPs = extras['total_ps'] as int?;
    if (totalPs != null && totalPs > 0) return totalPs;
  }
  return 0;
}
