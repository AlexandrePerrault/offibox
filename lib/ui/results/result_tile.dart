import 'package:flutter/material.dart';
import 'package:offibox/data/bdm_cip_quantite_loader.dart';
import 'package:offibox/data/bdpm_labels_loader.dart';
import 'package:offibox/utils/normalize.dart';
import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/ui/results/result_line_1.dart';
import 'package:offibox/ui/results/result_line_2_code.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';

/// Une ligne de résultat : label, codes, actions. Réduit la complexité de ResultsPanel.
class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.item,
    required this.label,
    required this.query,
    required this.hasNsfpDate,
    required this.isSingleResult,
    required this.animationIndex,
    required this.onOpen,
    required this.onOpenUrl,
    this.statutsForCis,
    this.tauxRemboursement,
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
    this.cip13ToFic03Status,
    this.vocPatientUrl,
    this.vocProUrl,
  });
  /// fic03spe ANSM (CIS_CIP8 → "R"|"G") pour badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  final Map<String, String>? cip13ToFic03Status;

  final SearchResult item;
  final String label;
  final String query;
  final bool hasNsfpDate;
  final bool isSingleResult;
  final int animationIndex;
  final VoidCallback onOpen;
  final void Function(String url) onOpenUrl;
  /// Statuts CIS (col B) pour badge "plus d'infos" sur la ligne 1.
  final List<String>? statutsForCis;
  /// Taux de remboursement (ex. "65 %") pour la modale « plus d'infos ».
  final String? tauxRemboursement;
  /// CIS → info statut ANSM (source : fichiers-medicaments/statutsANSM.csv).
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  /// Génériques 2026 : badge "générique de X" et "générique : Y" en ligne 2.
  final Map<String, Generique2026Info>? generiques2026ByCis;
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  final Map<String, String>? generiques2026DciToGenericName;
  final Set<String>? generiques2026CisSet;
  final Map<String, String>? biosimilairesInfoByCip;
  final Map<String, String>? compositionByCis;
  /// CIS → "colD : colE pour colF" (CIS_COMPO_bdpm) pour modale « + d'infos ».
  final Map<String, String>? compositionBdpmByCis;
  /// CIP13 (chiffres) hospitaliers (CIP hospitaliers.csv) — badge « non remboursé » si BDM hors liste et sans taux.
  final Set<String>? hospitalCip13Set;
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : alerte ligne 4 si rappel < 15 jours.
  final AnsmRappelItem? ansmLastRappel;
  /// CIP13 (chiffres) → URL vidéo (feuille videos). Pour pill "video" en ligne 2 BDM.
  final Map<String, String>? videosByCip13;
  /// Au clic sur le pill "video" : affiche le panneau vidéo thérapeutique sous la barre.
  final void Function(String url)? onOpenTherapeuticVideo;
  /// CIS avec « arrêt de commercialisation » (CIS_CIP_Dispo_Spec) — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date + URL pour le badge « arrêt de commercialisation » (clic → ouvrir URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// URL fiche VOC patient (OMÉDIT) — pill ligne 3 si BDM et libellé match.
  final String? vocPatientUrl;
  /// URL fiche VOC pro (OMÉDIT) — pill ligne 3 si BDM et libellé match.
  final String? vocProUrl;

  @override
  Widget build(BuildContext context) {
    final compositionLine = item.source == SourceType.bdm && item.cis != null && compositionBdpmByCis != null
        ? compositionBdpmByCis![item.cis!.replaceAll(RegExp(r'\D'), '').trim()]
        : null;
    final listes = <String>[
      if (item.liste1) 'Liste 1',
      if (item.liste2) 'Liste 2',
    ];
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _HoverableResult(
        enabled: true,
        child: ListTile(
          dense: !isSingleResult,
          visualDensity: isSingleResult
              ? VisualDensity.standard
              : const VisualDensity(vertical: -3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: resultTileHorizontalPadding,
            vertical: resultTileVerticalPadding / 2,
          ),
          onTap: onOpen,
          title: LayoutBuilder(
            builder: (context, constraints) {
              final column = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResultLine1(
                    item: item,
                    label: label,
                    hasNsfpDate: hasNsfpDate,
                    query: query,
                    onOpenUrl: onOpenUrl,
                    statutsForCis: statutsForCis,
                    tauxRemboursement: tauxRemboursement,
                    compositionLine: compositionLine,
                    listes: listes,
                    hospitalCip13Set: hospitalCip13Set,
                    generiques2026ByCis: generiques2026ByCis,
                    generiques2026PrincepsKeyToGenericName: generiques2026PrincepsKeyToGenericName,
                    cip13ToFic03Status: cip13ToFic03Status,
                  ),
                  const SizedBox(height: resultLineGap),
                  ResultLine2Code(
                    item: item,
                    onOpenUrl: onOpenUrl,
                    ansmStatutsByCis: ansmStatutsByCis,
                    generiques2026ByCis: generiques2026ByCis,
                    generiques2026PrincepsKeyToGenericName: generiques2026PrincepsKeyToGenericName,
                    generiques2026DciToGenericName: generiques2026DciToGenericName,
                    biosimilairesInfoByCip: biosimilairesInfoByCip,
                    recalledProductNames: recalledProductNames,
                    ansmLastRappel: ansmLastRappel,
                    cisArretCommercialisation: cisArretCommercialisation,
                    arretCommercialisationByCis: arretCommercialisationByCis,
                    statutsForCis: statutsForCis,
                    tauxRemboursement: tauxRemboursement,
                    compositionLine: compositionLine,
                    listes: listes,
                  ),
                  // Panneau de résultats : uniquement lignes 1 et 2 pour plus de clarté.
                  // Lignes 3 et 4 (Sources, biosimilaires, rappel) affichées dans la barre une fois le produit injecté (SelectedResultView).
                ],
              );
              // Si le titre est contraint en hauteur (ex. panneau étroit), rendre le contenu scrollable pour éviter RenderFlex overflow.
              final maxHeight = constraints.maxHeight;
              if (maxHeight.isFinite && maxHeight > 0) {
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: column,
                  ),
                );
              }
              return column;
            },
          ),
        ),
      ),
    );

    // Pas d'animation d'apparition pour éviter le lag
    return content;
  }
}

class _HoverableResult extends StatefulWidget {
  const _HoverableResult({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_HoverableResult> createState() => _HoverableResultState();
}

class _HoverableResultState extends State<_HoverableResult> {
  static const Color _offiboxTeal = Color(0xFF5A9094);
  final ValueNotifier<bool> _hovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _hovered,
              builder: (_, __) {
                final hovered = _hovered.value;
                return IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: hovered
                          ? _offiboxTeal.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
                      border: hovered
                          ? Border.all(
                              color: _offiboxTeal.withValues(alpha: 0.25),
                              width: 1,
                            )
                          : null,
                      boxShadow: hovered
                          ? [
                              BoxShadow(
                                color: _offiboxTeal.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Helpers pour construire le label d'affichage à partir d'un SearchResult.
/// Pour BDM : nom et dosage (format "nom dosage forme, conditionnement"), affiché en MAJUSCULES avec Spinnaker.
class ResultLabelHelper {
  static String displayLabel(SearchResult item) {
    // Outils métier et sites web : afficher le libellé col B (commentaire), pas le mot-clé col A.
    if (item.source == SourceType.keyword || item.source == SourceType.siteWeb) {
      final colB = (item.commentaire ?? item.label).trim();
      if (colB.isNotEmpty) return stripGuillemets(colB);
    }
    String displayLabel = item.label;
    if (item.source == SourceType.bdm) {
      final cip13 = item.cip13?.replaceAll(RegExp(r'\D'), '');
      final bdpmTxtLabel = cip13 != null && cip13.length == 13
          ? BdpmTxtLabelCache.instance.get(cip13)
          : null;
      if (bdpmTxtLabel != null && bdpmTxtLabel.trim().isNotEmpty && cip13 != null) {
        displayLabel = bdpmTxtLabel.trim();
      } else {
        final cached = BdmLibelleCache.instance.get(item.cip13);
        if (cached != null && cached.libelle.trim().isNotEmpty) {
          displayLabel = _stripLeadingCipFromLabel(cached.libelle.trim());
        } else {
          final raw = item.labelRaw.trim();
          if (raw.isNotEmpty) {
            displayLabel = _stripLeadingCipFromLabel(raw);
          } else {
            displayLabel = _stripLeadingCipFromLabel(displayLabel);
          }
        }
      }
      return stripGuillemets(displayLabel.trim().toUpperCase());
    }
    if (item.source == SourceType.amc) return 'Mutuelle ${stripGuillemets(displayLabel.trim())}';
    // 📘 LPP : afficher le libellé quand présent (recherche par code ou libellé)
    if (item.source == SourceType.lpp &&
        item.lppLibelle != null &&
        item.lppLibelle!.trim().isNotEmpty) {
      return stripGuillemets(item.lppLibelle!.trim());
    }
    return stripGuillemets(displayLabel.trim());
  }

  /// Retire en tête de chaîne un préfixe CIP (ex. "CIP : 3400930040935" ou "34009 300 409 3 5 : ").
  static String _stripLeadingCipFromLabel(String label) {
    return label.replaceFirst(
      RegExp(r'^\s*(?:CIP\s*:\s*)?(\d\s*){13}\s*:\s*', caseSensitive: false),
      '',
    ).trim();
  }

  /// Libellé BDM : nom du médicament (avant dosage) en majuscules. (Réservé pour usage futur.)
  static String formatBdmLibelle(String libelle, String dosage) {
    if (libelle.isEmpty) return libelle;
    int splitAt = -1;
    if (dosage.isNotEmpty) {
      final dosageNorm = dosage.replaceAll(RegExp(r'\s+'), ' ').trim();
      final dosageNoSpace = dosage.replaceAll(RegExp(r'\s+'), '');
      final idx1 = libelle.toLowerCase().indexOf(dosageNorm.toLowerCase());
      final idx2 = libelle.toLowerCase().indexOf(dosageNoSpace.toLowerCase());
      if (idx1 >= 0) splitAt = idx1;
      if (idx2 >= 0 && (splitAt < 0 || idx2 < splitAt)) splitAt = idx2;
    }
    if (splitAt < 0) {
      final match = RegExp(r'\s+\d+[\s,]*(mg|g|ml|µg|microgrammes?|pour cent|%|UI|u\.?a\.?h\.?)\b', caseSensitive: false).firstMatch(libelle);
      if (match != null) splitAt = match.start;
    }
    if (splitAt > 0) {
      final before = libelle.substring(0, splitAt).trim();
      final after = libelle.substring(splitAt).trim();
      return '${before.toUpperCase()} $after';
    }
    return libelle.toUpperCase();
  }

  static bool hasNsfpDate(SearchResult item) {
    return item.nsfpDate != null && item.nsfpDate!.trim().isNotEmpty;
  }
}
