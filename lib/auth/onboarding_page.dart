import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:offibox/services/firestore_user_cache.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _loading = false;

  Future<void> _finishOnboarding() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté')),
        );
      }
      return;
    }

    final ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await ref.set({
        'email': user.email,
        'onboardingDone': true,
        'createdAt': FieldValue.serverTimestamp(),
        'trialEndsAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
        'plan': 'trial',
        'maxDevices': 5,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
      FirestoreUserCache.instance.invalidate(user.uid);

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  Text(
                    'Bienvenue dans Offibox',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade100,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Avant de commencer, voici quelques informations importantes.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade300,
                    ),
                  ),

                  const SizedBox(height: 32),

                  _infoItem(
                    icon: Icons.schedule,
                    title: 'Essai gratuit 15 jours',
                    text:
                        'Vous disposez de 15 jours pour tester toutes les fonctionnalités sans engagement.',
                  ),

                  _infoItem(
                    icon: Icons.devices,
                    title: 'Licence limitée à 5 PC',
                    text:
                        'Votre licence est personnelle et ne peut être utilisée que sur 5 ordinateurs maximum.',
                  ),

                  _infoItem(
                    icon: Icons.lock_outline,
                    title: 'Connexion unique',
                    text:
                        'Vous n’aurez pas à vous reconnecter tant que vous ne vous déconnectez pas volontairement.',
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _finishOnboarding,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Commencer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'En cliquant sur “Commencer”, vous acceptez les conditions d’utilisation.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
