import 'package:cloud_firestore/cloud_firestore.dart';

/// Heure serveur : lecture seule du doc _server/time (pas d'écriture côté client).
/// Réduit les coûts Firestore (1 lecture au lieu de 1 écriture + 1 lecture).
/// Le doc peut être mis à jour par une Cloud Function planifiée si besoin.
class ServerTimeService {
  static Future<DateTime> getServerTime() async {
    final docRef = FirebaseFirestore.instance
        .collection('_server')
        .doc('time');

    final snapshot = await docRef.get();

    if (!snapshot.exists) return DateTime.now();

    final data = snapshot.data();
    final ts = data?['timestamp'] as Timestamp?;
    if (ts == null) return DateTime.now();

    return ts.toDate();
  }
}
