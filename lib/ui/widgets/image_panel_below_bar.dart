import 'package:flutter/material.dart';

/// Panneau affichant une image (asset) sous la barre.
class ImagePanelBelowBar extends StatelessWidget {
  const ImagePanelBelowBar({
    super.key,
    required this.assetPath,
    required this.barWidth,
    required this.onClose,
  });

  final String assetPath;
  final double barWidth;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              assetPath,
              width: barWidth,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 200,
                height: 120,
                child: Center(child: Text('Image non disponible')),
              ),
            ),
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
    );
  }
}
