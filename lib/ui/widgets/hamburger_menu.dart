import 'dart:math' as math;
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';

/// Menu hamburger : Raccourcis clavier, Ouvrir offibox.fr, Réduire, Fermer, À propos.
class HamburgerMenu extends StatefulWidget {
  const HamburgerMenu({
    super.key,
    required this.onOpenOffibox,
    required this.onMinimize,
    required this.onClose,
    this.onShowAbout,
    this.onShowShortcuts,
    this.onOpenGoogleAgenda,
    this.onConnectGoogleAgenda,
    this.onOpenIdBox,
    this.isGoogleConnected = false,
    this.popupKey,
    /// Décalage vertical du menu (pour l’ouvrir sous la barre de recherche).
    this.menuOffsetDy = 0,
    this.barWidth,
    this.barBottomY,
    this.barTopY,
    this.rightMargin,
  });

  final VoidCallback onOpenOffibox;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final VoidCallback? onShowAbout;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onOpenGoogleAgenda;
  /// Appelé pour lancer la connexion OAuth Google Calendar (Windows/Desktop). Si null, l’entrée « Connecter l’agenda Google » est masquée.
  final VoidCallback? onConnectGoogleAgenda;
  /// Ouvre le panneau « Boîte à idées » sous la barre.
  final VoidCallback? onOpenIdBox;
  final bool isGoogleConnected;
  /// Clé pour ouvrir le menu depuis l'extérieur (ex. clic droit sur le logo). Type GlobalKey<HamburgerMenuState>.
  final GlobalKey<HamburgerMenuState>? popupKey;
  /// Décalage vertical (dy) pour placer le menu sous la barre de recherche.
  final double menuOffsetDy;
  /// Largeur de la barre (bord droit en px). Si non null, le menu est aligné à droite sur ce bord.
  final double? barWidth;
  /// Ordinate Y du bas de la barre (en coords overlay). Si non null, le menu s’ouvre sous la barre (top = barBottomY + menuOffsetDy).
  final double? barBottomY;
  final double? barTopY;
  final double? rightMargin;

  static const Color _offiboxTeal = Color(0xFF5A9094);

  @override
  State<HamburgerMenu> createState() => HamburgerMenuState();
}

/// Action du menu (pour showMenu).
enum _HamburgerAction { shortcuts, openOffibox, minimize, close, idBox, about, googleAgenda, connectGoogleAgenda }

class HamburgerMenuState extends State<HamburgerMenu> {
  bool _hovering = false;
  final GlobalKey _buttonKey = GlobalKey();

  /// Ouvre le menu (sous la barre, aligné à droite). Appelé par le bouton ou par popupKey.currentState?.openMenu().
  void openMenu() => _openMenu(context);

  static const double _menuWidth = 280;

  void _openMenu(BuildContext context) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final overlayRect = overlayBox.localToGlobal(Offset.zero) & overlayBox.size;

    double top;
    double rightInset;
    if (widget.barBottomY != null && widget.barWidth != null) {
      // Menu fixé sous la barre, bord droit aligné avec le bord droit de la barre
      top = widget.barBottomY! + widget.menuOffsetDy;
      rightInset = widget.rightMargin ?? (overlayRect.right - widget.barWidth!);
      final left = (overlayRect.right - rightInset - _menuWidth).clamp(0.0, double.infinity);
      final position = RelativeRect.fromLTRB(left, top, rightInset, 0);
      return _showMenuAt(context, position, overlayRect);
    }
    final buttonBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;
    final buttonRect = buttonBox.localToGlobal(Offset.zero) & buttonBox.size;
    top = buttonRect.bottom + widget.menuOffsetDy;
    rightInset = overlayRect.right - buttonRect.right;
    final position = RelativeRect.fromLTRB(0, top, rightInset, 0);
    return _showMenuAt(context, position, overlayRect);
  }

  Future<void> _showMenuAt(BuildContext context, RelativeRect position, Rect overlayRect) async {
    final items = _buildMenuItems();
    final top = position.top;
    final maxHeight = (overlayRect.bottom - top - 16).clamp(200.0, double.infinity);
    final _HamburgerAction? value = await material.showMenu<_HamburgerAction>(
      context: context,
      positionBuilder: (_, __) => position,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      color: Colors.white,
      elevation: 8,
      items: items,
    );
    if (value == null || !mounted) return;
    switch (value) {
      case _HamburgerAction.shortcuts:
        widget.onShowShortcuts?.call();
        break;
      case _HamburgerAction.openOffibox:
        widget.onOpenOffibox();
        break;
      case _HamburgerAction.minimize:
        widget.onMinimize();
        break;
      case _HamburgerAction.close:
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
        break;
      case _HamburgerAction.idBox:
        widget.onOpenIdBox?.call();
        break;
      case _HamburgerAction.about:
        widget.onShowAbout?.call();
        break;
      case _HamburgerAction.googleAgenda:
        widget.onOpenGoogleAgenda?.call();
        break;
      case _HamburgerAction.connectGoogleAgenda:
        widget.onConnectGoogleAgenda?.call();
        break;
    }
  }

  List<PopupMenuEntry<_HamburgerAction>> _buildMenuItems() {
    return [
          if (widget.onShowShortcuts != null)
            const PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.shortcuts,
              child: _MenuItemRow(
                icon: Icons.keyboard,
                label: 'Raccourcis clavier',
              ),
            ),
          if (widget.onShowShortcuts != null) const PopupMenuDivider(height: 3),
          const PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.openOffibox,
            child: _MenuItemRow(
              label: 'Ouvrir offibox.fr',
              isOffiboxFrLabel: true,
              iconAssetPath: 'assets/icons/logo_offibox2.png',
            ),
          ),
          if (widget.isGoogleConnected && widget.onOpenGoogleAgenda != null)
            const PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.googleAgenda,
              child: _MenuItemRow(
                icon: Icons.event_note_outlined,
                label: 'Google Agenda',
              ),
            ),
          if (!widget.isGoogleConnected && widget.onConnectGoogleAgenda != null)
            const PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.connectGoogleAgenda,
              child: _MenuItemRow(
                icon: Icons.event_note_outlined,
                label: 'Connecter l\'agenda Google',
            ),
          ),
          const PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.minimize,
            child: _MenuItemRow(
              icon: Icons.minimize,
              label: 'Réduire',
              rotateMinimize: true,
            ),
          ),
          const PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.close,
            child: _MenuItemRow(
              icon: Icons.close,
              label: 'Quitter',
            ),
          ),
          if (widget.onOpenIdBox != null)
            const PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.idBox,
              child: _MenuItemRow(
                label: 'Id Box',
                isIdBoxLabel: true,
                iconAssetPath: 'assets/icons/ampoule_idees.jpg',
              ),
            ),
          if (widget.onShowAbout != null)
            const PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.about,
              child: _MenuItemRow(
                icon: Icons.info_outline,
                label: 'À propos',
              ),
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const size = OffiboxWindowUI.menuButtonSize;
    return Tooltip(
      message: 'Menu',
      textStyle: const TextStyle(color: HamburgerMenu._offiboxTeal, fontFamily: 'Spinnaker'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: _buttonKey,
          onTap: () => _openMenu(context),
          child: SizedBox(
            width: size,
            height: size,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: _hovering ? HamburgerMenu._offiboxTeal : OffiboxColors.tealLight,
                shape: BoxShape.circle,
                border: Border.all(color: HamburgerMenu._offiboxTeal, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_rounded,
                size: 22,
                color: _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatefulWidget {
  final IconData? icon;
  final bool useExternalLink;
  final String label;
  final bool rotateMinimize;
  /// Affiche le label en style Offi (teal) + box.fr (gris), Spinnaker.
  final bool isOffiboxFrLabel;
  /// Affiche le label en style ID (vert) + box (gris), Spinnaker.
  final bool isIdBoxLabel;
  /// Chemin d’une image (ex. ampoule) affichée devant le label.
  final String? iconAssetPath;

  const _MenuItemRow({
    this.icon,
    this.useExternalLink = false,
    required this.label,
    this.rotateMinimize = false,
    this.isOffiboxFrLabel = false,
    this.isIdBoxLabel = false,
    this.iconAssetPath,
  });

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hovering = false;

  static const Color _idBoxGreen = Color(0xFF2E7D32);

  Widget _buildOffiboxFrStyle(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13,
      fontFamily: 'Spinnaker',
      fontWeight: FontWeight.w600,
      color: _hovering ? Colors.white : Colors.grey.shade800,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Ouvrir ', style: baseStyle),
        Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(
                text: 'Offi',
                style: TextStyle(
                  color: _hovering ? Colors.white : OffiboxColors.primary,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Spinnaker',
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: 'box.fr',
                style: TextStyle(
                  color: _hovering ? Colors.white : OffiboxColors.darkGray,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Spinnaker',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdBoxStyle(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'Spinnaker',
          fontWeight: FontWeight.w600,
          color: _hovering ? Colors.white : Colors.grey.shade800,
        ),
        children: [
          TextSpan(
            text: 'ID',
            style: TextStyle(
              color: _hovering ? Colors.white : _idBoxGreen,
              fontWeight: FontWeight.w700,
              fontFamily: 'Spinnaker',
              fontSize: 13,
            ),
          ),
          TextSpan(
            text: ' BOX',
            style: TextStyle(
              color: _hovering ? Colors.white : OffiboxColors.darkGray,
              fontWeight: FontWeight.w700,
              fontFamily: 'Spinnaker',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovering ? HamburgerMenu._offiboxTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
        ),
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 0.48, horizontal: 4),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              if (widget.useExternalLink)
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/icons/monitor_www.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.open_in_browser,
                      size: 20,
                      color: _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
                    ),
                  ),
                )
              else if (widget.iconAssetPath != null)
                Image.asset(
                  widget.iconAssetPath!,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
                  ),
                )
              else if (widget.icon != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: Transform.rotate(
                      angle: widget.rotateMinimize ? math.pi : 0,
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              widget.isOffiboxFrLabel
                  ? _buildOffiboxFrStyle(context)
                  : widget.isIdBoxLabel
                      ? _buildIdBoxStyle(context)
                      : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Spinnaker',
                        fontWeight: FontWeight.w500,
                        color: _hovering ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
