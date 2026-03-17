import 'package:flutter/material.dart';

/// Panneau affichant une image (asset) sous la barre, avec titre optionnel au-dessus.
class ImagePanelBelowBar extends StatelessWidget {
  const ImagePanelBelowBar({
    super.key,
    required this.assetPath,
    required this.barWidth,
    required this.onClose,
    this.title,
  });

  final String assetPath;
  final double barWidth;
  final VoidCallback onClose;
  /// Titre affiché au-dessus de l'image (ex. "disponibilité produits - semaine 13").
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null && title!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 40, 8),
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: title != null ? BorderRadius.zero : BorderRadius.circular(8),
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
              ),
            ],
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
