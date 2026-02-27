import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/offibox_info_bar.dart';
import 'package:offibox/ui/widgets/window/floating_search_bar.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';
import 'package:offibox/window/widgets/offibox_pill.dart';
import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/catalogue_panel_below_bar.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/ui/widgets/youtube_video_panel_below_bar.dart';
import 'package:offibox/ui/widgets/pharmaradio_flash_panel_below_bar.dart';
import 'package:offibox/ui/widgets/therapeutic_video_panel_below_bar.dart';

/// Croix de fermeture (ligne 1, au-dessus du logo) : rouge, inversion au survol, ne chevauche jamais le texte.
class _CloseBarButton extends StatefulWidget {
  const _CloseBarButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CloseBarButton> createState() => _CloseBarButtonState();
}

class _CloseBarButtonState extends State<_CloseBarButton> {
  static const Color _red = Color(0xFFD32F2F);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered ? Colors.white : _red;
    final fg = _hovered ? _red : Colors.white;
    return Tooltip(
      message: 'Refermer',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: _red, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.18 : 0.12),
                  blurRadius: _hovered ? 6 : 4,
                  offset: Offset(0, _hovered ? 2 : 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.close, size: 16, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton pour replier (▲) ou déployer (▼) la barre d’infos.

class OffiboxTopBar extends StatelessWidget {
  const OffiboxTopBar({
    super.key,
    required this.expanded,
    this.infoBarExpanded = true,
    this.onToggleInfoBar,
    required this.barWidth,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onTapInside,
    required this.onToggleWindow,
    this.onSearchSubmit,
    this.filterHovered = false,
    this.onFilterHoverChange,
    this.selectedResult,
    this.onOpenSelected,
    this.statutsByCis,
    this.ansmStatutsByCis,
    this.generiques2026ByCis,
    this.generiques2026PrincepsKeyToGenericName,
    this.generiques2026DciToGenericName,
    this.generiques2026CisSet,
    this.biosimilairesInfoByCip,
    this.compositionByCis,
    this.cip13ToFic03Status,
    this.compositionBdpmByCis,
    this.hospitalCip13Set,
    this.menuPopupKey,
    this.onOpenOffibox,
    this.onMinimize,
    this.onClose,
    this.onShowAbout,
    this.onShowShortcuts,
    this.onOpenGoogleAgenda,
    this.onConnectGoogleAgenda,
    this.onOpenIdBox,
    this.isGoogleConnected = false,
    this.onEscape,
    this.infoBarItems,
    this.leadingFilterButton,
    this.appVersion = '1.0.0',
    this.onOpenEspacePro,
    this.onOpenCataloguePdf,
    this.onDownloadCataloguePdf,
    this.showCataloguePanel = false,
    this.onOpenCataloguePanel,
    this.showYouTubePanel = false,
    this.youtubeVideoUrl,
    this.onOpenYouTubeVideo,
    this.onCloseYouTubePanel,
    this.showTherapeuticVideoPanel = false,
    this.therapeuticVideoUrl,
    this.onOpenTherapeuticVideo,
    this.onCloseTherapeuticVideo,
    this.videosByCip13,
    this.showPharmaradioFlashPanel = false,
    this.onOpenPharmaradioFlash,
    this.onClosePharmaradioFlash,
    this.onScanDataMatrix,
    this.scanPayload,
    this.recalledProductNames,
    this.ansmLastRappel,
    this.cisArretCommercialisation,
    this.arretCommercialisationByCis,
    this.tauxRemboursementByCis,
    this.getVocUrlsForItem,
    this.onOpenUrl,
    this.barBottomY,
    this.barTopY,
    this.rightMargin,
  });

  /// Au clic sur "Espace pro" (catalogue) : affiche la fenêtre de connexion (lab + identifiants).
  final void Function(BuildContext context, String url, String labName, String? iconUrl)? onOpenEspacePro;
  /// Quand un labo avec catalogue (col. G) est sélectionné : ouvre le PDF (ou mode recherche).
  final void Function(BuildContext context, String pdfUrl, String labName, bool searchMode)? onOpenCataloguePdf;
  /// Télécharger le PDF (ouvre l’URL dans le navigateur). Si null, le bouton « Télécharger PDF » ouvre le PDF dans l’app.
  final VoidCallback? onDownloadCataloguePdf;
  /// Afficher le panneau catalogue sous la barre (uniquement après clic sur le badge Catalogue).
  final bool showCataloguePanel;
  /// Appelé au clic sur le badge Catalogue : affiche le panneau sous la barre.
  final VoidCallback? onOpenCataloguePanel;
  /// Afficher le panneau vidéo YouTube sous la barre.
  final bool showYouTubePanel;
  /// URL YouTube à afficher.
  final String? youtubeVideoUrl;
  /// Appelé au clic sur un pill YouTube : affiche la vidéo sous la barre.
  final void Function(String youtubeUrl)? onOpenYouTubeVideo;
  /// Ferme le panneau vidéo YouTube.
  final VoidCallback? onCloseYouTubePanel;
  /// Afficher le panneau vidéo thérapeutique (feuille videos) sous la barre.
  final bool showTherapeuticVideoPanel;
  /// URL de la vidéo thérapeutique à afficher.
  final String? therapeuticVideoUrl;
  /// Au clic sur le pill "video" (ligne 2 BDM) : affiche le panneau avec la vidéo.
  final void Function(String url)? onOpenTherapeuticVideo;
  /// Ferme le panneau vidéo thérapeutique.
  final VoidCallback? onCloseTherapeuticVideo;
  /// CIP13 (chiffres) → URL vidéo (feuille videos). Pour afficher le pill "video" en ligne 2.
  final Map<String, String>? videosByCip13;
  /// Afficher le panneau Flash info Pharmaradio sous la barre (au clic sur le résultat Pharmaradio).
  final bool showPharmaradioFlashPanel;
  /// Ouvre le panneau Flash info Pharmaradio.
  final VoidCallback? onOpenPharmaradioFlash;
  /// Ferme le panneau Flash info Pharmaradio.
  final VoidCallback? onClosePharmaradioFlash;
  /// Scan DataMatrix : (cip13, payload expiration/lot/série) → on vide le champ et on injecte le résultat.
  final void Function(String cip13, Gs1ScanPayload? payload)? onScanDataMatrix;
  /// Payload du dernier scan GS1 pour affichage expiration/lot/n° série en ligne 1.
  final Gs1ScanPayload? scanPayload;
  /// Noms normalisés des produits en rappel ANSM (alerte en rouge italique en ligne 2).
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : date en ligne 2, alerte ligne 4 si < 15 jours.
  final AnsmRappelItem? ansmLastRappel;
  /// CIS avec « arrêt de commercialisation » (CIS_CIP_Dispo_Spec) — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date + URL pour le badge « arrêt de commercialisation » (clic → ouvrir URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// CIS → taux de remboursement (ex. "65 %") pour « plus d'infos ».
  final Map<String, String>? tauxRemboursementByCis;
  /// Pour chaque résultat BDM, retourne (url fiche patient VOC, url fiche pro VOC) si le libellé contient un médicament VOC.
  final (String?, String?)? Function(SearchResult)? getVocUrlsForItem;
  /// Ouverture d’une URL (badges, liens). Si fourni, utilisé pour ouvrir les PDF sous la barre au lieu du navigateur.
  final void Function(String url)? onOpenUrl;
  /// Ordinate Y du bas de la barre (coords écran) pour ouvrir le menu hamburger / filtres sous la barre.
  final double? barBottomY;
  /// Ordinate Y du haut de la barre (coords écran). Si non null, le menu s'aligne verticalement avec la barre.
  final double? barTopY;
  /// Marge droite (px) : le menu est aligné à droite avec la barre (bord droit = écran - rightMargin).
  final double? rightMargin;

  final bool expanded;
  /// Barre d’infos (DGS-Urgent, ANSM, etc.) : true = déployée, false = repliée
  final bool infoBarExpanded;
  final VoidCallback? onToggleInfoBar;
  final double barWidth;

  final TextEditingController searchController;
  final FocusNode searchFocus;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onTapInside;
  final VoidCallback onToggleWindow;
  /// Soumission (Enter) : lance la recherche immédiatement.
  final ValueChanged<String>? onSearchSubmit;
  /// Survol du bouton filtre (pour réduire badge filtre + hamburger de 15 %).
  final bool filterHovered;
  final ValueChanged<bool>? onFilterHoverChange;

  final SearchResult? selectedResult;
  final VoidCallback? onOpenSelected;
  final Map<String, List<String>>? statutsByCis;
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  final Map<String, Generique2026Info>? generiques2026ByCis;
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  final Map<String, String>? generiques2026DciToGenericName;
  final Set<String>? generiques2026CisSet;
  final Map<String, String>? biosimilairesInfoByCip;
  final Map<String, String>? compositionByCis;
  /// fic03spe ANSM (CIS_CIP8 → "R"|"G") pour badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  final Map<String, String>? cip13ToFic03Status;
  /// CIS → "colD : colE pour colF" (CIS_COMPO_bdpm) pour modale « + d'infos ».
  final Map<String, String>? compositionBdpmByCis;
  /// CIP13 hospitaliers — badge « non remboursé » si BDM hors liste et sans taux.
  final Set<String>? hospitalCip13Set;

  final GlobalKey<HamburgerMenuState>? menuPopupKey;
  final VoidCallback? onOpenOffibox;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final VoidCallback? onShowAbout;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onOpenGoogleAgenda;
  /// Connexion OAuth Google Calendar (Windows/Desktop). Null si non disponible.
  final VoidCallback? onConnectGoogleAgenda;
  final bool isGoogleConnected;
  /// ESC dans la barre de recherche → refermer la barre (ex. fermer avec Échap).
  final VoidCallback? onEscape;
  /// Ouvre le panneau « Boîte à idées » sous la barre.
  final VoidCallback? onOpenIdBox;
  /// Items de la barre d’infos (si null, liste par défaut utilisée).
  final List<TickerItem>? infoBarItems;
  /// Bouton menu filtre tout à gauche de la barre d’infos.
  final Widget? leadingFilterButton;
  /// Version affichée dans le tooltip du logo (ex. 1.0.1).
  final String appVersion;

  static const List<TickerItem> _defaultInfoBarItems = [
    (label: 'DGS-Urgent', url: 'https://sante.gouv.fr/professionnels/article/dgs-urgent', tooltip: 'Cliquer pour plus d\'infos', icon: TickerItemIcon.danger, isAnsm: false, isDgs: true, colorOverride: null),
    (label: 'Info médicament (ANSM)', url: 'https://ansm.sante.fr/', tooltip: 'Cliquer pour plus d\'infos', icon: TickerItemIcon.none, isAnsm: true, isDgs: false, colorOverride: const Color(0xFF42A5F5)),
    (label: 'Actualités', url: 'https://www.who.int/fr/campaigns', tooltip: null, icon: TickerItemIcon.none, isAnsm: false, isDgs: false, colorOverride: const Color(0xFF37474F)),
  ];

  static const double _gapLogoMenu = 4;
  /// Marge à droite pour que le bloc hamburger + logo ne soit pas collé au bord.
  static const double _rightBlockPadding = 8;
  /// Largeur réservée à droite (logo + hamburger + marges).
  static double get _logoAndMenuWidth =>
      OffiboxWindowUI.pillSize + _gapLogoMenu + OffiboxWindowUI.menuButtonSize + _rightBlockPadding;
  /// Largeur fixe de la zone du bouton filtre (gauche) — même base que le bouton menu + marge.
  static double get filterButtonZoneWidth => OffiboxWindowUI.menuButtonSize + 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // 🔑 empêche les débordements
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (expanded) ...[
          SizedBox(
            width: barWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: infoBarExpanded
                            ? OffiboxInfoBar(
                                key: const ValueKey<bool>(true),
                                visible: true,
                                width: constraints.maxWidth,
                                items: infoBarItems ?? _defaultInfoBarItems,
                                value: infoBarExpanded,
                                onChanged: onToggleInfoBar != null
                                    ? (_) => onToggleInfoBar!()
                                    : null,
                              )
                            : OffiboxInfoBar(
                                key: const ValueKey<bool>(false),
                                visible: true,
                                width: constraints.maxWidth,
                                items: infoBarItems ?? _defaultInfoBarItems,
                                value: false,
                                onChanged: onToggleInfoBar != null
                                    ? (_) => onToggleInfoBar!()
                                    : null,
                              ),
                      );
                    },
                  ),
                ),
                if (selectedResult != null && onEscape != null) ...[
                  const SizedBox(width: 8),
                  _CloseBarButton(onPressed: onEscape!),
                ],
              ],
            ),
          ),
          if (infoBarExpanded) const SizedBox(height: 6),
        ],
        SizedBox(
          width: barWidth,
          child: Stack(
            alignment: Alignment.centerRight,
            clipBehavior: Clip.none,
            children: [
              if (!expanded)
                const SizedBox(height: OffiboxWindowUI.barHeight, width: double.infinity),
              SizedBox(
                width: barWidth,
                child: FloatingSearchBar(
              expanded: expanded,
              textController: searchController,
              focusNode: searchFocus,
              onChanged: onSearchChanged,
              onTapInside: onTapInside,
              onSubmit: onSearchSubmit,
              onEscape: onEscape,
              onFilterHoverChange: onFilterHoverChange,
              selectedResult: selectedResult,
              onOpenSelected: onOpenSelected,
              statutsByCis: statutsByCis,
              ansmStatutsByCis: ansmStatutsByCis,
              generiques2026ByCis: generiques2026ByCis,
              generiques2026PrincepsKeyToGenericName: generiques2026PrincepsKeyToGenericName,
              generiques2026DciToGenericName: generiques2026DciToGenericName,
              generiques2026CisSet: generiques2026CisSet,
              biosimilairesInfoByCip: biosimilairesInfoByCip,
              compositionBdpmByCis: compositionBdpmByCis,
              hospitalCip13Set: hospitalCip13Set,
              menuMinTopY: barBottomY != null ? barBottomY! + 8 : null,
              rightReservedWidth: _logoAndMenuWidth + 6,
              leftReservedWidth: filterButtonZoneWidth,
              onOpenEspacePro: onOpenEspacePro,
              onOpenCataloguePanel: onOpenCataloguePanel,
              onOpenYouTubeVideo: onOpenYouTubeVideo,
              onOpenTherapeuticVideo: onOpenTherapeuticVideo,
              videosByCip13: videosByCip13,
              onOpenPharmaradioFlash: onOpenPharmaradioFlash,
              leadingMenuButton: expanded ? leadingFilterButton : null,
              onScanDataMatrix: onScanDataMatrix,
              scanPayload: scanPayload,
              recalledProductNames: recalledProductNames,
              ansmLastRappel: ansmLastRappel,
              cisArretCommercialisation: cisArretCommercialisation,
              arretCommercialisationByCis: arretCommercialisationByCis,
              tauxRemboursementByCis: tauxRemboursementByCis,
              getVocUrlsForItem: getVocUrlsForItem,
              onOpenUrl: onOpenUrl,
            ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: _rightBlockPadding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (expanded &&
                          menuPopupKey != null &&
                          onOpenOffibox != null &&
                          onMinimize != null &&
                          onClose != null) ...[
                        Theme(
                          data: Theme.of(context).copyWith(
                            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Spinnaker'),
                            popupMenuTheme: PopupMenuThemeData(
                              textStyle: const TextStyle(fontFamily: 'Spinnaker', fontSize: 13),
                            ),
                          ),
                          child: HamburgerMenu(
                            popupKey: menuPopupKey,
                            onOpenOffibox: onOpenOffibox!,
                            onMinimize: onMinimize!,
                            onClose: onClose!,
                            onShowAbout: onShowAbout,
                            onShowShortcuts: onShowShortcuts,
                            onOpenGoogleAgenda: onOpenGoogleAgenda,
                            onConnectGoogleAgenda: onConnectGoogleAgenda,
                            onOpenIdBox: onOpenIdBox,
                            isGoogleConnected: isGoogleConnected,
                            menuOffsetDy: 0,
                            barWidth: barWidth,
                            barBottomY: barBottomY,
                            barTopY: barTopY,
                            rightMargin: rightMargin,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Tooltip(
                        message: 'Version $appVersion',
                        child: OffiboxPill(
                          onTap: onToggleWindow,
                          onSecondaryTap: (expanded &&
                                  menuPopupKey != null &&
                                  onOpenOffibox != null &&
                                  onMinimize != null &&
                                  onClose != null)
                              ? () => menuPopupKey!.currentState?.openMenu()
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
        if (showCataloguePanel &&
            selectedResult != null &&
            selectedResult!.source == SourceType.catalogue &&
            selectedResult!.catalogueUrl != null &&
            selectedResult!.catalogueUrl!.trim().isNotEmpty &&
            onOpenCataloguePdf != null) ...[
          Builder(
            builder: (context) {
              final result = selectedResult!;
              final catalogueUrl = result.catalogueUrl!.trim();
              final labName = result.label;
              return CataloguePanelBelowBar(
                cataloguePdfUrl: catalogueUrl,
                labName: labName,
                onDownloadPdf: onDownloadCataloguePdf ?? () {
                  if (onOpenCataloguePdf != null) {
                    onOpenCataloguePdf!(context, catalogueUrl, labName, false);
                  }
                },
                onSearchInCatalogue: () => onOpenCataloguePdf!(
                  context,
                  catalogueUrl,
                  labName,
                  true,
                ),
              );
            },
          ),
        ],
        if (showYouTubePanel &&
            youtubeVideoUrl != null &&
            youtubeVideoUrl!.trim().isNotEmpty &&
            onCloseYouTubePanel != null) ...[
          YouTubeVideoPanelBelowBar(
            youtubeUrl: youtubeVideoUrl!.trim(),
            barWidth: barWidth,
            onClose: onCloseYouTubePanel!,
          ),
        ],
        if (showTherapeuticVideoPanel &&
            therapeuticVideoUrl != null &&
            therapeuticVideoUrl!.trim().isNotEmpty &&
            onCloseTherapeuticVideo != null) ...[
          TherapeuticVideoPanelBelowBar(
            videoUrl: therapeuticVideoUrl!.trim(),
            barWidth: barWidth,
            sourceLogoAssetPath: 'assets/icons/logo societe francaise pneumologie.jpg',
            onClose: onCloseTherapeuticVideo!,
          ),
        ],
        if (showPharmaradioFlashPanel && onClosePharmaradioFlash != null) ...[
          PharmaradioFlashInfoPanelBelowBar(
            barWidth: barWidth,
            onClose: onClosePharmaradioFlash!,
          ),
        ],
      ],
    );
  }
}
