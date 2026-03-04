import 'dart:async';

import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/offibox_logo_button.dart';

/// Encapsulation bouton + logo : au lancement le logo est au repos (apparition en fondu, pas de scale hover),
/// puis scalable quand la barre est déployée, les menus ou fenêtres ouverts (scale doux selon [expanded]).
class OffiboxPill extends StatefulWidget {
  const OffiboxPill({
    super.key,
    required this.onTap,
    this.onSecondaryTap,
    this.expanded = false,
  });

  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  /// true quand la barre est déployée (ou menu/fenêtre ouverts) → logo scale légèrement pour rester cohérent.
  final bool expanded;

  static double get size => OffiboxWindowUI.pillSize;
  /// Bordures arrondies comme les badges (tickerBadgeBorderRadius)
  static const double borderRadius = 22;

  @override
  State<OffiboxPill> createState() => _OffiboxPillState();
}

class _OffiboxPillState extends State<OffiboxPill>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _restEnded = false;
  Timer? _restTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _opacity;

  /// Au lancement le logo reste au repos (pas de scale au survol) pendant cette durée.
  static const Duration _restDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _restTimer = Timer(_restDuration, () {
      if (mounted) setState(() => _restEnded = true);
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoverScale = (_restEnded && _hovering) ? 1.02 : 1.0;
    final baseScale = widget.expanded ? 1.06 : 1.0;
    final scale = baseScale * hoverScale;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onSecondaryTapDown: widget.onSecondaryTap != null
            ? (_) => widget.onSecondaryTap!()
            : null,
        child: FadeTransition(
          opacity: _opacity,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OffiboxPill.borderRadius),
              child: Container(
                width: OffiboxPill.size,
                height: OffiboxPill.size,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(OffiboxPill.borderRadius),
                  border: Border.all(
                    color: Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
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
      ),
    );
  }
}
