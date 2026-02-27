import 'package:flutter/material.dart';
import 'package:offibox/ui/widgets/offibox_logo_button.dart';

class OffiboxPill extends StatefulWidget {
  const OffiboxPill({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  static const double size = 60;
  static const double borderRadius = 15;

  @override
  State<OffiboxPill> createState() => _OffiboxPillState();
}

class _OffiboxPillState extends State<OffiboxPill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: Container(
          width: OffiboxPill.size,
          height: OffiboxPill.size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(OffiboxPill.borderRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x08FFFFFF),
                blurRadius: 3,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Center(
            child: OffiboxLogoButton(
              size: 48,
              onTap: widget.onTap,
            ),
          ),
        ),
      ),
    );
  }
}
