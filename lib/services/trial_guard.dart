import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:offibox/services/firestore_user_cache.dart';

class TrialGuard {
  static const _adminEmails = ['offibox@gmail.com', 'offibox17@gmail.com'];

  /// Vérifie si onboarding est terminé (lecture via cache partagé).
  static Future<bool> isOnboardingDone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final data = await getUserDocCached(user.uid);
    if (data == null) return false;

    return data['onboardingDone'] == true;
  }

  /// Vérifie si la période d'essai est expirée (lecture via cache partagé).
  static Future<bool> isTrialExpired() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    if (user.email != null &&
        _adminEmails.contains(user.email!.toLowerCase())) {
      return false;
    }

    final data = await getUserDocCached(user.uid);
    if (data == null) return true;

    final plan = data['plan'];
    if (plan == 'pro') return false;

    final trialEndsAt = data['trialEndsAt'] as Timestamp?;
    if (trialEndsAt == null) return true;

    return trialEndsAt.toDate().isBefore(DateTime.now());
  }

  /// Démarre la période de 15 jours à la première connexion (web ou app).
  /// Si le document users/{uid} n'existe pas ou n'a pas trialEndsAt, on le crée/met à jour.
  /// À appeler après toute connexion réussie (Google ou e-mail).
  static Future<void> ensureTrialStartedOnFirstConnection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await getUserDocCached(user.uid);
    final hasTrial = data != null && data['trialEndsAt'] != null;
    if (hasTrial) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
        'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
        'plan': 'trial',
      },
      SetOptions(merge: true),
    );
    FirestoreUserCache.instance.invalidate(user.uid);
  }
}
