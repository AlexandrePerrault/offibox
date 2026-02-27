import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:offibox/auth/onboarding_page.dart';
import 'package:offibox/auth/trial_expired_page.dart';
import 'package:offibox/services/trial_guard.dart';
import 'package:offibox/ui/widgets/debug_banner.dart';
import 'package:offibox/window/offibox_window.dart';

class FirstLaunchCheck extends StatelessWidget {
  const FirstLaunchCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const DebugBanner(
        label: 'FirstLaunchCheck: user null',
        child: Scaffold(
          backgroundColor: Color(0xFFE8F0F1),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 🔒 Étape 1 — Vérification licence via Cloud Function
    return FutureBuilder<bool>(
      future: TrialGuard.isTrialExpired(),
      builder: (context, trialSnapshot) {
        String debugLabel;
        Widget content;

        if (trialSnapshot.connectionState == ConnectionState.waiting) {
          debugLabel = 'FirstLaunchCheck: waiting trial';
          content = const Scaffold(
            backgroundColor: Color(0xFFE8F0F1),
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          final expired = trialSnapshot.data ?? true;
          if (expired) {
            debugLabel = 'FirstLaunchCheck: TrialExpiredPage';
            content = const TrialExpiredPage();
          } else {
            // 🔐 Étape 2 — Vérifier si onboarding nécessaire
            return FutureBuilder<bool>(
              future: TrialGuard.isOnboardingDone(),
              builder: (context, onboardingSnapshot) {
                if (onboardingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const DebugBanner(
                    label: 'FirstLaunchCheck: waiting onboarding',
                    child: Scaffold(
                      backgroundColor: Color(0xFFE8F0F1),
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final onboardingDone =
                    onboardingSnapshot.data ?? false;

                if (!onboardingDone) {
                  return const DebugBanner(
                    label: 'FirstLaunchCheck: OnboardingPage',
                    child: OnboardingPage(),
                  );
                }

                return const DebugBanner(
                  label: 'FirstLaunchCheck: OffiboxWindow',
                  child: OffiboxWindow(),
                );
              },
            );
          }
        }

        return DebugBanner(label: debugLabel, child: content);
      },
    );
  }
}
