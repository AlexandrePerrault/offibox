import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/offibox_logo_button.dart';

class OffiboxPill extends StatefulWidget {
  const OffiboxPill({
    super.key,
    required this.onTap,
    this.onSecondaryTap,
  });

  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  static double get size => OffiboxWindowUI.pillSize;
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
      child: GestureDetector(
        onSecondaryTapDown: widget.onSecondaryTap != null
            ? (_) => widget.onSecondaryTap!()
            : null,
        child: AnimatedScale(
          scale: _hovering ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(OffiboxPill.borderRadius),
            child: Container(
                width: OffiboxPill.size,
                height: OffiboxPill.size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius:
                      BorderRadius.circular(OffiboxPill.borderRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 1.0),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Color(0x0AFFFFFF),
                      blurRadius: 2,
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
          ),
        ),
      );
  }
}
