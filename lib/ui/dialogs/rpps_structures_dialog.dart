import 'package:flutter/material.dart';

/// Dialogue listant les structures d'un professionnel RPPS.
class RppsStructuresDialog extends StatelessWidget {
  const RppsStructuresDialog({
    super.key,
    required this.rpps,
    required this.displayName,
  });

  final String rpps;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Structures — $displayName'),
      content: const Text('Liste des structures (non chargée).'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
