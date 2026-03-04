import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/services/firestore_user_cache.dart';

/// Clé préférence : dernier enregistrement lastSeenAt (timestamp ms) pour debounce.
const String _kLastSeenAtWriteKeyPrefix = 'device_guard_last_seen_';

/// Enregistrement des appareils : requêtes ciblées, cache user doc, debounce lastSeenAt (max 1 écriture / 24h).
class DeviceGuard {
  /// Cache session : (uid, deviceId) → déjà enregistré (évite de relire devices à chaque appel).
  static final Map<String, bool> _deviceRegisteredCache = {};

  /// Vérifie et enregistre l'appareil. Utilise le cache user doc et debounce lastSeenAt.
  static Future<void> checkAndRegisterDevice({
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final userData = await getUserDocCached(user.uid);
    final maxDevices = userData?['maxDevices'] ?? 5;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final devicesRef = userRef.collection('devices');

    final cacheKey = '${user.uid}|$deviceId';
    bool? alreadyRegistered = _deviceRegisteredCache[cacheKey];

    if (alreadyRegistered == null) {
      final devicesSnap =
          await devicesRef.where('active', isEqualTo: true).get();
      alreadyRegistered =
          devicesSnap.docs.any((d) => d.id == deviceId);
      _deviceRegisteredCache[cacheKey] = alreadyRegistered;

      if (!alreadyRegistered &&
          devicesSnap.docs.length >= maxDevices) {
        throw Exception('LIMIT_EXCEEDED');
      }
    }

    final isRegistered = alreadyRegistered == true;
    if (!isRegistered) {
      await devicesRef.doc(deviceId).set({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': 'windows',
        'appVersion': appVersion,
        'active': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'firstSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
      await _markLastSeenAtWritten(user.uid, deviceId);
      return;
    }

    if (!await _shouldWriteLastSeenAt(user.uid, deviceId)) return;

    await devicesRef.doc(deviceId).set({
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true),);
    await _markLastSeenAtWritten(user.uid, deviceId);
  }

  static Future<bool> _shouldWriteLastSeenAt(String uid, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kLastSeenAtWriteKeyPrefix${uid}_$deviceId';
    final last = prefs.getInt(key);
    if (last == null) return true;
    const debounce = Duration(hours: 24);
    return DateTime.now().millisecondsSinceEpoch - last > debounce.inMilliseconds;
  }

  static Future<void> _markLastSeenAtWritten(String uid, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kLastSeenAtWriteKeyPrefix${uid}_$deviceId';
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }
}
