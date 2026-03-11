import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/data/bdpm_labels_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/search/medicine_picto_registry.dart';
import 'package:offibox/ui/results/plus_infos_badge.dart';
import 'package:offibox/ui/results/result_line_2_code.dart';
import 'package:offibox/ui/spans/common_spans.dart';
import 'package:offibox/data/fic03spe_loader.dart';
import 'package:offibox/ui/spans/offibox_ui_helpers.dart';
import 'package:offibox/ui/spans/search_result_span_cache.dart';
import 'package:offibox/utils/normalize.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/offibox_tooltip.dart';

class ResultLine1 extends StatelessWidget {
  final SearchResult item;
  final String label;
  final String query;
  final bool hasNsfpDate;
  final void Function(String url) onOpenUrl;
  /// Statuts CIS (col B du CSV) pour ce résultat — si non vide, affiche badge "plus d'infos"
  final List<String>? statutsForCis;
  /// Taux de remboursement affichable (ex. "65 %") pour la modale « plus d'infos » (ligne 3).
  final String? tauxRemboursement;
  /// Composition BDPM "colD : colE pour colF" (CIS_COMPO_bdpm) pour la modale « plus d'infos » (ligne 1).
  final String? compositionLine;
  /// Listes (ex. ["Liste 1", "Liste 2"]) pour la modale « plus d'infos » (ligne 2).
  final List<String>? listes;
  /// CIP13 (chiffres) hospitaliers (CIP hospitaliers.csv) — si le produit n'est pas dedans et sans taux (col I CIS_CIP_bdpm), badge « non remboursé ».
  final Set<String>? hospitalCip13Set;
  /// Génériques 2026 (CIS → info) pour badge "Gé" en ligne 1.
  final Map<String, Generique2026Info>? generiques2026ByCis;
  /// Clé princeps → col A pour badge "Princeps" en ligne 1.
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  /// fic03spe ANSM (CIS_CIP8 → "R"|"G") : badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  final Map<String, String>? cip13ToFic03Status;
  /// Quand true (résultat injecté dans la barre), la ligne 1 est mise à l'échelle pour tenir sur une seule ligne.
  final bool scaleDownToFitLine1;

  const ResultLine1({
    super.key,
    required this.item,
    required this.label,
    required this.query,
    required this.hasNsfpDate,
    required this.onOpenUrl,
    this.statutsForCis,
    this.tauxRemboursement,
    this.compositionLine,
    this.listes,
    this.hospitalCip13Set,
    this.generiques2026ByCis,
    this.generiques2026PrincepsKeyToGenericName,
    this.cip13ToFic03Status,
    this.scaleDownToFitLine1 = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled =
        item.isInactive || item.hospitalOnly || item.isNsfpEffective;
    final bool isOrganisme =
        item.source == SourceType.amc || item.source == SourceType.amo;
    final cisKeyBdm = item.source == SourceType.bdm && item.cis != null
        ? item.cis!.replaceAll(RegExp(r'\D'), '').trim()
        : '';
    /// Statut fic03spe (R = Princeps, G = Générique) pour ce BDM ; prioritaire sur génériques 2026 pour les badges.
    final fic03Status = item.source == SourceType.bdm
        ? getFic03StatusForItem(item.cis, item.cip13, cip13ToFic03Status)
        : null;

    // Chemin rapide BDM : libellé déjà reconstruit (BdpmTxtLabelCache) → pas de highlight, clé sans query → moins de lag à la frappe.
    final cip13Clean = item.cip13?.replaceAll(RegExp(r'\D'), '');
    final useBdmFastPath = item.source == SourceType.bdm &&
        cip13Clean != null &&
        cip13Clean.length == 13 &&
        BdpmTxtLabelCache.instance.get(cip13Clean) != null;

    final cacheKey = useBdmFastPath
        ? 'bdm-fast-$cip13Clean-$cisKeyBdm-F$fic03Status-S${statutsForCis?.length ?? 0}-${tauxRemboursement ?? ''}-${compositionLine ?? ''}-${listes?.join('|') ?? ''}-H${hospitalCip13Set?.length ?? 0}-$isDisabled-$hasNsfpDate'
        : '${item.source}-${item.source == SourceType.lpp ? item.cip13 : item.cip13 ?? item.label}::${query.toLowerCase()}::${item.commentaire}::${statutsForCis?.join('|') ?? ''}::${tauxRemboursement ?? ''}::${compositionLine ?? ''}::${listes?.join('|') ?? ''}::H${hospitalCip13Set?.length ?? 0}::S${item.isStupefiant}::E${item.isException}::O${item.isOtc}::P${item.isPih}::H${item.hospitalOnly}::F$fic03Status${item.source == SourceType.dm ? '::${item.url ?? ''}' : ''}::scale$scaleDownToFitLine1';

    final cachedSpans = SearchResultSpanCache.get(cacheKey, () {
      final spans = <InlineSpan>[];

      if (useBdmFastPath) {
        _buildBdmFastPathSpans(
          spans: spans,
          label: label,
          query: query,
          isDisabled: isDisabled,
          fic03Status: fic03Status,
          item: item,
          statutsForCis: statutsForCis,
          tauxRemboursement: tauxRemboursement,
          compositionLine: compositionLine,
          listes: listes ?? const [],
          hospitalCip13Set: hospitalCip13Set,
          hasNsfpDate: hasNsfpDate,
          context: context,
          generiques2026ByCis: generiques2026ByCis,
          cisKeyBdm: cisKeyBdm,
        );
        return spans;
      }

      // ======================================================
      // 🧭 ICÔNE PRINCIPALE
      // ======================================================
      String? emoji;
      switch (item.source) {
        case SourceType.bdm:
          emoji = '💊';
          break;
        case SourceType.dm:
          emoji = null;
          break;
        case SourceType.lpp:
          emoji = null;
          break;
        case SourceType.veto:
          emoji = '🐾';
          break;
        case SourceType.catalogue:
          emoji = null;
          break;
        default:
          emoji = null;
      }

      if (emoji != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
      } else if (item.source == SourceType.dm) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Image.asset(
                'assets/icons/dm_bandage_beige.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                  color: OffiboxColors.primary,
                ),
              ),
            ),
          ),
        );
      }

      if (item.source == SourceType.bdm) {
        if (fic03Status == 'R') {
          spans.add(princepsSquareSpan());
          spans.add(const TextSpan(text: ' '));
        } else if (fic03Status == 'G' || item.isGeneric == true) {
          spans.add(geSquareSpanGreen());
          spans.add(const TextSpan(text: ' '));
        } else {
          final generique2026Info = (generiques2026ByCis != null && cisKeyBdm.isNotEmpty)
              ? generiques2026ByCis![cisKeyBdm]
              : null;
          if (generique2026Info != null && item.isGeneric != true) {
            spans.add(princepsSquareSpan());
            spans.add(const TextSpan(text: ' '));
          }
        }
      }

      // 🏭 Catalogues laboratoires — badge LABORATOIRE (common_spans) + nom + logo col B (tooltip = nom col 1), surbrillance recherche
      if (item.source == SourceType.catalogue) {
        spans.add(laboratoireSpan());
        spans.add(const TextSpan(text: ' '));
        spans.addAll(
          highlightText(
            context: context,
            text: label.trim(),
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          ),
        );
        if (item.iconUrl != null && item.iconUrl!.trim().isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          final labName = (item.laboratory.isEmpty ? item.label : item.laboratory).trim();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: logoWithTooltipZoom(
                tooltip: labName.isNotEmpty ? labName : 'Catalogue laboratoire',
                child: Container(
                  width: _labLine1IconBoxSize,
                  height: _labLine1IconBoxSize,
                  padding: const EdgeInsets.all((_labLine1IconBoxSize - _labLine1IconInnerSize) / 2),
                  decoration: _labLine1IconDecoration(),
                  child: Center(
                    child: _labIconWidget(item.iconUrl!, _labLine1IconInnerSize),
                  ),
                ),
              ),
            ),
          ),);
        }
        // Badge external link pour ouvrir l’URL catalogue (injecté ou en liste)
        if (item.url != null && item.url!.trim().isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SiteWebLinkExternalBadge(
                url: item.url!.trim(),
                onOpenUrl: onOpenUrl,
                useLabIconStyle: true,
              ),
            ),
          ),);
        }
        // Ligne 1 laboratoires : Tél (col C), Fax (col D), Mail (col E) — même taille icônes + contour 3D
        if (item.phone != null && item.phone!.trim().isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _wrapBadgeIfDisabled(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: _labLine1IconDecoration(color: const Color(0xFFF1F5F9)),
                  child: CodeBadgeWithCopy(
                    label: 'Tél',
                    value: item.phone!.replaceAll('"', '').replaceAll("'", ''),
                    tooltip: 'Copier le numéro',
                    leadingIcon: Icons.phone,
                    fontSize: 11,
                    leadingIconSize: _labLine1IconInnerSize,
                  ),
                ),
                isDisabled,
              ),
            ),
          ),);
        }
        if (item.fax != null && item.fax!.trim().isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _wrapBadgeIfDisabled(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: _labLine1IconDecoration(color: const Color(0xFFF1F5F9)),
                  child: CodeBadgeWithCopy(
                    label: 'Fax',
                    value: item.fax!.replaceAll('"', '').replaceAll("'", ''),
                    tooltip: 'Copier le fax',
                    leadingIcon: Icons.fax,
                    fontSize: 11,
                    leadingIconSize: _labLine1IconInnerSize,
                  ),
                ),
                isDisabled,
              ),
            ),
          ),);
        }
        if (item.email != null && item.email!.trim().isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          final email = item.email!.replaceAll('"', '').replaceAll("'", '');
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _wrapBadgeIfDisabled(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: _labLine1IconDecoration(color: const Color(0xFFF1F5F9)),
                  child: OffiboxTooltip(
                    message: 'Ouvrir le client mail',
                    child: InkWell(
                      onTap: () => openUrl('mailto:$email'),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, size: _labLine1IconInnerSize, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text('Mail : $email', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: email));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mail copié'), duration: Duration(milliseconds: 900), behavior: SnackBarBehavior.floating));
                            },
                            child: const Icon(Icons.copy, size: _labLine1IconInnerSize, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                isDisabled,
              ),
            ),
          ),);
        }
      }

      // Stupéfiant / Exception / OTC/Libre accès / PIH / HOP en ligne 1 — pour BDM ils sont ajoutés après la gélule (avant le libellé) plus bas
      if (item.source != SourceType.bdm) {
        if (item.isStupefiant == true) {
          spans.add(stupSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isException == true) {
          spans.add(exceptionSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isOtc == true) {
          spans.add(otcSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isPih == true) {
          spans.add(pihSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.hospitalOnly == true) {
          spans.add(hopSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
      }

      spans.addAll(buildMedicinePictos(item));

      // BDM : badges STUPS / EXCEPTION / SURV / OTC/Libre accès / PIH / HOP toujours après la gélule, avant le libellé (ligne 1).
        final cip13Digits = item.cip13?.replaceAll(RegExp(r'\D'), '');
        final bool showNrBadge = item.source == SourceType.bdm &&
            (tauxRemboursement == null || tauxRemboursement!.trim().isEmpty) &&
            (hospitalCip13Set != null && cip13Digits != null && cip13Digits.length == 13 && !hospitalCip13Set!.contains(cip13Digits));
      if (item.source == SourceType.bdm &&
          (item.isStupefiant == true ||
              item.isException == true ||
              item.isSurveillanceParticuliere == true ||
              item.isOtc == true ||
              showNrBadge ||
              item.isPih == true ||
              item.hospitalOnly == true)) {
        spans.add(const TextSpan(text: ' '));
        if (item.isStupefiant == true) {
          spans.add(stupSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isException == true) {
          spans.add(exceptionSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isSurveillanceParticuliere == true) {
          spans.add(surveillanceSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isOtc == true || showNrBadge) {
          spans.add(otcSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.isPih == true) {
          spans.add(pihSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
        if (item.hospitalOnly == true) {
          spans.add(hopSquareSpan());
          spans.add(const TextSpan(text: ' '));
        }
      }

      if (item.source == SourceType.amc) {
        spans.add(amcVitaleIconSpan());
        spans.add(const TextSpan(text: ' '));
        spans.add(amcMutSquareSpan());
        spans.add(const TextSpan(text: ' '));
      } else if (item.source == SourceType.amo) {
        spans.add(amcVitaleIconSpan());
        spans.add(const TextSpan(text: ' '));
        spans.add(amoMutSquareSpan());
        spans.add(const TextSpan(text: ' '));
      }

      // 📦 CERP — Catalogue / produits : texte + logo (si asset) + ouverture URL (si fournie)
      if (item.source == SourceType.cerp) {
        final url = item.catalogueUrl?.trim().isNotEmpty == true
            ? item.catalogueUrl!.trim()
            : item.url?.trim();
        final libelle = (item.label.isNotEmpty ? item.label : item.labelRaw).trim().toUpperCase();

        spans.add(const TextSpan(text: '📦 '));
        if (libelle.isNotEmpty) {
          final highlightSpans = highlightText(
            context: context,
            text: libelle,
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          );
          if (url != null && url.isNotEmpty) {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: () => onOpenUrl(url),
                borderRadius: BorderRadius.circular(4),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Spinnaker',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? Colors.grey.shade600 : Colors.black87,
                    ),
                    children: highlightSpans,
                  ),
                ),
              ),
            ),);
          } else {
            spans.addAll(highlightSpans);
          }
        }

        final iconPath = item.iconUrl?.trim();
        if (iconPath != null && iconPath.isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: logoWithTooltipZoom(
                tooltip: 'CERP',
                child: Container(
                  width: _labLine1IconBoxSize,
                  height: _labLine1IconBoxSize,
                  padding: const EdgeInsets.all((_labLine1IconBoxSize - _labLine1IconInnerSize) / 2),
                  decoration: _labLine1IconDecoration(),
                  child: Center(
                    child: _labIconWidget(iconPath, _labLine1IconInnerSize),
                  ),
                ),
              ),
            ),
          ),);
        }

        if (url != null && url.isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _SiteWebLinkExternalBadge(
              url: url,
              onOpenUrl: onOpenUrl,
              useLabIconStyle: true,
            ),
          ),);
        }
        return spans;
      }

      // 🏷️ Mots-clés — en liste : uniquement common span ; en barre : badge + libellé + logo + lien
      if (item.source == SourceType.keyword) {
        if (!scaleDownToFitLine1) {
          spans.add(keywordPlusAndOutilsMetierSpan());
          return spans;
        }
        final hasKeywordIcon = item.iconUrl != null && item.iconUrl!.trim().isNotEmpty;
        final urlColC = item.url?.trim();
        final libelleColB = (item.commentaire ?? item.label).trim().toUpperCase();

        spans.add(keywordPlusAndOutilsMetierSpan());
        spans.add(const TextSpan(text: ' '));
        if (libelleColB.isNotEmpty) {
          final highlightSpans = highlightText(
            context: context,
            text: libelleColB,
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          );
          if (urlColC != null && urlColC.isNotEmpty) {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: () => onOpenUrl(urlColC),
                borderRadius: BorderRadius.circular(4),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Spinnaker',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? Colors.grey.shade600 : Colors.black87,
                    ),
                    children: highlightSpans,
                  ),
                ),
              ),
            ),);
          } else {
            spans.addAll(highlightSpans);
          }
        }
        if (item.keywordAppearanceDate != null && item.keywordAppearanceDate!.trim().isNotEmpty) {
          final date = item.keywordAppearanceDate!.trim();
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: date,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'nouveau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Spinnaker',
                  ),
                ),
              ),
            ),
          ),);
        }
        if (hasKeywordIcon) {
          spans.add(const TextSpan(text: ' '));
          spans.add(keywordLogoWrappedSpan(
            iconAssetPath: item.iconUrl!.trim(),
            tooltip: 'Outils métier',
          ),);
        }
        if (urlColC != null && urlColC.isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _SiteWebLinkExternalBadge(
              url: urlColC,
              onOpenUrl: onOpenUrl,
            ),
          ),);
        }
      }

      // 📋 Codes actes pharmacie — ligne 1 : badge "Codes actes" + Code — Libellé — Tarif (surbrillance)
      if (item.source == SourceType.codesActes) {
        spans.add(codesActesBadgeSpan());
        spans.add(const TextSpan(text: ' '));
        final line1Text = (item.label).trim();
        if (line1Text.isNotEmpty) {
          final highlightSpans = highlightText(
            context: context,
            text: line1Text,
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          );
          spans.addAll(highlightSpans);
        }
      }

      // 🌐 Sites web — en liste : uniquement common span ; en barre : badge + nom col B + logo + lien
      if (item.source == SourceType.siteWeb) {
        if (!scaleDownToFitLine1) {
          spans.add(siteInternetBadgeSpan());
          return spans;
        }
        spans.add(siteInternetBadgeSpan());
        spans.add(const TextSpan(text: ' '));
        final nomColB = ((item.commentaire ?? item.label).trim()).toUpperCase();
        final urlColD = item.url?.trim();
        if (nomColB.isNotEmpty) {
          final highlightSpans = highlightText(
            context: context,
            text: nomColB,
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          );
          if (urlColD != null && urlColD.isNotEmpty) {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: () => onOpenUrl(urlColD),
                borderRadius: BorderRadius.circular(4),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Spinnaker',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? Colors.grey.shade600 : Colors.black87,
                    ),
                    children: highlightSpans,
                  ),
                ),
              ),
            ),);
          } else {
            spans.addAll(highlightSpans);
          }
        }
        // PDF : logo uniquement dans le badge hoverpill (ligne 2), pas en ligne 1
        // Ne pas afficher le picto écran (monitor_www) comme logo ; uniquement les vrais logos (ex. POSOS).
        final iconPath = item.iconUrl?.trim();
        if (iconPath != null &&
            iconPath.isNotEmpty &&
            !iconPath.toLowerCase().contains('monitor_www')) {
          spans.add(const TextSpan(text: ' '));
          final rawTooltip = (item.commentaire ?? item.label).trim();
          final siteWebTooltip = rawTooltip.isEmpty ? 'Site internet' : rawTooltip;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: logoWithTooltipZoom(
                tooltip: siteWebTooltip.isNotEmpty ? siteWebTooltip : 'Site internet',
                child: InkWell(
                  onTap: urlColD != null && urlColD.isNotEmpty
                      ? () => onOpenUrl(urlColD)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: _siteWebLogoWidget(iconPath),
                ),
              ),
            ),
          ),);
        }
        // Badge link-external à droite : ouvre l'URL col D au clic, couleur offibox, inversion au survol/clic
        if (urlColD != null && urlColD.isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _SiteWebLinkExternalBadge(
              url: urlColD,
              onOpenUrl: onOpenUrl,
            ),
          ),);
        }
      }

      // 🟪 Annuaires (CRPV, Centres anti poison, CHU) — logo annuaire + span + libellé + tél, fax (ligne 1)
      if (item.source == SourceType.pharmacovigilance ||
          item.source == SourceType.centresAntiPoison ||
          item.source == SourceType.chu ||
          item.source == SourceType.ceipAddictovigilance ||
          item.source == SourceType.annuaireSanteRpps) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Image.asset(
              'assets/icons/annuaire.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(width: 20, height: 20),
            ),
          ),
        ),);
        spans.add(annuaireSquareSpan());
        spans.add(const TextSpan(text: ' '));
        spans.addAll(
          highlightText(
            context: context,
            text: label.trim(),
            searchQuery: query,
            italic: isDisabled,
            forceGrey: isDisabled,
            disableBold: false,
          ),
        );

        // Ligne 1 annuaire RPPS : Docteur X, médecin (spé) uniquement. Tél/Fax → ligne 2 ; RPPS, MSS, Structures → ligne 3.
        // MSS badge en ligne 3 (ResultLine3Actions)
        // ignore: dead_code
        if (false) {
          final mss = item.mssanteEmail?.replaceAll('"', '').replaceAll("'", '').trim();
          if (mss != null && mss.isNotEmpty) {
          spans.add(const TextSpan(text: ' '));
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _wrapBadgeIfDisabled(
                  OffiboxTooltip(
                    message: 'MSSanté (cliquer pour écrire)',
                    child: InkWell(
                      onTap: () => openUrl('mailto:$mss'),
                      borderRadius: BorderRadius.circular(8),
                      child: CodeBadgeWithCopy(
                        label: 'MSS',
                        value: mss,
                        tooltip: 'Copier l’adresse MSSanté',
                        leadingIcon: Icons.verified_user,
                      ),
                    ),
                  ),
                  isDisabled,
                ),
              ),
            ),
          );
          }
        }

      }

      // 📘 LPP — ligne 1 : badge LPP + "CODE LPP: " + code + badge copier + libellé (source en ligne 2 uniquement)
      if (item.source == SourceType.lpp &&
          item.cip13 != null &&
          item.cip13!.length == 7) {
        spans.add(const TextSpan(text: ' '));
        spans.add(TextSpan(
          text: 'CODE LPP: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.grey.shade500 : Colors.black87,
            fontFamily: 'Spinnaker',
          ),
        ),);
        spans.add(TextSpan(
          text: item.cip13!,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.grey.shade500 : Colors.black87,
            fontFamily: 'Spinnaker',
          ),
        ),);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _wrapBadgeIfDisabled(
                CodeBadgeWithCopy(
                  label: 'Code LPP',
                  value: item.cip13!,
                  tooltip: 'Copier le code LPP',
                ),
                isDisabled,
              ),
            ),
          ),
        );
        if (item.lppLibelle != null && item.lppLibelle!.trim().isNotEmpty) {
          spans.add(TextSpan(
            text: '  ·  ',
            style: TextStyle(
              color: isDisabled ? Colors.grey.shade500 : Colors.black54,
              fontFamily: 'Spinnaker',
            ),
          ),);
          final libelle = normalizeText(item.lppLibelle!.trim())
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim();
          spans.addAll(
            highlightText(
              context: context,
              text: libelle,
              searchQuery: query,
              italic: isDisabled,
              forceGrey: isDisabled,
              disableBold: false,
            ),
          );
        }
      } else if (item.source != SourceType.keyword && item.source != SourceType.catalogue && item.source != SourceType.siteWeb && item.source != SourceType.codesActes && item.source != SourceType.pharmacovigilance && item.source != SourceType.centresAntiPoison && item.source != SourceType.chu && item.source != SourceType.ceipAddictovigilance && item.source != SourceType.annuaireSanteRpps) {
        String cleanLabel = cleanLabelLine1(label);
        if (item.source == SourceType.amc) {
          cleanLabel = cleanLabel.replaceFirst(
            RegExp(r'^mutuelle\s+', caseSensitive: false),
            '',
          );
        }
        cleanLabel = cleanLabel
            .replaceAll(RegExp(r'\s*\((LPP|DM|VETO)\)\s*', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s*VETO\)\s*', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s*LPP\)\s*', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s*\(LPP\s*', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();

        final labelSpans = highlightText(
          context: context,
          text: cleanLabel,
          searchQuery: query,
          italic: isDisabled,
          forceGrey: isDisabled,
          disableBold: isDisabled,
          isHop: item.hospitalOnly,
          isNsfp: item.isNsfpEffective,
          disableLinks: isOrganisme,
        );
        // DM (pansements) : clic sur le nom ouvre la fiche produit (même URL que le badge Fiche produit).
        if (item.source == SourceType.dm &&
            item.url != null &&
            item.url!.trim().isNotEmpty) {
          final ficheUrl = item.url!.trim();
          final recognizer = TapGestureRecognizer()
            ..onTap = () => onOpenUrl(ficheUrl);
          spans.add(TextSpan(
            recognizer: recognizer,
            children: labelSpans,
          ),);
        } else {
          spans.addAll(labelSpans);
        }
      }

      if (item.source == SourceType.amc || item.source == SourceType.amo) {
        spans.add(const TextSpan(text: ' '));
        if (item.cip13 != null && item.cip13!.isNotEmpty) {
          final code = item.cip13!.replaceAll('"', '').replaceAll("'", '');
          final labelCode = item.source == SourceType.amc
              ? 'code préfectoral'
              : 'code régime';
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _wrapBadgeIfDisabled(
                  CodeBadgeWithCopy(
                    label: labelCode,
                    value: code,
                    tooltip: 'Copier le $labelCode',
                  ),
                  isDisabled,
                ),
              ),
            ),
          );
        }
        if (item.phone != null && item.phone!.isNotEmpty) {
          final phone = item.phone!.replaceAll('"', '').replaceAll("'", '');
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _wrapBadgeIfDisabled(
                  CodeBadgeWithCopy(
                    label: 'Tél',
                    value: phone,
                    tooltip: 'Copier le numéro',
                    leadingIcon: Icons.phone,
                  ),
                  isDisabled,
                ),
              ),
            ),
          );
        }
        if (item.fax != null && item.fax!.isNotEmpty) {
          final fax = item.fax!.replaceAll('"', '').replaceAll("'", '');
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _wrapBadgeIfDisabled(
                  CodeBadgeWithCopy(
                    label: 'Fax',
                    value: fax,
                    tooltip: 'Copier le fax',
                    leadingIcon: Icons.fax,
                  ),
                  isDisabled,
                ),
              ),
            ),
          );
        }
      }

      if (item.liste1) {
        spans.add(_listeSpan('(LISTE 1)', Colors.red));
      }
      if (item.liste2) {
        spans.add(_listeSpan('(LISTE 2)', Colors.green));
      }

      _addCodeBadgeSpans(spans: spans, context: context, item: item, isDisabled: isDisabled);

      // BDM : badge « plus d'infos » affiché en ligne 2 après les autres badges (voir ResultLine2Code).
      final showPlusInfos = (statutsForCis != null && statutsForCis!.isNotEmpty) ||
          (tauxRemboursement != null && tauxRemboursement!.trim().isNotEmpty) ||
          (compositionLine != null && compositionLine!.trim().isNotEmpty) ||
          (listes != null && listes!.isNotEmpty);
      if (showPlusInfos && item.source != SourceType.bdm) {
        spans.add(const TextSpan(text: ' '));
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PlusInfosBadge(
                statuts: statutsForCis ?? const [],
                tauxRemboursement: tauxRemboursement,
                compositionLine: compositionLine,
                listes: listes ?? const [],
                isDisabled: isDisabled,
              ),
            ),
          ),
        );
      }

      if (hasNsfpDate) {
        spans.add(nsfpTextEndSpan(item));
      }

      return spans;
    });


// En barre (injecté) : renvoi à la ligne à la même taille de police pour ne pas toucher le logo Offibox à droite.
// En liste : une ligne, débordement clip.
final richText = RichText(
  softWrap: scaleDownToFitLine1,
  overflow: TextOverflow.clip,
  text: TextSpan(
    style: TextStyle(
      fontSize: 13,
      fontFamily: 'Spinnaker',
      color: isDisabled ? Colors.grey.shade500 : Colors.black87,
      fontStyle: isDisabled ? FontStyle.italic : FontStyle.normal,
      fontWeight: isDisabled ? FontWeight.w400 : FontWeight.w600,
    ),
    children: cachedSpans,
  ),
);
return richText;
  }
}

// ======================================================
// 🔧 HELPERS
// ======================================================

WidgetSpan _listeSpan(String text, Color color) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Spinnaker',
          color: color,
        ),
      ),
    ),
  );
}

Widget offiboxCopyWidget({
  required BuildContext context,
  required String code,
  String tooltip = 'Copier',
  bool disabled = false,
}) {
  return OffiboxTooltip(
    message: tooltip,
    child: InkWell(
      onTap: disabled
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Copié'),
                  duration: Duration(milliseconds: 800),
                ),
              );
            },
      child: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(
          Icons.copy,
          size: 14,
        ),
      ),
    ),
  );
}

/// Ligne 1 BDM simplifiée quand le libellé vient du cache BDPM : pas de highlight, moins de spans.
void _buildBdmFastPathSpans({
  required List<InlineSpan> spans,
  required String label,
  required String query,
  required bool isDisabled,
  required String? fic03Status,
  required SearchResult item,
  required List<String>? statutsForCis,
  required String? tauxRemboursement,
  required String? compositionLine,
  required List<String> listes,
  required Set<String>? hospitalCip13Set,
  required bool hasNsfpDate,
  required BuildContext context,
  Map<String, Generique2026Info>? generiques2026ByCis,
  String cisKeyBdm = '',
}) {
  spans.add(
    const WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: EdgeInsets.only(right: 6),
        child: Text('💊', style: TextStyle(fontSize: 20)),
      ),
    ),
  );
  if (fic03Status == 'R') {
    spans.add(princepsSquareSpan());
    spans.add(const TextSpan(text: ' '));
  } else if (fic03Status == 'G' || item.isGeneric == true) {
    spans.add(geSquareSpanGreen());
    spans.add(const TextSpan(text: ' '));
  } else {
    final generique2026Info = (generiques2026ByCis != null && cisKeyBdm.isNotEmpty)
        ? generiques2026ByCis[cisKeyBdm]
        : null;
    if (generique2026Info != null && item.isGeneric != true) {
      spans.add(princepsSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
  }
  // BDM : badges STUPS / EXCEPTION / SURV / OTC/Libre accès / PIH / HOP après la gélule, avant le libellé (ligne 1).
  final cip13DigitsFast = item.cip13?.replaceAll(RegExp(r'\D'), '');
  final bool showNrBadgeFast = item.source == SourceType.bdm &&
      (tauxRemboursement == null || tauxRemboursement.trim().isEmpty) &&
      (hospitalCip13Set != null && cip13DigitsFast != null && cip13DigitsFast.length == 13 && !hospitalCip13Set!.contains(cip13DigitsFast));
  if (item.source == SourceType.bdm &&
      (item.isStupefiant == true ||
          item.isException == true ||
          item.isSurveillanceParticuliere == true ||
          item.isOtc == true ||
          showNrBadgeFast ||
          item.isPih == true ||
          item.hospitalOnly == true)) {
    spans.add(const TextSpan(text: ' '));
    if (item.isStupefiant == true) {
      spans.add(stupSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
    if (item.isException == true) {
      spans.add(exceptionSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
    if (item.isSurveillanceParticuliere == true) {
      spans.add(surveillanceSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
    if (item.isOtc == true || showNrBadgeFast) {
      spans.add(otcSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
    if (item.isPih == true) {
      spans.add(pihSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
    if (item.hospitalOnly == true) {
      spans.add(hopSquareSpan());
      spans.add(const TextSpan(text: ' '));
    }
  }
  final effectiveLabel = label.trim().isEmpty ? item.label : label;
  final displayLabel = cleanLabelLine1(effectiveLabel);
  spans.addAll(
    highlightText(
      context: context,
      text: displayLabel,
      searchQuery: query,
      italic: isDisabled,
      forceGrey: isDisabled,
      disableBold: false,
    ),
  );
  _addCodeBadgeSpans(spans: spans, context: context, item: item, isDisabled: isDisabled);
  // BDM : badge « plus d'infos » affiché en ligne 2 après les autres badges (voir ResultLine2Code).
  final showPlusInfos = (statutsForCis != null && statutsForCis.isNotEmpty) ||
      (tauxRemboursement != null && tauxRemboursement.trim().isNotEmpty) ||
      (compositionLine != null && compositionLine.trim().isNotEmpty) ||
      (listes.isNotEmpty);
  if (showPlusInfos && item.source != SourceType.bdm) {
    spans.add(const TextSpan(text: ' '));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: PlusInfosBadge(
            statuts: statutsForCis ?? const [],
            tauxRemboursement: tauxRemboursement,
            compositionLine: compositionLine,
            listes: listes,
            isDisabled: isDisabled,
          ),
        ),
      ),
    );
  }
  if (hasNsfpDate) {
    spans.add(nsfpTextEndSpan(item));
  }
}

/// CIP (BDM) / EAN (DM) / GTIN (veto) en badge ligne 1
void _addCodeBadgeSpans({
  required List<InlineSpan> spans,
  required BuildContext context,
  required SearchResult item,
  required bool isDisabled,
}) {
  final code = item.cip13?.replaceAll('"', '').replaceAll("'", '');
  if (code == null || code.isEmpty) return;

  String label;
  switch (item.source) {
    case SourceType.bdm:
      label = 'CIP';
      break;
    case SourceType.dm:
      label = 'EAN';
      break;
    case SourceType.veto:
      label = 'GTIN';
      break;
    default:
      return;
  }

  spans.add(const TextSpan(text: ' '));
  spans.add(
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _wrapBadgeIfDisabled(
          CodeBadgeWithCopy(
            label: label,
            value: code,
            tooltip: 'Copier le $label',
            fontSize: 10,
          ),
          isDisabled,
        ),
      ),
    ),
  );

  // DM (pansements) : plus d’icône lien externe en ligne 1 (clic sur le nom ouvre la fiche).
}

Widget _wrapBadgeIfDisabled(Widget child, bool isDisabled) {
  if (!isDisabled) return child;
  return Opacity(opacity: 0.7, child: child);
}

/// Normalise le chemin d'asset (antislashs → slashes) pour éviter les erreurs de chargement sur Windows.
String _normalizeAssetPath(String path) => path.trim().replaceAll(r'\', '/');

/// Taille unique des icônes laboratoire en ligne 1 (logo, lien externe, tél, fax, mail).
const double _labLine1IconBoxSize = 36;
const double _labLine1IconInnerSize = 28;

/// Décoration commune : contour (liseré) + léger effet 3D pour les icônes laboratoire ligne 1.
BoxDecoration _labLine1IconDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        offset: const Offset(0, 2),
        blurRadius: 3,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.9),
        offset: const Offset(0, -1),
        blurRadius: 0,
      ),
    ],
  );
}

Widget _labIconWidget(String iconPath, double size) {
  final normalized = _normalizeAssetPath(iconPath);
  final path = normalized.toLowerCase();
  if (path.endsWith('.svg')) {
    return FutureBuilder<bool>(
      future: rootBundle.load(normalized).then((_) => true, onError: (_, __) => false),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return SvgPicture.asset(
            normalized,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return SizedBox(width: size, height: size);
      },
    );
  }
  return Image.asset(
    normalized,
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
  );
}

/// Badge link-external à droite du libellé site web : couleur offibox, inversion au tooltip (survol) et au clic ; ouvre l'URL col D.
/// Si [useLabIconStyle] true (ligne 1 laboratoire), même taille que les autres icônes + contour 3D.
class _SiteWebLinkExternalBadge extends StatefulWidget {
  const _SiteWebLinkExternalBadge({
    required this.url,
    required this.onOpenUrl,
    this.useLabIconStyle = false,
  });
  final String url;
  final void Function(String url) onOpenUrl;
  final bool useLabIconStyle;

  @override
  State<_SiteWebLinkExternalBadge> createState() => _SiteWebLinkExternalBadgeState();
}

class _SiteWebLinkExternalBadgeState extends State<_SiteWebLinkExternalBadge> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _inverted => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    final double size = widget.useLabIconStyle ? _labLine1IconInnerSize : 20;
    final double boxSize = widget.useLabIconStyle ? _labLine1IconBoxSize : (20 + 8);
    const String asset = 'assets/icons/link-external.svg';
    final decoration = widget.useLabIconStyle
        ? _labLine1IconDecoration(color: _inverted ? OffiboxColors.primary : Colors.white).copyWith(
            border: Border.all(color: OffiboxColors.primary, width: 1),
          )
        : BoxDecoration(
            color: _inverted ? OffiboxColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: OffiboxColors.primary, width: 1),
          );
    return OffiboxTooltip(
      message: widget.url,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            widget.onOpenUrl(widget.url);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.useLabIconStyle ? boxSize : null,
            height: widget.useLabIconStyle ? boxSize : null,
            padding: EdgeInsets.all(widget.useLabIconStyle ? (boxSize - size) / 2 : 4),
            decoration: decoration,
            child: SizedBox(
              width: size,
              height: size,
              child: SvgPicture.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  _inverted ? Colors.white : OffiboxColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo colonne C des sites web : même taille que les logos outils métier. Gère les assets manquants (ex. logo-FSPF-color.svg) sans crash.
Widget _siteWebLogoWidget(String iconPath) {
  final normalized = _normalizeAssetPath(iconPath);
  final path = normalized.toLowerCase();
  final isSvg = path.endsWith('.svg');
  Widget image;
  if (isSvg) {
    image = FutureBuilder<Object>(
      future: rootBundle.load(normalized).then((_) => true, onError: (_, __) => false),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return SvgPicture.asset(
            normalized,
            width: keywordLogoInnerSize,
            height: keywordLogoInnerSize,
            fit: BoxFit.contain,
          );
        }
        return const SizedBox(width: keywordLogoInnerSize, height: keywordLogoInnerSize);
      },
    );
  } else {
    image = Image.asset(
      normalized,
      width: keywordLogoInnerSize,
      height: keywordLogoInnerSize,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(width: keywordLogoInnerSize, height: keywordLogoInnerSize),
    );
  }
  return Container(
    width: keywordLogoBoxSize,
    height: keywordLogoBoxSize,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: image,
    ),
  );
}
