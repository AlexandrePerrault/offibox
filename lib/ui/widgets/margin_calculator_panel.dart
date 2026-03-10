import 'package:flutter/material.dart';

/// Panneau calculatrice de marge sous la barre.
class MarginCalculatorPanel extends StatelessWidget {
  const MarginCalculatorPanel({
    super.key,
    required this.barWidth,
    required this.onClose,
  });

  final double barWidth;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: barWidth,
        child: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Calculatrice de marge')),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
