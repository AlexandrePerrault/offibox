import 'package:cloud_firestore/cloud_firestore.dart';

class ServerTimeService {

  static Future<DateTime> getServerTime() async {
    final docRef = FirebaseFirestore.instance
        .collection('_server')
        .doc('time');

    await docRef.set({
      'timestamp': FieldValue.serverTimestamp(),
    });

    final snapshot = await docRef.get();

    final Timestamp ts = snapshot.data()!['timestamp'];

    return ts.toDate();
  }
}
