import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrialExpiredPage extends StatefulWidget {
  const TrialExpiredPage({super.key});

  @override
  State<TrialExpiredPage> createState() => _TrialExpiredPageState();
}

class _TrialExpiredPageState extends State<TrialExpiredPage> {
  @override
  void initState() {
    super.initState();
    _markStatusBlocked();
  }

  Future<void> _markStatusBlocked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'status': 'blocked',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock,
                  size: 70,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  "Essai expiré",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Votre période d'essai de 15 jours est terminée.\nVeuillez activer une licence pour continuer.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text("Se déconnecter"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
