import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:offibox/utils/open_url.dart';

class TrialExpiredPageNoAuth extends StatelessWidget {
  const TrialExpiredPageNoAuth({super.key});

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
                const Icon(Icons.schedule, size: 70, color: Colors.orange),
                const SizedBox(height: 24),
                Text("Période d'essai terminée", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.grey.shade100)),
                const SizedBox(height: 12),
                Text("Votre période d'essai de 15 jours est terminée. Connectez-vous sur Offibox.fr pour activer une licence.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey.shade300)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(onPressed: () => SystemNavigator.pop(), child: const Text("Fermer")),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: () => openUrl('https://offibox.fr'), child: const Text("Offibox.fr")),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}