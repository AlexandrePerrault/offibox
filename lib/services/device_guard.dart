import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceGuard {
  static Future<void> checkAndRegisterDevice({
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final devicesRef = userRef.collection('devices');

    final userSnap = await userRef.get();
    final maxDevices = userSnap.data()?['maxDevices'] ?? 5;

    final devicesSnap =
        await devicesRef.where('active', isEqualTo: true).get();

    final alreadyRegistered = devicesSnap.docs
        .any((d) => d.id == deviceId);

    if (!alreadyRegistered &&
        devicesSnap.docs.length >= maxDevices) {
      throw Exception('LIMIT_EXCEEDED');
    }

    await devicesRef.doc(deviceId).set({
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': 'windows',
      'appVersion': appVersion,
      'active': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'firstSeenAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true),);
  }
}
