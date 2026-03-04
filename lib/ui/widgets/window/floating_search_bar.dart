import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/ui/results/selected_result_view.dart';
import 'package:offibox/ui/widgets/search_bar_filter_button.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/utils/scan_controller.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';

class _SearchFieldWithOffiboxPlaceholder extends StatefulWidget {
  final bool expanded;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;
  final VoidCallback? onEscape;

  const _SearchFieldWithOffiboxPlaceholder({
    super.key,
    required this.expanded,
    required this.controller,
    required this.focusNode,
    this.onChanged,
    this.onSubmit,
    this.onEscape,
  });

  @override
  State<_SearchFieldWithOffiboxPlaceholder> createState() =>
      _SearchFieldWithOffiboxPlaceholderState();
}

class _SearchFieldWithOffiboxPlaceholderState
    extends State<_SearchFieldWithOffiboxPlaceholder> {
  bool _hidePlaceholder = false;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.controller.text.length;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _SearchFieldWithOffiboxPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastLength = widget.controller.text.length;
    }
    if (widget.expanded && !oldWidget.expanded) {
      _hidePlaceholder = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final len = widget.controller.text.length;
    if (len == 0 && _lastLength > 0) {
      setState(() => _hidePlaceholder = true);
    }
    _lastLength = len;
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    if (value.isEmpty) {
      setState(() => _hidePlaceholder = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.controller.text.isEmpty;
    final bool showPlaceholder =
        widget.expanded && widget.controller.text.isEmpty && !_hidePlaceholder;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        widget.focusNode.requestFocus();
        if (isEmpty) {
          setState(() => _hidePlaceholder = true);
        }
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _EscapeSearchIntent(),
          SingleActivator(LogicalKeyboardKey.keyQ, control: true): _EscapeSearchIntent(),
        },
        child: Actions(
          actions: {
            _EscapeSearchIntent: CallbackAction<_EscapeSearchIntent>(
              onInvoke: (_) {
                widget.onEscape?.call();
                return null;
              },
            ),
          },
          child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: _onChanged,
            onSubmitted: widget.onSubmit,
            onTap: () {
              setState(() => _hidePlaceholder = true);
            },
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Spinnaker',
              color: Colors.black87,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showPlaceholder ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: showPlaceholder ? Offset.zero : const Offset(0.06, 0),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontFamily: 'Spinnaker',
          ),
          children: [
            const TextSpan(text: 'Rechercher sur '),

            /// 🟦 Logo Offibox — même couleur que l’aspect transparent de la barre
            TextSpan(
              text: 'Offi',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Spinnaker',
                color: OffiboxColors.primary,
              ),
            ),
            TextSpan(
              text: 'box',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Spinnaker',
                color: Colors.grey.shade600,
              ),
            ),
            const TextSpan(text: ' (CIP, DCI, labos, législation, '),

            /// 📷 QR
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.qr_code,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
            ),
            const TextSpan(text: ')'),

            /// 🔍 Icône recherche à droite du texte (10 % plus grande qu’avant : 20)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.search,
                  size: 20,
                  color: OffiboxColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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

class _EscapeSearchIntent extends Intent {
  const _EscapeSearchIntent();
}

List<String> _statutsForCis(Map<String, List<String>>? map, String? cis) {
  if (map == null || cis == null || cis.isEmpty) return const [];
  final key = cis.replaceAll(RegExp(r'\D'), '').trim();
  return map[key] ?? const [];
}

String? _tauxRemboursementForCis(Map<String, String>? map, String? cis) {
  if (map == null || cis == null || cis.isEmpty) return null;
  final key = cis.replaceAll(RegExp(r'\D'), '').trim();
  return map[key];
}

class FloatingSearchBar extends ConsumerStatefulWidget {
  const FloatingSearchBar({
    super.key,
    required this.expanded,
    required this.textController,
    required this.focusNode,
    required this.onChanged,
    required this.onTapInside,
    required this.selectedResult,
    required this.onOpenSelected,
    this.scanController,
    this.onScanDataMatrix,
    this.onScanMutuelleQr,
    this.onEscape,
    this.onSubmit,
    this.onFilterHoverChange,
  this.statutsByCis,
  this.ansmStatutsByCis,
  this.generiques2026ByCis,
  this.generiques2026PrincepsKeyToGenericName,
  this.generiques2026DciToGenericName,
  this.generiques2026CisSet,
  this.cip13ToFic03Status,
  this.biosimilairesInfoByCip,
  this.compositionByCis,
  this.compositionBdpmByCis,
  this.hospitalCip13Set,
  this.menuMinTopY,
  this.rightReservedWidth = 0,
  this.leftReservedWidth = 0,
  this.onOpenEspacePro,
  this.onOpenCataloguePanel,
  this.onOpenYouTubeVideo,
  this.onOpenTherapeuticVideo,
  this.videosByCip13,
  this.onOpenPharmaradioFlash,
  this.leadingMenuButton,
  this.scanPayload,
  this.recalledProductNames,
    this.ansmLastRappel,
    this.rappelForLine3Badge,
    this.cisArretCommercialisation,
  this.arretCommercialisationByCis,
  this.tauxRemboursementByCis,
  this.getVocUrlsForItem,
  this.onOpenUrl,
});

  final bool expanded;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTapInside;
  /// Appelé à la soumission (Enter) pour lancer la recherche immédiatement.
  final ValueChanged<String>? onSubmit;
  /// Appelé quand le survol du bouton filtre change (pour réduire aussi le badge hamburger).
  final ValueChanged<bool>? onFilterHoverChange;

  final SearchResult? selectedResult;
  final VoidCallback? onEscape;
  final VoidCallback? onOpenSelected;
  final ScanController? scanController;
  final void Function(String cip13, Gs1ScanPayload? payload)? onScanDataMatrix;
  /// QR mutuelle (carte Vitale) : code préfectoral 8 chiffres → sélectionne la mutuelle et affiche son libellé.
  final void Function(String codePrefectoral)? onScanMutuelleQr;
  final Map<String, List<String>>? statutsByCis;
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  final Map<String, Generique2026Info>? generiques2026ByCis;
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  final Map<String, String>? generiques2026DciToGenericName;
  final Set<String>? generiques2026CisSet;
  final Map<String, String>? cip13ToFic03Status;
  final Map<String, String>? biosimilairesInfoByCip;
  final Map<String, String>? compositionByCis;
  /// CIS → "colD : colE pour colF" (CIS_COMPO_bdpm) pour modale « + d'infos ».
  final Map<String, String>? compositionBdpmByCis;
  /// CIP13 hospitaliers — badge « non remboursé » si BDM hors liste et sans taux.
  final Set<String>? hospitalCip13Set;
  /// Y min (écran) pour ouvrir le panneau filtre sous la barre. Si non null, le filtre est forcé sous la barre.
  final double? menuMinTopY;
  final double rightReservedWidth;
  /// Largeur fixe de la zone du bouton filtre (gauche), pour la bloquer.
  final double leftReservedWidth;
  final void Function(BuildContext context, String url, String labName, String? iconUrl)? onOpenEspacePro;
  final VoidCallback? onOpenCataloguePanel;
  final void Function(String youtubeUrl)? onOpenYouTubeVideo;
  /// Au clic sur le pill "video" (ligne 2 BDM) : affiche le panneau vidéo thérapeutique.
  final void Function(String url)? onOpenTherapeuticVideo;
  /// CIP13 (chiffres) → URL vidéo (feuille videos). Pour pill "video" en ligne 2.
  final Map<String, String>? videosByCip13;
  /// Ouvre le panneau Flash info Pharmaradio sous la barre (résultat Pharmaradio).
  final VoidCallback? onOpenPharmaradioFlash;
  /// Bouton menu (hamburger) affiché à gauche de la barre quand elle est déployée.
  final Widget? leadingMenuButton;
  /// Payload du dernier scan GS1 (expiration, lot, n° série) pour affichage en ligne 1 du résultat injecté.
  final Gs1ScanPayload? scanPayload;
  /// Noms normalisés des produits en rappel ANSM (alerte « produit concerné par un rappel de lot N° » en rouge italique).
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : date en ligne 2, alerte ligne 4 si < 15 jours.
  final AnsmRappelItem? ansmLastRappel;
  /// Rappel correspondant au résultat sélectionné (badge ligne 3 « rappel de produit + date »).
  final AnsmRappelItem? rappelForLine3Badge;
  /// CIS avec « arrêt de commercialisation » (CIS_CIP_Dispo_Spec) — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date + URL pour le badge « arrêt de commercialisation » (clic → ouvrir URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// CIS → taux de remboursement (ex. "65 %") pour « plus d'infos ».
  final Map<String, String>? tauxRemboursementByCis;
  /// Pour chaque résultat BDM, retourne (url fiche patient VOC, url fiche pro VOC) si le libellé contient un médicament VOC.
  final (String?, String?)? Function(SearchResult)? getVocUrlsForItem;
  /// Ouverture d’une URL (ex. au clic sur un badge). Si non fourni, utilise openUrl. Permet d’ouvrir les PDF sous la barre.
  final void Function(String url)? onOpenUrl;

  @override
  ConsumerState<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends ConsumerState<FloatingSearchBar> {
  static const double _barHeight = OffiboxWindowUI.barHeight;
  static const double _barHeightExpanded = OffiboxWindowUI.barHeightExpanded;
  static const double _borderRadius = OffiboxWindowUI.borderRadius;

  bool _filterHovered = false;

  @override
  Widget build(BuildContext context) {
    final scan = widget.scanController ?? ScanController();

    if (!widget.expanded) return const IgnorePointer(child: SizedBox.shrink());

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final isExpandedWithResult = widget.selectedResult != null;
        final selected = widget.selectedResult;
        // Pansements (DM) / Codes actes : pas de ligne 2 → hauteur réduite comme outils métier / sites web / catalogues
        final isSingleLineSource = selected != null &&
            (selected.source == SourceType.keyword ||
                selected.source == SourceType.siteWeb ||
                selected.source == SourceType.catalogue ||
                selected.source == SourceType.codesActes ||
                selected.source == SourceType.dm);
        // Hauteur selon le nombre de lignes (2, 3 ou 4) pour les médicaments.
        double expandedHeight = _barHeightExpanded;
        if (selected != null && !isSingleLineSource) {
          final hasLine3 = (selected.url != null && selected.url!.trim().isNotEmpty) ||
              (selected.meddisparUrl != null && selected.meddisparUrl!.trim().isNotEmpty);
          final hasBiosimRelation = selected.biosimilaireOf != null && selected.biosimilaireOf!.trim().isNotEmpty;
          final hasGenericRelation = selected.isGeneric == true ||
              (selected.princepsName != null && selected.princepsName!.trim().isNotEmpty) ||
              (selected.genericName != null && selected.genericName!.trim().isNotEmpty) ||
              selected.isBioreferent == true;
          final showBiosimLine = selected.source == SourceType.bdm && (hasBiosimRelation || hasGenericRelation);
          final lineCount = 2 + (hasLine3 ? 1 : 0) + (showBiosimLine ? 1 : 0);
          switch (lineCount) {
            case 2:
              expandedHeight = OffiboxWindowUI.barHeightExpanded;
              break;
            case 3:
              expandedHeight = OffiboxWindowUI.barHeightExpandedThreeLines;
              break;
            case 4:
              expandedHeight = OffiboxWindowUI.barHeightExpandedFourLines;
              break;
            default:
              expandedHeight = OffiboxWindowUI.barHeightExpanded;
          }
        }
        // Hauteur réduite (-20 %) quand la barre est déployée mais vide (aucun résultat sélectionné).
        final barHeight = isExpandedWithResult
            ? (isSingleLineSource ? OffiboxWindowUI.barHeightExpandedSingleLine : expandedHeight)
            : OffiboxWindowUI.barHeightExpandedEmpty;
        return ClipRRect(
          borderRadius: BorderRadius.circular(_borderRadius),
          child: SizedBox(
            width: maxW,
            child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints.tightFor(height: barHeight, width: maxW),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x22000000),
              blurRadius: isExpandedWithResult ? 24 : 14,
              offset: Offset(0, isExpandedWithResult ? 10 : 5),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0x15000000),
              blurRadius: isExpandedWithResult ? 14 : 8,
              offset: Offset(0, isExpandedWithResult ? 5 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadius),
                  ),
                ),
              ),
              Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
          if (widget.leadingMenuButton != null) ...[
            widget.leadingMenuButton!,
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: widget.leftReservedWidth > 0 ? widget.leftReservedWidth : null,
            child: MouseRegion(
              onEnter: (_) {
                setState(() => _filterHovered = true);
                widget.onFilterHoverChange?.call(true);
              },
              onExit: (_) {
                setState(() => _filterHovered = false);
                widget.onFilterHoverChange?.call(false);
              },
              child: AnimatedScale(
                scale: _filterHovered ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: SearchBarFilterButton(menuMinTopY: widget.menuMinTopY),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.selectedResult != null
                    ? GestureDetector(
                        key: const ValueKey('selected'),
                        onTap: widget.onTapInside,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final selected = widget.selectedResult;
                            if (selected == null) return const IgnorePointer(child: SizedBox.shrink());
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: SelectedResultView(
                                  item: selected,
                                  onOpenSelected: widget.onOpenSelected,
                                  onClose: widget.onTapInside,
                                  statutsForCis: _statutsForCis(widget.statutsByCis, selected.cis),
                                  tauxRemboursement: _tauxRemboursementForCis(widget.tauxRemboursementByCis, selected.cis),
                                  compositionLine: selected.source == SourceType.bdm && selected.cis != null && widget.compositionBdpmByCis != null
                                      ? widget.compositionBdpmByCis![selected.cis!.replaceAll(RegExp(r'\D'), '').trim()]
                                      : null,
                                  listes: [
                                    if (selected.liste1) 'Liste 1',
                                    if (selected.liste2) 'Liste 2',
                                  ],
                                  hospitalCip13Set: widget.hospitalCip13Set,
                                  ansmStatutsByCis: widget.ansmStatutsByCis,
                                  generiques2026ByCis: widget.generiques2026ByCis,
                                  generiques2026PrincepsKeyToGenericName: widget.generiques2026PrincepsKeyToGenericName,
                                  generiques2026DciToGenericName: widget.generiques2026DciToGenericName,
                                  generiques2026CisSet: widget.generiques2026CisSet,
                                  cip13ToFic03Status: widget.cip13ToFic03Status,
                                  biosimilairesInfoByCip: widget.biosimilairesInfoByCip,
                                  onOpenUrl: widget.onOpenUrl ?? openUrl,
                                  onOpenEspacePro: widget.onOpenEspacePro,
                                  onOpenCataloguePanel: widget.onOpenCataloguePanel,
                                  onOpenYouTubeVideo: widget.onOpenYouTubeVideo,
                                  onOpenTherapeuticVideo: widget.onOpenTherapeuticVideo,
                                  videosByCip13: widget.videosByCip13,
                                  onOpenPharmaradioFlash: widget.onOpenPharmaradioFlash,
                                  scanPayload: widget.scanPayload,
                                  recalledProductNames: widget.recalledProductNames,
                                  ansmLastRappel: widget.ansmLastRappel,
                                  rappelForLine3Badge: widget.rappelForLine3Badge,
                                  cisArretCommercialisation: widget.cisArretCommercialisation,
                                  arretCommercialisationByCis: widget.arretCommercialisationByCis,
                                  vocPatientUrl: () {
                                    final voc = widget.selectedResult != null ? widget.getVocUrlsForItem?.call(widget.selectedResult!) : null;
                                    return voc?.$1;
                                  }(),
                                  vocProUrl: () {
                                    final voc = widget.selectedResult != null ? widget.getVocUrlsForItem?.call(widget.selectedResult!) : null;
                                    return voc?.$2;
                                  }(),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : _SearchFieldWithOffiboxPlaceholder(
                        key: const ValueKey('search'),
                        expanded: widget.expanded,
                        controller: widget.textController,
                        focusNode: widget.focusNode,
                        onChanged: widget.onChanged,
                        onEscape: widget.onEscape,
                        onSubmit: (value) {
                          final result = scan.handle(
                            raw: value,
                            onSearch: widget.onChanged,
                            onScanDataMatrix: widget.onScanDataMatrix != null
                                ? (cip13, payload) {
                                    widget.textController.text = '';
                                    widget.onScanDataMatrix!(cip13, payload);
                                  }
                                : null,
                            onScanMutuelleQr: widget.onScanMutuelleQr != null
                                ? (code) {
                                    widget.textController.text = '';
                                    widget.onScanMutuelleQr!(code);
                                  }
                                : null,
                          );
                          if (result.isMutuelleQr) return;
                          if (!result.isDataMatrix) {
                            widget.onSubmit?.call(value);
                          } else if (result.cip13 != null && widget.onScanDataMatrix == null) {
                            widget.onSubmit?.call(result.cip13!);
                          }
                        },
                      ),
            ),
          ),

          // Quand un résultat est injecté : petit espace avant le bloc hamburger + logo. Quand aucun résultat : collé à la barre.
          if (widget.selectedResult != null) const SizedBox(width: 4),
          if (widget.rightReservedWidth > 0)
            SizedBox(width: widget.rightReservedWidth),
        ],
      ),
            ],
          ),
        ),
        ),
      ),
    );
      },
    );
  }
}

