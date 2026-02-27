import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/utils/open_url.dart';

/// Badge on/off type iOS : piste en pill, glissable — droite = ouvrir, gauche = fermer.
class _InfoBarOnOffBadge extends StatefulWidget {
  const _InfoBarOnOffBadge({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _trackWidth = 27;
  static const double _trackHeight = 17;
  static const double _knobSize = 12;
  static const double _padding = 2;

  @override
  State<_InfoBarOnOffBadge> createState() => _InfoBarOnOffBadgeState();
}

class _InfoBarOnOffBadgeState extends State<_InfoBarOnOffBadge> {
  double? _dragOffset; // offset pendant le drag (px), null = pas de drag

  double get _effectivePosition {
    if (_dragOffset != null) {
      final range = _InfoBarOnOffBadge._trackWidth -
          2 * _InfoBarOnOffBadge._padding -
          _InfoBarOnOffBadge._knobSize;
      final raw = (widget.value ? range : 0) + _dragOffset!;
      return raw.clamp(0.0, range);
    }
    return widget.value
        ? (_InfoBarOnOffBadge._trackWidth -
            2 * _InfoBarOnOffBadge._padding -
            _InfoBarOnOffBadge._knobSize)
        : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final range = _InfoBarOnOffBadge._trackWidth -
        2 * _InfoBarOnOffBadge._padding -
        _InfoBarOnOffBadge._knobSize;
    final isOn = _dragOffset == null
        ? widget.value
        : _effectivePosition >= range * 0.5;
    final padding = _InfoBarOnOffBadge._padding;
    final isDragging = _dragOffset != null;

    return Tooltip(
      message: isOn
          ? 'Glisser à gauche pour replier'
          : 'Glisser à droite pour déployer',
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        onHorizontalDragStart: (_) => setState(() => _dragOffset = 0),
        onHorizontalDragUpdate: (d) =>
            setState(() => _dragOffset = (_dragOffset ?? 0) + d.delta.dx),
        onHorizontalDragEnd: (d) {
          final velocity = d.velocity.pixelsPerSecond.dx;
          final pos = _effectivePosition;
          bool newValue;
          if (velocity.abs() > 100) {
            newValue = velocity > 0;
          } else {
            newValue = pos >= range * 0.5;
          }
          setState(() => _dragOffset = null);
          if (newValue != widget.value) widget.onChanged(newValue);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _InfoBarOnOffBadge._trackWidth,
          height: _InfoBarOnOffBadge._trackHeight,
          child: Container(
            decoration: BoxDecoration(
              // ON (barre déployée) = couleur Offibox, OFF = gris
              color: isOn ? OffiboxColors.primary : const Color(0xFF979797),
              borderRadius:
                  BorderRadius.circular(_InfoBarOnOffBadge._trackHeight / 2),
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isDragging)
                  Positioned(
                    left: padding + _effectivePosition,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildKnob(isOn),
                    ),
                  )
                else
                  TweenAnimationBuilder<double>(
                    key: ValueKey(widget.value),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOutCubic,
                    builder: (context, t, _) {
                      final leftPos =
                          padding + (widget.value ? t : 1 - t) * range;
                      return Positioned(
                        left: leftPos,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildKnob(widget.value),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKnob(bool isOn) {
    return Container(
      width: _InfoBarOnOffBadge._knobSize,
      height: _InfoBarOnOffBadge._knobSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Type d’icône pour un item du ticker.
enum TickerItemIcon { none, danger, info }

/// Élément cliquable de la barre défilante (label, url, optionnel: tooltip, icône, couleurs ANSM bleu / DGS rouge / override).
typedef TickerItem = ({
  String label,
  String url,
  String? tooltip,
  TickerItemIcon icon,
  bool isAnsm,
  bool isDgs,
  Color? colorOverride,
});

class OffiboxInfoBar extends StatefulWidget {
  const OffiboxInfoBar({
    super.key,
    required this.visible,
    required this.width,
    required this.items,
    this.value = true,
    this.onChanged,
  });

  final bool visible;
  final double width;
  final List<TickerItem> items;
  /// true = barre déployée (on), false = repliée (off).
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<OffiboxInfoBar> createState() => _OffiboxInfoBarState();
}

class _OffiboxInfoBarState extends State<OffiboxInfoBar> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  bool _paused = false;

  static const double _speed = 30;

  static const String _sep = '  •  ';
  static const int _minLength = 300;

  /// Puce grise entre les badges (gris Offibox, type Word).
  static Color get _bulletColor => offiboxGrey;

  /// Préfixe Unicode selon le type d’icône (danger triangle, info).
  static String _iconPrefix(TickerItemIcon icon) {
    switch (icon) {
      case TickerItemIcon.danger:
        return '\u{26A0} '; // ⚠
      case TickerItemIcon.info:
        return '\u{2139} '; // ℹ
      case TickerItemIcon.none:
        return '';
    }
  }

  /// Couleur par item (override, DGS rouge = même que badge INFOS, ANSM bleu, défaut brun).
  static Color _colorForItem(TickerItem e) {
    if (e.colorOverride != null) return e.colorOverride!;
    if (e.isDgs) return OffiboxWindowUI.tickerInfosRed;
    if (e.isAnsm) return const Color(0xFF1565C0);
    return const Color(0xFF8D6E63);
  }

  /// Un segment = badge (style unifié avec logo INFOS : même pill, typo, padding).
  Widget _buildBadge(TickerItem e, Color bgColor) {
    final content = Container(
      padding: OffiboxWindowUI.tickerBadgePadding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OffiboxWindowUI.tickerBadgeBorderRadius),
      ),
      child: Text(
        e.label,
        style: GoogleFonts.spinnaker(
          fontSize: OffiboxWindowUI.tickerBadgeFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1,
          letterSpacing: 0.3,
        ),
      ),
    );
    final gesture = GestureDetector(
      onTap: () {
        if (e.url.isNotEmpty) openUrl(e.url);
      },
      child: content,
    );
    final msg = e.tooltip;
    if (msg != null && msg.trim().isNotEmpty) {
      return Tooltip(
        message: msg,
        waitDuration: const Duration(milliseconds: 400),
        child: gesture,
      );
    }
    return gesture;
  }

  /// Puce grise entre les badges.
  Widget _bullet() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '•',
        style: GoogleFonts.spinnaker(
          fontSize: 10 * 1.15, // +15 % cohérent avec les badges
          color: _bulletColor,
          height: 1.1,
        ),
      ),
    );
  }

  /// Contenu défilant : badges (common span) + puces grises.
  Widget _buildScrollableContent(BuildContext context) {
    const int repeat = 2;
    final segmentWidgets = <Widget>[];
    for (var r = 0; r < repeat; r++) {
      for (var i = 0; i < widget.items.length; i++) {
        final e = widget.items[i];
        final color = _colorForItem(e);
        segmentWidgets.add(_buildBadge(e, color));
        segmentWidgets.add(_bullet());
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: segmentWidgets,
    );
  }

  @override
  void initState() {
    super.initState();
    // Démarrer le défilement après le premier layout pour que le ScrollController soit attaché
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_paused && mounted && _scrollController.hasClients) {
        final pos = _scrollController.position;
        final maxExtent = pos.maxScrollExtent;
        if (maxExtent <= 0) return;
        final nextOffset = _scrollController.offset + _speed * 0.05;
        if (nextOffset >= maxExtent) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(nextOffset);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const IgnorePointer(child: SizedBox.shrink());

    final barHeight = OffiboxWindowUI.tickerBarHeight;
    return SizedBox(
      height: barHeight,
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => _paused = true,
        onExit: (_) => _paused = false,
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              OffiboxWindowUI.borderRadius,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: widget.value ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (widget.onChanged != null) ...[
                _InfoBarOnOffBadge(
                  value: widget.value,
                  onChanged: widget.onChanged!,
                ),
                const SizedBox(width: 3),
              ],
              GestureDetector(
                onTap: widget.onChanged != null && !widget.value
                    ? () => widget.onChanged!(true)
                    : null,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: barHeight,
                  child: Container(
                    padding: OffiboxWindowUI.tickerBadgePadding,
                    decoration: BoxDecoration(
                      color: OffiboxWindowUI.tickerInfosBadgeGreen,
                      borderRadius: BorderRadius.circular(
                        OffiboxWindowUI.borderRadius,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.value
                          ? 'INFOS'
                          : 'BARRE D\'INFOS DÉSACTIVÉE',
                      style: GoogleFonts.spinnaker(
                        fontSize: OffiboxWindowUI.tickerBadgeFontSize,
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            widget.value ? FontStyle.normal : FontStyle.italic,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              if (widget.value)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Align(
                      alignment: Alignment.center,
                      child: _buildScrollableContent(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
