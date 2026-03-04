import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:offibox/services/firestore_user_cache.dart';

class CerpClientService {
  /// Enregistre (email, flag CERP BA, code client) dans users/{uid}.
  /// Si [isCerpBaClient] est false, le code est effacé.
  static Future<void> upsertForCurrentUser({
    required bool isCerpBaClient,
    required String cerpBaClientCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'email': user.email,
        'cerpBaClient': isCerpBaClient,
        'cerpBaClientCode': isCerpBaClient ? cerpBaClientCode.trim() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    FirestoreUserCache.instance.invalidate(user.uid);
  }
  static Future<bool> isCurrentUserCerpBaValidated() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final data = await getUserDocCached(user.uid);
    final flag = (data?['cerpBaClient'] as bool?) ?? false;
    final code = (data?['cerpBaClientCode'] as String?)?.trim() ?? '';
    return flag && code.isNotEmpty;
  }
}
