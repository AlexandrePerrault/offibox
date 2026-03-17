import 'package:flutter/material.dart';


class OffiboxLogoButton extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const OffiboxLogoButton({
    super.key,
    required this.onTap,
    this.size = 44,
  });

  @override
  State<OffiboxLogoButton> createState() => _OffiboxLogoButtonState();
}

class _OffiboxLogoButtonState extends State<OffiboxLogoButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) {
        setState(() => pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1.0, // ✨ enfoncement
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.asset(
            'assets/icons/logo_offibox.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.medication,
              size: widget.size * 0.7,
              color: const Color(0xFF5A9094), // Offibox teal
            ),
          ),
        ),
      ),
    );
  }
}
