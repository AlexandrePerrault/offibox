import 'package:cloud_firestore/cloud_firestore.dart';

/// Cache en mémoire pour le document Firestore users/{uid}.
/// Réduit les lectures répétées (trial, onboarding, trialEndsAt) dans la même session.
class FirestoreUserCache {
  FirestoreUserCache._();
  static final FirestoreUserCache instance = FirestoreUserCache._();

  static const Duration ttl = Duration(minutes: 2);

  final Map<String, _Entry> _cache = {};

  /// Données utilisateur en cache (null si pas en cache ou expiré).
  Map<String, dynamic>? getCached(String uid) {
    final entry = _cache[uid];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _cache.remove(uid);
      return null;
    }
    return entry.data;
  }

  void setCached(String uid, Map<String, dynamic>? data) {
    _cache[uid] = _Entry(data: data, at: DateTime.now());
  }

  void invalidate(String uid) {
    _cache.remove(uid);
  }

  void invalidateAll() {
    _cache.clear();
  }
}

class _Entry {
  _Entry({this.data, required DateTime at}) : at = at;
  final Map<String, dynamic>? data;
  final DateTime at;
}

/// Récupère users/{uid} depuis le cache ou Firestore (une seule lecture partagée).
Future<Map<String, dynamic>?> getUserDocCached(String uid) async {
  final cached = FirestoreUserCache.instance.getCached(uid);
  if (cached != null) return cached;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final data = doc.exists ? doc.data() : null;
  FirestoreUserCache.instance.setCached(uid, data);
  return data;
}
