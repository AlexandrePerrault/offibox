import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/ui/results/result_tile.dart';
import 'package:offibox/utils/open_url.dart';

/// Ouvre une URL de manière sécurisée (utilisé par ResultTile). Déclenche onBeforeOpenLink.
Future<void> openUrlSafe(String url) async {
  final clean = url
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('\r', '')
      .replaceAll('\n', '')
      .trim();
  if (!clean.startsWith('http') && !clean.startsWith('tel:')) {
    debugPrint('⛔ URL invalide ignorée : [$clean]');
    return;
  }
  await openUrl(clean);
}

/// Couleur Offibox légère
const _offiboxTealLight = Color(0xFF5A9094);
const _kMaxInitialResults = 12;
const double _kCacheExtent = 800.0;

class ResultsPanel extends StatefulWidget {
  const ResultsPanel({
    super.key,
    required this.results,
    required this.scrollController,
    required this.query,
    required this.onOpen,
    required this.onOpenStatuts,
    this.onOpenSingle,
    this.onOpenUrlFromTile,
    this.statutsByCis,
    this.tauxRemboursementByCis,
    this.ansmStatutsByCis,
    this.generiques2026ByCis,
    this.generiques2026PrincepsKeyToGenericName,
    this.generiques2026DciToGenericName,
    this.generiques2026CisSet,
    this.biosimilairesInfoByCip,
    this.compositionByCis,
    this.compositionBdpmByCis,
    this.hospitalCip13Set,
    this.recalledProductNames,
    this.ansmLastRappel,
    this.videosByCip13,
    this.onOpenTherapeuticVideo,
    this.cisArretCommercialisation,
    this.arretCommercialisationByCis,
    this.getVocUrlsForItem,
    this.cip13ToFic03Status,
  });
  /// fic03spe ANSM : CIS_CIP8 → "R"|"G". Badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  final Map<String, String>? cip13ToFic03Status;

  final List<SearchResult> results;
  final ScrollController scrollController;
  final String query;
  final void Function(SearchResult item) onOpen;
  final void Function(String cip13, String label) onOpenStatuts;
  /// Si fourni, appelé au clic quand un seul résultat (accès direct RCP / e-pansement).
  final void Function(SearchResult item)? onOpenSingle;
  /// Si fourni, appelé au clic sur un lien dans un résultat (ex. badge ANSM) : injecte d’abord le résultat, n’ouvre pas l’URL.
  /// Une fois le résultat affiché dans la barre, les badges ouvrent l’URL via onOpenUrl de la vue sélectionnée.
  final void Function(SearchResult item, String url)? onOpenUrlFromTile;
  /// CIS → liste des statuts (col B CSV) pour badge "plus d'infos".
  final Map<String, List<String>>? statutsByCis;
  /// CIS → taux de remboursement affichable (ex. "65 %") pour « plus d'infos ».
  final Map<String, String>? tauxRemboursementByCis;
  /// CIS → info statut ANSM (source : fichiers-medicaments/statutsANSM.csv).
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  /// Génériques 2026 (CSV) : badge "générique de X" et "générique : Y" en ligne 2.
  final Map<String, Generique2026Info>? generiques2026ByCis;
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  final Map<String, String>? generiques2026DciToGenericName;
  final Set<String>? generiques2026CisSet;
  final Map<String, String>? biosimilairesInfoByCip;
  final Map<String, String>? compositionByCis;
  /// CIS → "colD : colE pour colF" (CIS_COMPO_bdpm) pour modale « + d'infos ».
  final Map<String, String>? compositionBdpmByCis;
  /// CIP13 (chiffres) hospitaliers — badge « non remboursé » si BDM hors liste et sans taux (col I CIS_CIP_bdpm).
  final Set<String>? hospitalCip13Set;
  /// Noms normalisés des produits en rappel ANSM (alerte en rouge italique en ligne 2).
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : date en ligne 2, alerte ligne 4 si < 15 jours.
  final AnsmRappelItem? ansmLastRappel;
  /// CIP13 (chiffres) → URL vidéo (feuille videos). Pour pill "video" en ligne 2 BDM.
  final Map<String, String>? videosByCip13;
  /// Au clic sur le pill "video" : affiche le panneau vidéo thérapeutique sous la barre.
  final void Function(String url)? onOpenTherapeuticVideo;
  /// CIS avec « arrêt de commercialisation » (CIS_CIP_Dispo_Spec) — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date + URL pour le badge « arrêt de commercialisation » (clic → ouvrir URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// Pour chaque résultat BDM, retourne (url fiche patient VOC, url fiche pro VOC) si le libellé contient un médicament VOC.
  final (String?, String?)? Function(SearchResult)? getVocUrlsForItem;

  @override
  State<ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends State<ResultsPanel> {
  bool _showAll = false;

  @override
  void didUpdateWidget(ResultsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.results.length != widget.results.length) {
      _showAll = false; // reset quand la recherche change
    }
  }

  static List<String> _statutsForCis(
    Map<String, List<String>>? map,
    String? cis,
  ) {
    if (map == null || cis == null || cis.isEmpty) return const [];
    final key = cis.replaceAll(RegExp(r'\D'), '').trim();
    return map[key] ?? const [];
  }

  static String? _tauxRemboursementForCis(Map<String, String>? map, String? cis) {
    if (map == null || cis == null || cis.isEmpty) return null;
    final key = cis.replaceAll(RegExp(r'\D'), '').trim();
    return map[key];
  }

  @override
  Widget build(BuildContext context) {
    final isSingleResult = widget.results.length == 1;
    final totalCount = widget.results.length;
    final displayCount = _showAll ? totalCount : totalCount.clamp(0, _kMaxInitialResults);
    final hasMore = totalCount > _kMaxInitialResults && !_showAll;
    final itemCount = displayCount + (hasMore ? 1 : 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          border: Border.all(
            color: _offiboxTealLight.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Scrollbar(
          controller: widget.scrollController,
          thumbVisibility: totalCount > 5,
          radius: const Radius.circular(4),
          child: ListView.builder(
              key: ValueKey('${widget.results.length}_$_showAll'),
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              cacheExtent: _kCacheExtent,
              addRepaintBoundaries: true,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (hasMore && index == displayCount) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8F9),
                      border: Border(
                        top: BorderSide(
                          color: _offiboxTealLight.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: resultTileVerticalPadding,
                        horizontal: resultTileHorizontalPadding,
                      ),
                      child: InkWell(
                        onTap: () => setState(() => _showAll = true),
                        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Afficher plus (${totalCount - _kMaxInitialResults} résultat${totalCount - _kMaxInitialResults > 1 ? 's' : ''})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: OffiboxColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final item = widget.results[index];
                final vocUrls = widget.getVocUrlsForItem?.call(item);
                final statutsForCis = _statutsForCis(widget.statutsByCis, item.cis);
                final tauxRemboursement = _tauxRemboursementForCis(widget.tauxRemboursementByCis, item.cis);
                final isAlternate = index.isOdd;
                final tileKey = ValueKey<String>(
                  '${item.source.name}_${item.cip13 ?? ""}_${item.cis ?? ""}_${item.labelRaw}',
                );
                return RepaintBoundary(
                  child: Container(
                    color: isAlternate
                        ? const Color(0xFFF7F8F9)
                        : Colors.white,
                    child: ResultTile(
                      key: tileKey,
                      item: item,
                      label: ResultLabelHelper.displayLabel(item),
                      query: widget.query,
                      hasNsfpDate: ResultLabelHelper.hasNsfpDate(item),
                      isSingleResult: isSingleResult,
                      animationIndex: index,
                      statutsForCis: statutsForCis,
                      tauxRemboursement: tauxRemboursement,
                      ansmStatutsByCis: widget.ansmStatutsByCis,
                      generiques2026ByCis: widget.generiques2026ByCis,
                      generiques2026PrincepsKeyToGenericName: widget.generiques2026PrincepsKeyToGenericName,
                      generiques2026DciToGenericName: widget.generiques2026DciToGenericName,
                      generiques2026CisSet: widget.generiques2026CisSet,
                      biosimilairesInfoByCip: widget.biosimilairesInfoByCip,
                      compositionBdpmByCis: widget.compositionBdpmByCis,
                      hospitalCip13Set: widget.hospitalCip13Set,
                      recalledProductNames: widget.recalledProductNames,
                      ansmLastRappel: widget.ansmLastRappel,
                      videosByCip13: widget.videosByCip13,
                      onOpenTherapeuticVideo: widget.onOpenTherapeuticVideo,
                      cisArretCommercialisation: widget.cisArretCommercialisation,
                      arretCommercialisationByCis: widget.arretCommercialisationByCis,
                      cip13ToFic03Status: widget.cip13ToFic03Status,
                      vocPatientUrl: vocUrls?.$1,
                      vocProUrl: vocUrls?.$2,
                      onOpen: () {
                        if (isSingleResult && widget.onOpenSingle != null) {
                          widget.onOpenSingle!(item);
                        } else {
                          widget.onOpen(item);
                        }
                      },
                      onOpenUrl: widget.onOpenUrlFromTile != null
                          ? (url) => widget.onOpenUrlFromTile!(item, url)
                          : openUrlSafe,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    );
  }
}
