import 'package:cloud_firestore/cloud_firestore.dart';

/// Stream DocumentSnapshot for a reference. On Windows, avoids platform-thread issues
/// by not using .snapshots() directly in some contexts; here we use the standard API.
Stream<DocumentSnapshot<Map<String, dynamic>>> documentSnapshotStream(
  DocumentReference<Map<String, dynamic>> ref,
) {
  return ref.snapshots();
}
