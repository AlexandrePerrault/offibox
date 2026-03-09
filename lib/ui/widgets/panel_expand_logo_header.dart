
import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';

/// Bandeau en haut des panneaux PDF / XLS / vidéo : logo « étendre » en blanc sur fond Offibox.
const String _expandLogoAsset = 'assets/icons/agrandir-la-fenetre.png';

class PanelExpandLogoHeader extends StatelessWidget {
  const PanelExpandLogoHeader({super.key, this.width});

  /// Largeur du bandeau (optionnel, par défaut prend toute la largeur).
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      color: OffiboxColors.primary,
      alignment: Alignment.center,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          _expandLogoAsset,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.open_in_full,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
