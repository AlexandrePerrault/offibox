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

/// API FHIR Annuaire Santé (plus rapide que data.gouv.fr).
const String _kFhirAnnuaireBase =
    'https://gateway.api.esante.gouv.fr/fhir/v2';

String _apiKey() =>
    const String.fromEnvironment('ESANTE_API_KEY', defaultValue: '');

/// Récupère le nombre de professionnels de santé (Annuaire PS) via l'API FHIR
/// (interop.esante.gouv.fr/ig/fhir/annuaire). Recalcule au plus une fois par mois ;
/// entre deux recalculs retourne le cache. En échec API ou réseau : conserve la dernière
/// valeur en cache, sinon [kAnnuairePsTotalHorsAppli].
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
    count = await _fetchCountFromFhir();
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

/// Appel API FHIR : GET Practitioner?_count=1 → Bundle.total.
Future<int> _fetchCountFromFhir() async {
  final key = _apiKey();
  if (key.isEmpty) return 0;

  final uri = Uri.parse('$_kFhirAnnuaireBase/Practitioner').replace(
    queryParameters: {'_count': '1', 'active': 'true'},
  );
  final res = await http.get(
    uri,
    headers: {
      'ESANTE-API-KEY': key,
      'Accept': 'application/fhir+json',
    },
  );
  if (res.statusCode != 200) return 0;

  final json = jsonDecode(res.body) as Map<String, dynamic>?;
  if (json == null || json['resourceType'] != 'Bundle') return 0;

  final total = json['total'];
  if (total is int && total > 0) return total;
  return 0;
}
