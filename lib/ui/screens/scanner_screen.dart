import 'package:flutter/material.dart';

/// Écran de scan (code-barres / QR) pour iOS. Appelle [onScanned] avec le texte lu.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({
    super.key,
    required this.onScanned,
  });

  final void Function(String raw) onScanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onScanned('');
          },
          child: const Text('Simuler scan (placeholder)'),
        ),
      ),
    );
  }
}
