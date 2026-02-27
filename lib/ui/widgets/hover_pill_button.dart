import 'package:flutter/material.dart';
class HoverPillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Widget? iconWidget; // SVG / custom
  final String tooltip;
  final VoidCallback onTap;

  /// Hauteur du pill (défaut 30.8, soit +10 % par rapport à 28).
  final double? height;
  /// Largeur max du libellé (défaut 500 : libellé en entier pour tous les hover pills).
  final double? maxLabelWidth;
  /// Prend toute la largeur disponible (barre pleine largeur).
  final bool expand;
  /// Icône affichée après le libellé (ex. Material icon).
  final IconData? trailingIcon;
  /// Widget affiché après le libellé (ex. logo PDF rouge assets/icons/pdf_red.svg).
  final Widget? trailingWidget;

  const HoverPillButton({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    required this.tooltip,
    required this.onTap,
    this.height,
    this.maxLabelWidth,
    this.expand = false,
    this.trailingIcon,
    this.trailingWidget,
  }) : assert(icon != null || iconWidget != null);

  @override
  State<HoverPillButton> createState() => _HoverPillButtonState();
}


class _HoverPillButtonState extends State<HoverPillButton> {
  static const Color offiboxTeal = Color(0xFF5A9094);
  /// Hauteur par défaut +10 % (28 → 30.8).
  static const double _defaultHeight = 30.8;
  bool _hovered = false;

  double get _height => widget.height ?? _defaultHeight;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        _hovered ? Colors.white : offiboxTeal;

    final Color foregroundColor =
        _hovered ? offiboxTeal : Colors.white;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 900),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: widget.expand ? double.infinity : null,
            height: _height,
            padding: EdgeInsets.symmetric(horizontal: _height * 0.43),
            transform: Matrix4.identity()
              // ignore: deprecated_member_use
              ..translate(0.0, _hovered ? -1.5 : 0.0), // 🧠 lift 3D
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: offiboxTeal, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hovered ? 0.30 : 0.15,
                  ),
                  blurRadius: _hovered ? 14 : 5,
                  offset: Offset(0, _hovered ? 6 : 3),
                ),
              ],
            ),
            child: ClipRect(
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: widget.expand ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  // Icône (taille fixe)
                  AnimatedScale(
                    scale: _hovered ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: AnimatedRotation(
                      turns: _hovered ? 0.01 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: _buildIcon(foregroundColor),
                    ),
                  ),

                  const SizedBox(width: 6),

                  if (widget.expand)
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: widget.maxLabelWidth ?? 500),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.35,
                            color: foregroundColor,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.maxLabelWidth ?? 500),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                          color: foregroundColor,
                        ),
                      ),
                    ),
                  if (widget.trailingWidget != null) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(foregroundColor, BlendMode.srcIn),
                        child: widget.trailingWidget,
                      ),
                    ),
                  ] else if (widget.trailingIcon != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      widget.trailingIcon,
                      size: 16,
                      color: foregroundColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    if (widget.iconWidget != null) {
      return SizedBox(
        width: 24,
        height: 24,
        child: IconTheme(
          data: IconThemeData(color: color, size: 24),
          child: widget.iconWidget!,
        ),
      );
    }

    return Icon(
      widget.icon,
      size: 16,
      color: color,
    );
  }
}
