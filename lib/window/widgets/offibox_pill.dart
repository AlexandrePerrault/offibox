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
    this.searching = false,
  });

  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  /// true quand la barre est déployée (ou menu/fenêtre ouverts) → logo scale légèrement pour rester cohérent.
  final bool expanded;
  /// true pendant une recherche → affiche la gélule (💊) en rotation.
  final bool searching;

  static double get size => OffiboxWindowUI.pillSize;
  /// Bordures arrondies comme les badges (tickerBadgeBorderRadius)
  static const double borderRadius = 22;

  @override
  State<OffiboxPill> createState() => _OffiboxPillState();
}

class _OffiboxPillState extends State<OffiboxPill>
    with TickerProviderStateMixin {
  bool _hovering = false;
  bool _restEnded = false;
  Timer? _restTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _opacity;
  late final AnimationController _rotationController;

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
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _restTimer = Timer(_restDuration, () {
      if (mounted) setState(() => _restEnded = true);
    });
    if (widget.searching) _rotationController.repeat();
  }

  @override
  void didUpdateWidget(covariant OffiboxPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching != oldWidget.searching) {
      if (widget.searching) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _fadeController.dispose();
    _rotationController.dispose();
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
                  // Toujours le même "contour" arrondi, même barre repliée.
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(OffiboxPill.borderRadius),
                  border: Border.all(
                    color: const Color(0x14000000),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
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
                  child: widget.searching
                      ? RotationTransition(
                          turns: _rotationController,
                          child: GestureDetector(
                            onTap: widget.onTap,
                            child: const Text(
                              '💊',
                              style: TextStyle(fontSize: 28),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : OffiboxLogoButton(
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
