import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';

/// Logo complet Offibox : texte "Offi" (teal) + "Box" (gris) + icône boîte.
class OffiboxLogoComplete extends StatelessWidget {
  const OffiboxLogoComplete({
    super.key,
    this.height = 48,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * 2,
      child: Image.asset(
        'assets/icons/logo_offibox_installer.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackLogo(),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Offi',
          style: TextStyle(
            fontSize: height * 0.6,
            fontWeight: FontWeight.w700,
            color: OffiboxColors.primary,
          ),
        ),
        Text(
          'Box',
          style: TextStyle(
            fontSize: height * 0.6,
            fontWeight: FontWeight.w700,
            color: OffiboxColors.darkGray,
          ),
        ),
      ],
    );
  }
}
