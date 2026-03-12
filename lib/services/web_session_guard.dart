import 'package:cloud_firestore/cloud_firestore.dart';

/// Limite le nombre de connexions web simultanées par utilisateur (ex. 5).
/// Utilise la sous-collection Firestore users/{uid}/web_sessions/{sessionId}.
const int kMaxWebSessions = 5;
const Duration kSessionTimeout = Duration(minutes: 3);

class WebSessionGuard {
  static String? _currentSessionId;

  /// Génère un identifiant de session unique pour cet onglet.
  static String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().hashCode}';
  }

  /// Enregistre la session courante. Si déjà 5 sessions actives, retourne un message d'erreur.
  /// Sinon enregistre cette session et retourne null.
  static Future<String?> tryRegisterSession(String uid) async {
    final sessionId = _generateSessionId();
    final now = DateTime.now();
    final cutoff = now.subtract(kSessionTimeout);

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('web_sessions');

    final snap = await ref.get();
    final active = snap.docs
        .where((d) {
          final t = d.data()['lastSeen'] as Timestamp?;
          return t != null && t.toDate().isAfter(cutoff);
        })
        .toList();

    if (active.length >= kMaxWebSessions) {
      return 'Nombre maximum de connexions simultanées atteint ($kMaxWebSessions). Fermez un autre onglet ou déconnectez-vous ailleurs.';
    }

    _currentSessionId = sessionId;
    await ref.doc(sessionId).set({'lastSeen': Timestamp.fromDate(now)});
    return null;
  }

  /// Met à jour lastSeen pour la session courante (heartbeat). À appeler périodiquement.
  static Future<void> heartbeat(String uid) async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('web_sessions')
        .doc(sessionId)
        .set({'lastSeen': Timestamp.fromDate(DateTime.now())});
  }

  /// Supprime la session courante (à appeler au déchargement de la page si possible).
  static Future<void> unregisterSession(String uid) async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('web_sessions')
        .doc(sessionId)
        .delete();
    _currentSessionId = null;
  }
}
