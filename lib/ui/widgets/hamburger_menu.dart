import 'dart:math' as math;
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/offibox_tooltip.dart';

/// Menu hamburger : Raccourcis clavier, Ouvrir offibox.fr, Réduire, Fermer, À propos.
class HamburgerMenu extends StatefulWidget {
  const HamburgerMenu({
    super.key,
    required this.onOpenOffibox,
    required this.onMinimize,
    required this.onClose,
    this.onShowAccount,
    this.onShowAbout,
    this.onShowShortcuts,
    this.onShowContact,
    this.onShowVersionHistory,
    this.onOpenGoogleAgenda,
    this.onConnectGoogleAgenda,
    this.onOpenIdBox,
    this.isGoogleConnected = false,
    /// Si false (ex. pas de compte Gmail), l'entrée « Connecter l'agenda Google » est affichée mais grisée.
    this.canConnectGoogleAgenda = true,
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
  final VoidCallback? onShowAccount;
  final VoidCallback? onShowAbout;
  final VoidCallback? onShowShortcuts;
  /// Ouvre le dialogue Contact (téléphone, mail, adresse + formulaire).
  final VoidCallback? onShowContact;
  /// Ouvre le dialogue « Historique des versions » (releases GitHub + notes).
  final VoidCallback? onShowVersionHistory;
  final VoidCallback? onOpenGoogleAgenda;
  /// Appelé pour lancer la connexion OAuth Google Calendar (Windows/Desktop). Si null, l’entrée « Connecter l’agenda Google » est masquée.
  final VoidCallback? onConnectGoogleAgenda;
  /// Ouvre le panneau « Boîte à idées » sous la barre.
  final VoidCallback? onOpenIdBox;
  final bool isGoogleConnected;
  /// Autorise l'action « Connecter l'agenda Google » (ex. compte Gmail). Si false, l'entrée est grisée.
  final bool canConnectGoogleAgenda;
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
enum _HamburgerAction {
  account,
  shortcuts,
  openOffibox,
  minimize,
  close,
  idBox,
  contact,
  versionHistory,
  about,
  googleAgenda,
  connectGoogleAgenda,
}

class HamburgerMenuState extends State<HamburgerMenu> {
  bool _hovering = false;
  final GlobalKey _buttonKey = GlobalKey();

  /// Ouvre le menu (sous la barre, aligné à droite). Appelé par le bouton ou par popupKey.currentState?.openMenu().
  void openMenu() => _openMenu(context);

  static const double _menuWidth = 224;
  /// Hauteur d’un item (réduite de ~20 % par rapport au défaut 48).
  static const double _itemHeight = 38;

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
      case _HamburgerAction.account:
        widget.onShowAccount?.call();
        break;
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
      case _HamburgerAction.contact:
        widget.onShowContact?.call();
        break;
      case _HamburgerAction.versionHistory:
        widget.onShowVersionHistory?.call();
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
    int idx = 0;
    Widget wrapFade(Widget child) {
      final i = idx++;
      return _FadeInMenuItem(index: i, child: child);
    }
    return [
          if (widget.onShowAccount != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.account,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.account_circle_outlined,
                label: 'Mon compte',
              )),
            ),
          if (widget.onShowAccount != null) const PopupMenuDivider(height: 2.4),
          if (widget.onShowShortcuts != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.shortcuts,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.keyboard,
                label: 'Raccourcis clavier',
              )),
            ),
          if (widget.onShowShortcuts != null) const PopupMenuDivider(height: 2.4),
          PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.openOffibox,
            height: _itemHeight,
            child: wrapFade(const _MenuItemRow(
              label: 'Ouvrir offibox.fr',
              isOffiboxFrLabel: true,
              useExternalLink: true,
              iconAssetPath: 'assets/icons/logo_offibox2.png',
            )),
          ),
          if (widget.isGoogleConnected)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.googleAgenda,
              height: _itemHeight,
              enabled: false,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.event_note_outlined,
                label: 'Agenda Google (connecté)',
                isGreyed: true,
              )),
            ),
          if (!widget.isGoogleConnected && widget.onConnectGoogleAgenda != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.connectGoogleAgenda,
              height: _itemHeight,
              enabled: widget.canConnectGoogleAgenda,
              child: wrapFade(_MenuItemRow(
                icon: Icons.event_note_outlined,
                label: widget.canConnectGoogleAgenda
                    ? 'Connecter l\'agenda Google'
                    : 'Connecter l\'agenda Google (compte Gmail requis)',
              )),
            ),
          if (widget.onOpenIdBox != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.idBox,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                label: 'Id Box',
                isIdBoxLabel: true,
                iconAssetPath: 'assets/icons/ampoule_idees.jpg',
              )),
            ),
          if (widget.onShowContact != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.contact,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.alternate_email,
                label: 'Formulaire de contact',
              )),
            ),
          if (widget.onShowVersionHistory != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.versionHistory,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.history,
                label: 'Historique des versions',
              )),
            ),
          if (widget.onShowAbout != null)
            PopupMenuItem<_HamburgerAction>(
              value: _HamburgerAction.about,
              height: _itemHeight,
              child: wrapFade(const _MenuItemRow(
                icon: Icons.info_outline,
                label: 'À propos',
              )),
            ),
          PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.minimize,
            height: _itemHeight,
            child: wrapFade(const _MenuItemRow(
              icon: Icons.minimize,
              label: 'Réduire',
              rotateMinimize: true,
            )),
          ),
          PopupMenuItem<_HamburgerAction>(
            value: _HamburgerAction.close,
            height: _itemHeight,
            child: wrapFade(const _MenuItemRow(
              icon: Icons.close,
              label: 'Quitter',
            )),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const size = OffiboxWindowUI.menuButtonSize;
    return OffiboxTooltip(
      message: 'Menu',
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

/// Enveloppe un enfant du menu hamburger avec une apparition en fondu (délai échelonné par index).
class _FadeInMenuItem extends StatefulWidget {
  const _FadeInMenuItem({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_FadeInMenuItem> createState() => _FadeInMenuItemState();
}

class _FadeInMenuItemState extends State<_FadeInMenuItem>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 180);
  static const _delayPerItem = 32;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    final delay = widget.index * _delayPerItem;
    if (delay > 0) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
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
  /// Affiche l'entrée en gris (ex. « Agenda Google (connecté) » non cliquable).
  final bool isGreyed;

  const _MenuItemRow({
    this.icon,
    bool useExternalLink = false,
    required this.label,
    this.rotateMinimize = false,
    this.isOffiboxFrLabel = false,
    this.isIdBoxLabel = false,
    this.iconAssetPath,
    this.isGreyed = false,
  }) : useExternalLink = useExternalLink;

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hovering = false;

  static const Color _idBoxGreen = Color(0xFF2E7D32);
  static const Color _greyedColor = Color(0xFF9E9E9E);
  /// Largeur fixe de la colonne d’icônes pour les aligner verticalement.
  static const double _iconSlotWidth = 24;

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
        padding: const EdgeInsets.symmetric(vertical: 0.48, horizontal: 3),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.iconAssetPath != null)
                SizedBox(
                  width: _iconSlotWidth,
                  child: Center(
                    child: Image.asset(
                      widget.iconAssetPath!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: _hovering ? Colors.white : HamburgerMenu._offiboxTeal,
                      ),
                    ),
                  ),
                )
              else if (widget.useExternalLink)
                SizedBox(
                  width: _iconSlotWidth,
                  child: Center(
                    child: ColorFiltered(
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
                    ),
                  ),
                )
              else if (widget.icon != null)
                SizedBox(
                  width: _iconSlotWidth,
                  child: Center(
                    child: Transform.rotate(
                      angle: widget.rotateMinimize ? math.pi : 0,
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: widget.isGreyed
                            ? _greyedColor
                            : (_hovering ? Colors.white : HamburgerMenu._offiboxTeal),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
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
                        color: widget.isGreyed
                            ? _greyedColor
                            : (_hovering ? Colors.white : Colors.grey.shade800),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
