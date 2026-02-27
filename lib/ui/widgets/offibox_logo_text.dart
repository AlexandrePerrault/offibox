import 'package:flutter/material.dart';

class OffiboxLogoText extends StatelessWidget {
  const OffiboxLogoText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Offibox',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Color(0xFF5A9094),
      ),
    );
  }
}
