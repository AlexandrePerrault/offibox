import 'package:flutter/material.dart';

import 'package:offibox/auth/trial_expired_page_no_auth.dart';
import 'package:offibox/services/local_trial_guard.dart';
import 'package:offibox/window/offibox_window.dart';
import 'package:offibox/window/windows_preload_wrapper.dart';

class LocalTrialGate extends StatelessWidget {
  const LocalTrialGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: LocalTrialGuard.isExpired(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE8F0F1),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final expired = snapshot.data ?? false;
        if (expired) {
          return const TrialExpiredPageNoAuth();
        }
        return const WindowsPreloadWrapper(child: OffiboxWindow());
      },
    );
  }
}
