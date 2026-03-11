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

    // Cas historique : flag explicite posé par l'app (ancien OnboardingPage).
    if (data['onboardingDone'] == true) return true;

    // Cas inscription via site web (inscription.html / validation.html) :
    // on considère que l'onboarding est terminé dès qu'une fiche complète
    // a été créée côté Firestore (prénom / nom / officine ou date
    // d'activation d'abonnement).
    final firstName = (data['firstName'] as String?)?.trim();
    final lastName = (data['lastName'] as String?)?.trim();
    final pharmacyName = (data['pharmacyName'] as String?)?.trim();
    final hasProfile =
        (firstName != null && firstName.isNotEmpty) ||
        (lastName != null && lastName.isNotEmpty) ||
        (pharmacyName != null && pharmacyName.isNotEmpty);

    final hasSubscriptionStarted = data['subscriptionStartedAt'] != null;

    return hasProfile || hasSubscriptionStarted;
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

  /// Retourne la date de fin de licence à afficher (« licence jusqu'au DD/MM/YYYY »).
  /// Pour plan 'pro' : null (pas d'affichage ou « licence illimitée » selon choix).
  /// Pour trial : trialEndsAt.
  static Future<DateTime?> getLicenseEndDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final data = await getUserDocCached(user.uid);
    if (data == null) return null;

    if (data['plan'] == 'pro') return null;

    final trialEndsAt = data['trialEndsAt'] as Timestamp?;
    if (trialEndsAt == null) return null;

    return trialEndsAt.toDate();
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
