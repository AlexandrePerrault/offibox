import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Bannière de debug visible en mode debug pour diagnostiquer l'écran noir.
class DebugBanner extends StatelessWidget {
  const DebugBanner({
    super.key,
    required this.label,
    this.child,
  });

  final String label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return child ?? const SizedBox.shrink();
    }
    return Stack(
      children: [
        if (child != null) child!,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.amber.shade700,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'DEBUG: $label',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
