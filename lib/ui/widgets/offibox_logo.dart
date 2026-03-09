import 'package:flutter/material.dart';

class OffiboxLogo extends StatelessWidget {
  const OffiboxLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo_offibox.png',
      height: 64,
      fit: BoxFit.contain,
    );
  }
}

