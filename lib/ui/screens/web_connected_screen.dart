import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:offibox/generated/build_info.dart';
import 'package:offibox/services/trial_guard.dart';
import 'package:offibox/services/web_session_guard.dart';

/// Écran version web une fois connecté : barre déployée avec « mis à jour le … » et « licence jusqu'au … ».
/// Vérifie la limite de 5 connexions simultanées et affiche un message si dépassée.
class WebConnectedScreen extends StatefulWidget {
  const WebConnectedScreen({super.key});

  @override
  State<WebConnectedScreen> createState() => _WebConnectedScreenState();
}

class _WebConnectedScreenState extends State<WebConnectedScreen> {
  String? _licenseEndDate;
  bool _loading = true;
  String? _sessionError;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _loadLicenseAndCheckSession();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      WebSessionGuard.unregisterSession(uid);
    }
    super.dispose();
  }

  Future<void> _loadLicenseAndCheckSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final sessionError = await WebSessionGuard.tryRegisterSession(user.uid);
    if (!mounted) return;
    if (sessionError != null) {
      setState(() {
        _sessionError = sessionError;
        _loading = false;
      });
      return;
    }
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      WebSessionGuard.heartbeat(user.uid);
    });
    await TrialGuard.ensureTrialStartedOnFirstConnection();
    final date = await TrialGuard.getLicenseEndDate();
    if (!mounted) return;
    setState(() {
      if (date != null) {
        _licenseEndDate =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F0F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sessionError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F0F1),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                Text(
                  _sessionError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    setState(() => _sessionError = null);
                  },
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F1),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre type « déployée » : mis à jour + licence jusqu'au
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'mis à jour le ${kVersionDate}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  if (_licenseEndDate != null && _licenseEndDate!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      'licence jusqu\'au $_licenseEndDate',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Vous êtes connecté à Offibox (version web).',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
