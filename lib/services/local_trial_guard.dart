import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/utils/device_id.dart';

/// Garde d'essai local (sans authentification).
/// Utilise quand [AppConfig.trialNoAuth] est true : pas de login, 15 jours a partir du premier lancement.
/// La date de fin est validée côté serveur pour éviter le contournement par modification de l'horloge.
class LocalTrialGuard {
  LocalTrialGuard._();

  static const String _keyFirstLaunchMs = 'local_trial_first_launch_ms';
  static const int _trialDays = 15;

  /// Enregistre le premier lancement si pas encore fait (fallback local).
  static Future<void> ensureFirstLaunchRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyFirstLaunchMs)) return;
    await prefs.setInt(
      _keyFirstLaunchMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Vérifie le trial via le serveur (date fiable). Fallback local si hors ligne.
  /// Retourne (expired, endDate).
  static Future<({bool expired, DateTime? endDate})> checkTrialStatus() async {
    await ensureFirstLaunchRecorded();

    try {
      final deviceId = await getDeviceId();
      final callable =
          FirebaseFunctions.instance.httpsCallable('checkTrialNoAuth');
      final result = await callable.call<Map<String, dynamic>>({
        'deviceId': deviceId,
      });

      final data = result.data;
      if (data != null) {
        final valid = data['valid'] as bool? ?? false;
        final trialEndsAtStr = data['trialEndsAt'] as String?;
        DateTime? endDate;
        if (trialEndsAtStr != null) {
          endDate = DateTime.tryParse(trialEndsAtStr);
        }
        return (expired: !valid, endDate: endDate);
      }
    } catch (_) {
      // Hors ligne ou erreur : fallback sur la vérification locale
    }

    final expired = await _isExpiredLocal();
    final endDate = await _getEndDateLocal();
    return (expired: expired, endDate: endDate);
  }

  static Future<bool> _isExpiredLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyFirstLaunchMs);
    if (ms == null) return false;
    final firstLaunch = DateTime.fromMillisecondsSinceEpoch(ms);
    final endDate = firstLaunch.add(const Duration(days: _trialDays));
    return DateTime.now().isAfter(endDate);
  }

  static Future<DateTime?> _getEndDateLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyFirstLaunchMs);
    if (ms == null) return null;
    final firstLaunch = DateTime.fromMillisecondsSinceEpoch(ms);
    return firstLaunch.add(const Duration(days: _trialDays));
  }

  /// Verifie si la periode de 15 jours est expiree (serveur prioritaire, fallback local).
  static Future<bool> isExpired() async {
    final status = await checkTrialStatus();
    return status.expired;
  }

  /// Date de fin de l'essai (pour affichage).
  static Future<DateTime?> getEndDate() async {
    final status = await checkTrialStatus();
    return status.endDate;
  }

  /// Nombre de jours restants (0 si expire).
  static Future<int> getDaysRemaining() async {
    final end = await getEndDate();
    if (end == null) return _trialDays;
    final now = DateTime.now();
    if (now.isAfter(end)) return 0;
    return end.difference(now).inDays;
  }
}
