import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Dialogue compte utilisateur (email, déconnexion).
class AccountDialog extends StatelessWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AlertDialog(
      title: const Text('Mon compte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user?.email != null)
            Text(user!.email!, style: const TextStyle(fontSize: 14)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}
