import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:offibox/services/firestore_user_cache.dart';

/// Clé Firestore dans users/{uid} pour le groupe cahier de liaison (même valeur que le segment de chemin).
const String kPharmacyNameNormalizedKey = 'pharmacyNameNormalized';

/// Cahier de liaison partagé par officine (même pharmacie = même groupe).
/// Données en temps réel via Firestore ; tous les postes connectés avec le même
/// nom d'officine voient les mêmes entrées.
class CahierLiaisonService {
  CahierLiaisonService._();
  static final CahierLiaisonService instance = CahierLiaisonService._();

  static const String _collectionId = 'cahier_liaison';
  static const String _entriesSubcollection = 'entries';

  /// Normalise le nom de pharmacie en clé de groupe (slug).
  static String normalizePharmacyName(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final t = name.trim().toLowerCase();
    final withoutAccents = t
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ç', 'c');
    final slug = withoutAccents.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return slug;
  }

  /// Retourne le groupId pour l'utilisateur courant (basé sur pharmacyName), ou null si non défini.
  /// Met à jour users/{uid} avec pharmacyNameNormalized pour les règles Firestore.
  Future<String?> getGroupIdForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final data = await getUserDocCached(user.uid);
    final pharmacyName = (data?['pharmacyName'] as String?)?.trim();
    final groupId = normalizePharmacyName(pharmacyName);
    if (groupId.isEmpty) return null;

    final existing = (data?[kPharmacyNameNormalizedKey] as String?)?.trim();
    if (existing != groupId) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {kPharmacyNameNormalizedKey: groupId, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      FirestoreUserCache.instance.invalidate(user.uid);
    }
    return groupId;
  }

  /// Flux des entrées du cahier pour le groupe de l'utilisateur (ordre anti-chronologique).
  Stream<List<CahierEntry>> streamEntries(String groupId) {
    if (groupId.isEmpty) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection(_collectionId)
        .doc(groupId)
        .collection(_entriesSubcollection)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CahierEntry.fromFirestore(d)).toList());
  }

  /// Ajoute une entrée au cahier du groupe.
  Future<void> addEntry({
    required String groupId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || groupId.isEmpty) return;

    final data = await getUserDocCached(user.uid);
    final authorName = _authorDisplayName(data, user);

    final col = FirebaseFirestore.instance
        .collection(_collectionId)
        .doc(groupId)
        .collection(_entriesSubcollection);

    await col.add({
      'authorUid': user.uid,
      'authorName': authorName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _authorDisplayName(Map<String, dynamic>? data, User user) {
    final first = (data?['firstName'] as String?)?.trim();
    final last = (data?['lastName'] as String?)?.trim();
    if (first != null && last != null && first.isNotEmpty && last.isNotEmpty) {
      return '$first $last';
    }
    if (first != null && first.isNotEmpty) return first;
    if (last != null && last.isNotEmpty) return last;
    final email = user.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Utilisateur';
  }
}

/// Une entrée du cahier de liaison.
class CahierEntry {
  const CahierEntry({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  static CahierEntry fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'] as Timestamp?;
    return CahierEntry(
      id: doc.id,
      authorUid: (d['authorUid'] as String?) ?? '',
      authorName: (d['authorName'] as String?) ?? 'Anonyme',
      text: (d['text'] as String?) ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }
}
