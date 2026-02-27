import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrialGuard {
  static const _adminEmails = ['offibox@gmail.com', 'offibox17@gmail.com'];

  /// Vérifie si onboarding est terminé
  static Future<bool> isOnboardingDone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data();
    return data?['onboardingDone'] == true;
  }

  /// Vérifie si la période d’essai est expirée
  static Future<bool> isTrialExpired() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    if (user.email != null &&
        _adminEmails.contains(user.email!.toLowerCase())) {
      return false;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return true;

    final data = doc.data();

    final plan = data?['plan'];
    if (plan == 'pro') return false;

    final trialEndsAt = data?['trialEndsAt'] as Timestamp?;
    if (trialEndsAt == null) return true;

    return trialEndsAt.toDate().isBefore(DateTime.now());
  }
}
