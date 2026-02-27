import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/statuts/ansm_helpers.dart';
import 'package:offibox/utils/date_formatters.dart';
import 'package:offibox/utils/normalize.dart';
import 'package:offibox/data/ansm_rappels_loader.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/utils/ansm_rappel_match.dart';
import 'package:offibox/ui/results/plus_infos_badge.dart';
import 'package:offibox/ui/results/result_line_3_actions.dart';
import 'package:offibox/ui/spans/common_spans.dart';

String normalizeAddress(String input) {
  return utf8.decode(latin1.encode(input), allowMalformed: true);
}

/// Enlève tous les mots entre parenthèses (ex. "ZOLPIDEM (TARTRATE DE) 10 MG" → "ZOLPIDEM 10 MG").
String stripParenthesesFromGenericName(String s) {
  if (s.isEmpty) return s;
  return s
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Retourne le libellé col 1 (CSV génériques) uniquement avant les parenthèses (ex. "ACETATE D'ABIRATERONE 250 mg (sel)" → "ACETATE D'ABIRATERONE 250 mg").
String col1BeforeParentheses(String colA) {
  if (colA.isEmpty) return colA;
  final t = colA.trim();
  final idx = t.indexOf('(');
  if (idx <= 0) return t;
  return t.substring(0, idx).trim();
}

/// Formate la col A génériques 2026 pour le badge "générique : X" des princeps.
/// — Une seule DCI : premier mot en majuscules (ex. "RANITIDINE (CHLORHYDRATE DE) ÉQUIVALANT À RANITIDINE 300 MG" → "RANITIDINE").
/// — Association : on enlève les mentions de sel, on garde "DCI1+DCI2 dosage" (ex. "LISINOPRIL (DIHYDRATE) ÉQUIVALANT À LISINOPRIL 20 MG + HYDROCHLOROTHIAZIDE 12,5 MG" → "LISINOPRIL+HYDROCHLOROTHIAZIDE 12,5 MG").
String formatGenericNameForPrincepsBadge(String colA) {
  if (colA.isEmpty) return colA;
  final sansSels = stripParenthesesFromGenericName(colA);
  final t = sansSels.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return colA.trim();
  const sep = ' + ';
  final idx = t.toUpperCase().indexOf(sep);
  if (idx >= 0) {
    final part0 = t.substring(0, idx).trim();
    final part1 = t.substring(idx + sep.length).trim();
    final firstWord0 = part0.split(RegExp(r'\s+')).first.trim().toUpperCase();
    if (firstWord0.isEmpty) return part1;
    if (part1.isEmpty) return firstWord0;
    return '$firstWord0+$part1';
  }
  return t.split(RegExp(r'\s+')).first.trim().toUpperCase();
}

/// Formate le nom princeps (ex. "STILNOX" → "Stilnox") pour l'affichage du badge "princeps: X".
String princepsDisplayNameFromUppercase(String princepsUppercase) {
  if (princepsUppercase.isEmpty) return princepsUppercase;
  return princepsUppercase[0] + princepsUppercase.substring(1).toLowerCase();
}

/// Nom court princeps pour le badge ligne 2 (ex. "XANAX 0,25 MG, COMPRIMÉ" → "Xanax").
/// Si deux princeps (col B - col C), ex. "AZANTAC 150 MG - RANIPLEX 150 MG" → "Azantac - Raniplex".
String shortPrincepsDisplayForBadge(String princepsDisplay) {
  final t = princepsDisplay.trim();
  if (t.isEmpty) return t;
  const sep = ' - ';
  final idx = t.toUpperCase().indexOf(sep);
  if (idx >= 0) {
    final part1 = t.substring(0, idx).trim().split(RegExp(r'\s+')).first.trim();
    final part2 = t.substring(idx + sep.length).trim().split(RegExp(r'\s+')).first.trim();
    final a = princepsDisplayNameFromUppercase(part1.toUpperCase());
    final b = princepsDisplayNameFromUppercase(part2.toUpperCase());
    return a.isEmpty && b.isEmpty ? t : '$a - $b';
  }
  final firstWord = t.split(RegExp(r'\s+')).first.trim();
  return princepsDisplayNameFromUppercase(firstWord.toUpperCase());
}

/// Pour les princeps : si la dénomination contient "équivalant à X", retourne X (bloc après "équivalant à ").
/// Ex. "ONDANSETRON (CHLORHYDRATE D') DIHYDRATE équivalant à ONDANSETRON 8 mg" → "ONDANSETRON 8 mg".
String? equivalantAFromLabel(String? labelRaw) {
  if (labelRaw == null || labelRaw.isEmpty) return null;
  const marker = 'équivalant à ';
  final idx = labelRaw.toLowerCase().indexOf(marker);
  if (idx < 0) return null;
  final after = labelRaw.substring(idx + marker.length).trim();
  return after.isEmpty ? null : after;
}

/// Indique si l'URL pointe vers YouTube.
bool _isYouTubeUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.contains('youtube.com') || u.contains('youtu.be');
}

bool _isPdfUrl(String url) {
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.pdf');
}

bool _isXlsUrl(String url) {
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.xls') || path.endsWith('.xlsx');
}

/// Logo PDF rouge (assets/icons/pdf_red.svg) pour le badge "document" et fiches VOC.
Widget _pdfIconWidget() {
  return SvgPicture.asset(
    'assets/icons/pdf_red.svg',
    width: 16,
    height: 16,
    fit: BoxFit.contain,
  );
}

/// Logo Excel pour le badge hoverpill quand l'URL pointe vers un .xls/.xlsx.
Widget _excelIconWidget() {
  return Image.asset(
    'assets/icons/Microsoft_Office_Excel_Logo_128px.png',
    width: 16,
    height: 16,
    fit: BoxFit.contain,
  );
}

/// Icône lien externe (outils métier / sites web) pour les URL externes — couleur Offibox.
Widget _externalLinkIconWidget() {
  return SvgPicture.asset(
    'assets/icons/link-external.svg',
    width: 20,
    height: 20,
    fit: BoxFit.contain,
    colorFilter: const ColorFilter.mode(OffiboxColors.primary, BlendMode.srcIn),
  );
}

/// Icône pour un lien : PDF → picture_as_pdf, URL site web (http/https) → globe, sinon open_in_new.
IconData iconForUrl(String url) {
  final lower = url.trim().toLowerCase();
  if (lower.contains('pdf')) return Icons.picture_as_pdf;
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return Icons.public;
  }
  return Icons.open_in_new;
}

class ResultLine2Code extends StatelessWidget {
  final SearchResult item;
  final void Function(String url)? onOpenUrl;
  /// Source unique : fichiers-medicaments/statutsANSM.csv
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  /// CIS → info générique 2026 (badge "princeps : col B", RCP/MEDDISPAR à la suite).
  final Map<String, Generique2026Info>? generiques2026ByCis;
  /// Premier mot col B → col A (legacy).
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  /// DCI (premier mot col A) → col A. Pour "générique : X" sur BDM : match par mot entier (évite ALMUS→ENALAPRIL).
  final Map<String, String>? generiques2026DciToGenericName;
  /// Si fourni, au clic sur "Espace pro" (catalogue) on affiche la fenêtre de connexion au lieu d'ouvrir l'URL directement.
  final void Function(BuildContext context, String url, String labName, String? iconUrl)? onOpenEspacePro;
  /// Si fourni, au clic sur le badge "Catalogue" on affiche le panneau catalogue sous la barre au lieu d'ouvrir l'URL.
  final VoidCallback? onOpenCataloguePanel;
  /// Si fourni, au clic sur un pill YouTube on affiche la vidéo sous la barre au lieu d'ouvrir l'URL.
  final void Function(String youtubeUrl)? onOpenYouTubeVideo;
  /// Vidéo de démonstration (videos.csv) : pill en ligne 3 (voir ResultLine3Actions).
  /// Si fourni, au clic sur le pill « Flash info » (Pharmaradio) on affiche le panneau sous la barre.
  final VoidCallback? onOpenPharmaradioFlash;
  /// Quand true (résultat injecté dans la barre), affiche le badge "générique = [col A]" pour les produits en col B (princeps).
  final bool isInjected;
  /// Noms normalisés des produits concernés par un rappel ANSM (col A du fichier rappels) — si le produit BDM est dedans, affiche « produit concerné par un rappel de lot N° » en rouge italique.
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : affiche la date du dernier rappel si le produit correspond.
  final AnsmRappelItem? ansmLastRappel;
  /// CIP13 → colonne 5 du CSV biosimilaires 2026 (fenêtre « Infos biosimilaire » avec puces).
  final Map<String, String>? biosimilairesInfoByCip;
  /// CIS avec « arrêt de commercialisation » dans CIS_CIP_Dispo_Spec — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date d'arrêt + URL pour le badge « arrêt de commercialisation » (affichage date, clic → URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// Statuts CIS (col B) pour badge « plus d'infos » en ligne 2 (BDM uniquement).
  final List<String>? statutsForCis;
  /// Taux de remboursement (ex. "65 %") pour la modale « plus d'infos ».
  final String? tauxRemboursement;
  /// Composition BDPM pour la modale « plus d'infos ».
  final String? compositionLine;
  /// Listes (ex. ["Liste 1", "Liste 2"]) pour la modale « plus d'infos ».
  final List<String>? listes;

  const ResultLine2Code({
    super.key,
    required this.item,
    this.onOpenUrl,
    this.ansmStatutsByCis,
    this.generiques2026ByCis,
    this.generiques2026PrincepsKeyToGenericName,
    this.generiques2026DciToGenericName,
    this.onOpenEspacePro,
    this.onOpenCataloguePanel,
    this.onOpenYouTubeVideo,
    this.onOpenPharmaradioFlash,
    this.isInjected = false,
    this.recalledProductNames,
    this.ansmLastRappel,
    this.biosimilairesInfoByCip,
    this.cisArretCommercialisation,
    this.arretCommercialisationByCis,
    this.statutsForCis,
    this.tauxRemboursement,
    this.compositionLine,
    this.listes,
  });

  String _cleanCode(String value) {
    return value.replaceAll('"', '').replaceAll("'", '');
  }

  bool get _hasAnyCode {
  // 🏥 Organismes : uniquement si adresse
  if (item.source == SourceType.amc || item.source == SourceType.amo) {
    return item.groupLabel != null && item.groupLabel!.isNotEmpty;
  }

  // 🟪 CRPV — ligne 2 = adresse
  if (item.source == SourceType.pharmacovigilance) {
    return item.groupLabel != null && item.groupLabel!.isNotEmpty;
  }

  // 🩹 DM : EAN affiché une seule fois en ligne 1 — pas de doublon en ligne 2
  if (item.source == SourceType.dm) {
    return false;
  }
  // 🐾 Véto : ligne 2 = CIS uniquement (GTIN retiré)
  if (item.source == SourceType.veto) {
    return item.cis != null;
  }

  // 💊 BDM : ligne 2 = au moins "Source : BDNM" ; + statut ANSM, rappel, badges biosim, bioréf, générique 2026, etc.
  if (item.source == SourceType.bdm) {
    return true; // Toujours afficher la ligne 2 pour les médicaments (logo BDNM au minimum)
  }

  // 📘 LPP : ligne 2 = pill "+ d'infos" uniquement si URL (col B) présente
  if (item.source == SourceType.lpp) {
    return item.url?.trim().isNotEmpty ?? false;
  }

  // 🏷️ Mots-clés : ligne 2 = HoverPill(s) nom col C/D, E/F, G/H
  if (item.source == SourceType.keyword) {
    return (item.badge1Url ?? item.badge2Url ?? item.badge3Url ?? item.url)?.trim().isNotEmpty ?? false;
  }

  // 🌐 Sites web : ligne 2 = HoverPill(s) col E/F, G/H, I/J uniquement
  if (item.source == SourceType.siteWeb) {
    return (item.badge1Name != null && item.badge1Url != null && item.badge1Name!.trim().isNotEmpty && item.badge1Url!.trim().isNotEmpty) ||
        (item.badge2Name != null && item.badge2Url != null && item.badge2Name!.trim().isNotEmpty && item.badge2Url!.trim().isNotEmpty) ||
        (item.badge3Name != null && item.badge3Url != null && item.badge3Name!.trim().isNotEmpty && item.badge3Url!.trim().isNotEmpty);
  }

  // 🏭 Catalogues laboratoires : ligne 2 = HoverPill(s) Espace pro, Catalogue, etc. (F, G, H, I/J, K/L)
  if (item.source == SourceType.catalogue) {
    return (item.badge1Url ?? item.badge2Url ?? item.badge3Url ?? item.badge4Url)?.trim().isNotEmpty ?? false;
  }

  return item.cip13 != null || item.cis != null;
}

@override
Widget build(BuildContext context) {
  if (!_hasAnyCode) return const SizedBox.shrink();

  // ─────────────────────────────
  // 🏥 AMC-AMO — ADRESSE (ligne 2)
  // ─────────────────────────────
  if ((item.source == SourceType.amc || item.source == SourceType.amo) &&
      item.groupLabel != null &&
      item.groupLabel!.isNotEmpty) {
    final address = normalizeText(item.groupLabel!);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            address,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontFamily: 'Spinnaker',
            ),
          ),
          Tooltip(
            message: "Copier l'adresse",
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse copiée'),
                    duration: Duration(milliseconds: 900),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  // 🟪 CRPV — ADRESSE (ligne 2)
  // ─────────────────────────────
  if (item.source == SourceType.pharmacovigilance &&
      item.groupLabel != null &&
      item.groupLabel!.isNotEmpty) {
    final address = normalizeText(item.groupLabel!);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          address,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontFamily: 'Spinnaker',
          ),
        ),
        Tooltip(
          message: 'Copier l’adresse',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adresse copiée'),
                  duration: Duration(milliseconds: 900),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.copy,
                size: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // ─────────────────────────────
  // 📘 LPP — ligne 2 : pill "+ d'infos" (style meddispar), tooltip "accès nomenclature LPP", clic → URL col B
  // ─────────────────────────────
  if (item.source == SourceType.lpp) {
    final hasUrl = item.url?.trim().isNotEmpty ?? false;
    if (!hasUrl) return const SizedBox.shrink();
    final pill = HoverPillButton(
      label: '+ d\'infos',
      icon: _isPdfUrl(item.url!) || _isXlsUrl(item.url!) ? null : iconForUrl(item.url!),
      iconWidget: _isPdfUrl(item.url!) ? _pdfIconWidget() : _isXlsUrl(item.url!) ? _excelIconWidget() : _externalLinkIconWidget(),
      tooltip: 'accès nomenclature LPP',
      onTap: () {
        if (onOpenUrl != null) {
          onOpenUrl!(item.url!.trim());
        } else {
          openUrl(item.url!.trim());
        }
      },
    );
    final sourceWidget = isInjected ? ResultLine3Actions.buildSourceRow(item, isInjected, onOpenUrl) : null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: sourceWidget != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pill,
                const SizedBox(width: 8),
                sourceWidget,
              ],
            )
          : pill,
    );
  }

  // ─────────────────────────────
  // 🏷️ Mots-clés — ligne 2 : pill "site internet" (col D) + HoverPill(s) E/F, G/H, I/J ; icône YouTube si vidéo
  // ─────────────────────────────
  if (item.source == SourceType.keyword) {
    final pills = <Widget>[];
    final urlLigne1 = item.url?.trim();

    void addPill(String name, String url, {bool isYouTube = false}) {
      if (name.isEmpty || url.isEmpty) return;
      final urlTrim = url.trim();
      final useYouTubePanel = isYouTube && onOpenYouTubeVideo != null;
      final isPdf = _isPdfUrl(url);
      final isXls = _isXlsUrl(url);
      // XLS/PDF : afficher tout le libellé (badge hover pill) — pas de troncature à 160px
      final maxLabelWidth = (isXls || isPdf) ? 500.0 : null;
      pills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: useYouTubePanel || isPdf || isXls ? null : iconForUrl(url),
        iconWidget: useYouTubePanel
            ? SvgPicture.asset(
                'assets/icons/youtube.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              )
            : isPdf
                ? _pdfIconWidget()
                : isXls
                    ? _excelIconWidget()
                    : _externalLinkIconWidget(),
        tooltip: urlTrim,
        onTap: () {
          if (useYouTubePanel) {
            onOpenYouTubeVideo!(urlTrim);
          } else if (onOpenUrl != null) {
            onOpenUrl!(urlTrim);
          } else {
            openUrl(urlTrim);
          }
        },
      ),);
    }

    // Pill pour url ligne 1 (col D) : PDF → "document" ; XLS → "tableur" ; pas de pill "site internet" (l’icône external link en ligne 1 suffit)
    if (urlLigne1 != null && urlLigne1.isNotEmpty && !_isYouTubeUrl(urlLigne1)) {
      if (_isPdfUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'document',
          iconWidget: _pdfIconWidget(),
          tooltip: 'Ouvrir le document PDF',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ));
      } else if (_isXlsUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'tableur',
          iconWidget: _excelIconWidget(),
          tooltip: 'Ouvrir le fichier Excel',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ));
      }
      // Sinon (URL site web) : pas de pill "site internet", l’icône external link en ligne 1 suffit
    }
    // Badge 1 (col E/F) — sauf si c'est le fallback "Lien" pour urlLigne1
    if (item.badge1Name != null && item.badge1Url != null) {
      final skip = item.badge1Name == 'Lien' && item.badge1Url!.trim() == urlLigne1;
      if (!skip) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge1Name!, item.badge1Url!, isYouTube: _isYouTubeUrl(item.badge1Url!));
      }
    }
    if (item.badge2Name != null && item.badge2Url != null) {
      if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
      addPill(item.badge2Name!, item.badge2Url!, isYouTube: _isYouTubeUrl(item.badge2Url!));
    }
    if (item.badge3Name != null && item.badge3Url != null) {
      if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
      addPill(item.badge3Name!, item.badge3Url!, isYouTube: _isYouTubeUrl(item.badge3Url!));
    }
    // Fallback : si aucune pill et qu'on a url ligne 1 (YouTube ou PDF/tableur uniquement ; pas de pill "site internet", l’icône external link en ligne 1 suffit)
    if (pills.isEmpty && urlLigne1 != null && urlLigne1.isNotEmpty) {
      if (_isYouTubeUrl(urlLigne1)) {
        addPill('site internet', urlLigne1, isYouTube: true);
      } else if (_isPdfUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'document',
          iconWidget: _pdfIconWidget(),
          tooltip: 'Ouvrir le document PDF',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ));
      } else if (_isXlsUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'tableur',
          iconWidget: _excelIconWidget(),
          tooltip: 'Ouvrir le fichier Excel',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ));
      }
      // URL site web : pas de pill "site internet", l’icône external link en ligne 1 suffit
    }
    if (pills.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: pills,
        ),
      );
    }
  }

  // ─────────────────────────────
  // 🌐 Sites web — ligne 2 : HoverPill(s) col E/F, G/H, I/J (noms col E, G, I → url F, H, J)
  // ─────────────────────────────
  if (item.source == SourceType.siteWeb) {
    final pills = <Widget>[];
    final isPharmaradio = (item.label?.toLowerCase().contains('pharmaradio') ?? false) ||
        (item.commentaire?.toLowerCase().contains('pharmaradio') ?? false) ||
        (item.labelRaw?.toLowerCase().contains('pharmaradio') ?? false);
    if (isPharmaradio && onOpenPharmaradioFlash != null) {
      pills.add(HoverPillButton(
        label: 'Flash info',
        icon: Icons.newspaper,
        tooltip: 'Afficher le flash info Pharmaradio sous la barre',
        onTap: onOpenPharmaradioFlash!,
      ));
    }
    void addPill(String name, String url, {bool isYouTube = false}) {
      if (name.isEmpty || url.isEmpty) return;
      if (isPharmaradio && name.toLowerCase().contains('flash info du jour')) return;
      final urlTrim = url.trim();
      final useYouTubePanel = isYouTube && onOpenYouTubeVideo != null;
      final isPdf = _isPdfUrl(url);
      final isXls = _isXlsUrl(url);
      final maxLabelWidth = (isXls || isPdf) ? 500.0 : null;
      pills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: useYouTubePanel || isPdf || isXls ? null : iconForUrl(url),
        iconWidget: useYouTubePanel
            ? SvgPicture.asset(
                'assets/icons/youtube.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              )
            : isPdf
                ? _pdfIconWidget()
                : isXls
                    ? _excelIconWidget()
                    : _externalLinkIconWidget(),
        tooltip: urlTrim,
        onTap: () {
          if (useYouTubePanel) {
            onOpenYouTubeVideo!(urlTrim);
          } else if (onOpenUrl != null) {
            onOpenUrl!(urlTrim);
          } else {
            openUrl(urlTrim);
          }
        },
      ),);
    }
    // Ne pas ajouter de pill "site internet" quand l’icône external link est déjà en ligne 1 (item.url)
    final hasMainUrl = item.url != null && item.url!.trim().isNotEmpty;
    final skipSiteInternetPill = (String name) =>
        hasMainUrl && name.toLowerCase().trim() == 'site internet';
    if (item.badge1Name != null && item.badge1Url != null && item.badge1Name!.trim().isNotEmpty && item.badge1Url!.trim().isNotEmpty) {
      if (!skipSiteInternetPill(item.badge1Name!.trim())) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge1Name!.trim(), item.badge1Url!.trim(), isYouTube: _isYouTubeUrl(item.badge1Url!));
      }
    }
    if (item.badge2Name != null && item.badge2Url != null && item.badge2Name!.trim().isNotEmpty && item.badge2Url!.trim().isNotEmpty) {
      if (!skipSiteInternetPill(item.badge2Name!.trim())) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge2Name!.trim(), item.badge2Url!.trim(), isYouTube: _isYouTubeUrl(item.badge2Url!));
      }
    }
    if (item.badge3Name != null && item.badge3Url != null && item.badge3Name!.trim().isNotEmpty && item.badge3Url!.trim().isNotEmpty) {
      if (!skipSiteInternetPill(item.badge3Name!.trim())) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge3Name!.trim(), item.badge3Url!.trim(), isYouTube: _isYouTubeUrl(item.badge3Url!));
      }
    }
    if (pills.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: pills,
        ),
      );
    }
  }

  // ─────────────────────────────
  // 🏭 Catalogues laboratoires — ligne 2 : HoverPill(s) F (espace pro), G (catalogue), H, I/J, K/L ; icône web ou PDF
  // ─────────────────────────────
  if (item.source == SourceType.catalogue) {
    final cataloguePills = <Widget>[];
    void addCataloguePill(String name, String url) {
      if (name.isEmpty || url.isEmpty) return;
      final isPdf = _isPdfUrl(url);
      final isXls = _isXlsUrl(url);
      // XLS/PDF : afficher tout le libellé du badge
      final maxLabelWidth = (isXls || isPdf) ? 500.0 : null;
      final isCatalogueBadge = name == 'Catalogue';
      if (isCatalogueBadge && onOpenCataloguePanel != null) {
        cataloguePills.add(HoverPillButton(
          label: name,
          maxLabelWidth: maxLabelWidth,
          icon: isPdf || isXls ? null : iconForUrl(url),
          iconWidget: isPdf ? _pdfIconWidget() : isXls ? _excelIconWidget() : _externalLinkIconWidget(),
          tooltip: url,
          onTap: onOpenCataloguePanel!,
        ),);
        return;
      }
      cataloguePills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: isPdf || isXls ? null : iconForUrl(url),
        iconWidget: isPdf ? _pdfIconWidget() : isXls ? _excelIconWidget() : _externalLinkIconWidget(),
        tooltip: url,
        onTap: () {
          if (onOpenUrl != null) {
            onOpenUrl!(url.trim());
          } else {
            openUrl(url.trim());
          }
        },
      ),);
    }
    if (item.badge1Name != null && item.badge1Url != null) {
      final isEspacePro = item.badge1Name == 'Espace pro';
      if (isEspacePro && onOpenEspacePro != null) {
        final openEspacePro = onOpenEspacePro!;
        final badge1Url = item.badge1Url!;
        cataloguePills.add(HoverPillButton(
          label: item.badge1Name!,
          icon: _isPdfUrl(item.badge1Url!) || _isXlsUrl(item.badge1Url!) ? null : iconForUrl(item.badge1Url!),
          iconWidget: _isPdfUrl(item.badge1Url!) ? _pdfIconWidget() : _isXlsUrl(item.badge1Url!) ? _excelIconWidget() : _externalLinkIconWidget(),
          tooltip: 'accès espace pro',
          onTap: () {
            openEspacePro(
              context,
              badge1Url.trim(),
              item.label.trim().isNotEmpty ? item.label : item.labelRaw.trim(),
              item.iconUrl,
            );
          },
        ),);
      } else if (isEspacePro) {
        cataloguePills.add(HoverPillButton(
          label: item.badge1Name!,
          icon: _isPdfUrl(item.badge1Url!) || _isXlsUrl(item.badge1Url!) ? null : iconForUrl(item.badge1Url!),
          iconWidget: _isPdfUrl(item.badge1Url!) ? _pdfIconWidget() : _isXlsUrl(item.badge1Url!) ? _excelIconWidget() : _externalLinkIconWidget(),
          tooltip: 'accès espace pro',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(item.badge1Url!.trim());
            } else {
              openUrl(item.badge1Url!.trim());
            }
          },
        ),);
      } else {
        addCataloguePill(item.badge1Name!, item.badge1Url!);
      }
    }
    if (item.badge2Name != null && item.badge2Url != null) {
      if (cataloguePills.isNotEmpty) cataloguePills.add(const SizedBox(width: 6));
      addCataloguePill(item.badge2Name!, item.badge2Url!);
    }
    if (item.badge3Name != null && item.badge3Url != null) {
      if (cataloguePills.isNotEmpty) cataloguePills.add(const SizedBox(width: 6));
      addCataloguePill(item.badge3Name!, item.badge3Url!);
    }
    if (item.badge4Name != null && item.badge4Url != null) {
      if (cataloguePills.isNotEmpty) cataloguePills.add(const SizedBox(width: 6));
      addCataloguePill(item.badge4Name!, item.badge4Url!);
    }
    if (cataloguePills.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: cataloguePills,
        ),
      );
    }
  }

  // ─────────────────────────────
  // 💊 BDM — ligne 2 : statut ANSM + badges biosimilaire / bioréférent
  // ─────────────────────────────
  if (item.source == SourceType.bdm) {
    final cisKey = item.cis?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
    final info = (ansmStatutsByCis != null && cisKey.isNotEmpty)
        ? ansmStatutsByCis![cisKey]
        : null;
    final hasBiosim = item.biosimilaireOf != null &&
        item.biosimilaireOf!.trim().isNotEmpty;
    final hasBioref = item.isBioreferent == true;

    final line2Children = <Widget>[];

    // Badges métier (commonspans) : Stups, Exception, OTC, PIH, HOP — même ordre et style qu’en ligne 1.
    if (item.isStupefiant == true) {
      line2Children.add(squareTagWidget(
        label: 'S/AS',
        color: Colors.red.shade700,
        tooltip: 'Médicament stupéfiant ou assimilé stupéfiant',
        url: 'https://www.meddispar.fr/Substances-veneneuses/Medicaments-stupefiants-et-assimiles/Criteres#nav-buttons',
      ));
    }
    if (item.isException == true) {
      line2Children.add(squareTagWidget(
        label: 'EXCEPTION',
        color: Colors.blue.shade600,
        tooltip: 'Médicament d’exception',
        url: 'https://www.meddispar.fr/Medicaments-d-exception/Criteres#nav-buttons',
      ));
    }
    if (item.isOtc == true) {
      line2Children.add(squareTagWidget(
        label: 'OTC/autre',
        color: Colors.lightGreenAccent.shade700,
        tooltip: 'OTC / autre / NR',
        url: 'https://ansm.sante.fr/',
      ));
    }
    if (item.isPih == true) {
      line2Children.add(squareTagWidget(
        label: 'PIH',
        color: Colors.orange.shade700,
        tooltip: 'Prescription initiale hospitalière',
        url: 'https://www.meddispar.fr/Medicaments-a-prescription-restreinte/'
            'Medicaments-a-prescription-initiale-hospitaliere/Criteres#nav-buttons',
      ));
    }
    if (item.hospitalOnly == true) {
      line2Children.add(squareTagWidget(
        label: 'HOP',
        color: Colors.blue.shade700,
        tooltip: 'Réservé à l’usage hospitalier',
      ));
    }
    if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));

    // Badge « arrêt de commercialisation » pour NSFP dont le CIS est dans CIS_CIP_Dispo_Spec (exception affichée).
    final isArretCommercialisation = item.isNsfpEffective == true &&
        cisKey.isNotEmpty &&
        (cisArretCommercialisation?.contains(cisKey) ?? false);
    final arretInfo = (isArretCommercialisation && arretCommercialisationByCis != null)
        ? arretCommercialisationByCis![cisKey]
        : null;
    if (isArretCommercialisation) {
      line2Children.add(_ArretCommercialisationBadge(
        dateArret: arretInfo?.dateArret,
        url: arretInfo?.url,
        onOpenUrl: onOpenUrl,
      ));
      line2Children.add(const SizedBox(width: 6));
    }

    // Produit concerné par un rappel ANSM : pendant 7 jours, message + badge "+ d'infos" (comme ligne 1)
    final matchesLastRappel = ansmLastRappel != null &&
        isProductConcernedByLastRappel(item, ansmLastRappel!);
    final inCsvRappel = recalledProductNames != null &&
        item.labelRaw != null &&
        item.labelRaw!.trim().isNotEmpty &&
        recalledProductNames!.contains(normalizeProductNameForRappel(item.labelRaw!));
    final isConcerned = matchesLastRappel || inCsvRappel;
    final rappelRecent7j = ansmLastRappel != null && isRappelRecent(ansmLastRappel!, maxDays: 7);

    if (isConcerned && rappelRecent7j && ansmLastRappel!.url.trim().isNotEmpty) {
      line2Children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ce médicament fait l\'objet d\'un rappel de lot',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.red.shade700,
                fontFamily: 'Spinnaker',
              ),
            ),
            const SizedBox(width: 8),
            HoverPillButton(
              label: '+ d\'infos',
              icon: Icons.info_outline,
              tooltip: 'Plus d\'infos sur le rappel (ANSM)',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(ansmLastRappel!.url.trim());
                } else {
                  openUrl(ansmLastRappel!.url.trim());
                }
              },
            ),
          ],
        ),
      );
    } else if (isConcerned) {
      // Rappel > 7 jours ou pas d'URL : message seul (sans badge)
      line2Children.add(
        Text(
          'Ce médicament fait l\'objet d\'un rappel de lot',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.red.shade700,
            fontFamily: 'Spinnaker',
          ),
        ),
      );
    }

    // Badge générique 2026 : "princeps: [nom princeps]" (rose) ou "générique: [DCI]" (rose) + RCP et MEDDISPAR en HoverPill
    final generique2026Info = (generiques2026ByCis != null && cisKey.isNotEmpty)
        ? generiques2026ByCis![cisKey]
        : null;
    if (generique2026Info != null) {
      if (item.isGeneric == true) {
        // Produits génériques (CIS en col D du CSV génériques 2026) : afficher "princeps: [nom court]" (ex. princeps: Xanax).
        final princepsLabel = generique2026Info.princepsDisplay.trim();
        if (princepsLabel.isNotEmpty) {
          final shortName = shortPrincepsDisplayForBadge(princepsLabel);
          line2Children.add(_GeneriqueEqualsBadge(
            princepsDisplayName: shortName,
            tooltipFullPrinceps: princepsLabel,
          ));
        }
      } else {
        // Princeps : afficher le libellé col 1 (avant parenthèses) + badge "princeps".
        final col1Label = col1BeforeParentheses(generique2026Info.genericNameColA);
        if (col1Label.isNotEmpty) {
          line2Children.add(_PrincepsLine2Widget(
            col1LabelBeforeParens: col1Label,
          ));
        }
      }
      if (item.url != null && item.url!.trim().isNotEmpty) {
        if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));
        line2Children.add(HoverPillButton(
          label: 'RCP',
          icon: Icons.description_outlined,
          tooltip: 'Accéder au RCP',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(item.url!.trim());
            } else {
              openUrl(item.url!.trim());
            }
          },
        ),);
      }
      if (item.meddisparUrl != null && item.meddisparUrl!.trim().isNotEmpty) {
        if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));
        line2Children.add(HoverPillButton(
          label: 'MEDDISPAR',
          icon: Icons.warning_amber_rounded,
          tooltip: 'Fiche MEDDISPAR',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(item.meddisparUrl!.trim());
            } else {
              openUrl(item.meddisparUrl!.trim());
            }
          },
        ),);
      }
    }
    // Badge biosimilaire de [bioréférent]. RCP et MEDDISPAR restent en ligne 3 (hover pills).
    // Espacement réduit entre badges pour biosimilaires afin de laisser la place à l’icône Source BDNM.
    final spacingBetweenBadges = hasBiosim ? 4.0 : 6.0;
    if (hasBiosim) {
      line2Children.add(_BiosimilaireBadge(bioreferent: item.biosimilaireOf!));
      final biosimInfo = (biosimilairesInfoByCip != null && item.cip13 != null)
          ? biosimilairesInfoByCip![item.cip13!.replaceAll(RegExp(r'\D'), '')]
          : null;
      if (biosimInfo != null && biosimInfo.trim().isNotEmpty) {
        line2Children.add(SizedBox(width: spacingBetweenBadges));
        line2Children.add(_BiosimilaireInfosBadge(infoText: biosimInfo));
      }
    }
    // Badge BIORÉFÉRENT
    if (hasBioref) {
      line2Children.add(const _BioreferentBadge());
    }

    // Générique 2026 "générique : col A" par match DCI supprimé : trop de faux positifs (ex. mot "SOLUTION"
    // dans le libellé BDM → affichage erroné "générique : SOLUTION DE GLUCOSE..." sur des produits comme le Doliprane).
    // On conserve uniquement le badge princeps (generique2026Info, par CIS) qui est fiable.

    // Statut ANSM (source statutsANSM.csv) : badges de couleurs + date dernière MAJ
    if (info != null) {
      if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
      final String dateRemise = info.dateRemise.trim().isNotEmpty
          ? info.dateRemise
          : info.dateMaj;
      final String extraInfo = info.isRemise
          ? 'Remise à disposition à partir du ${formatToFrDate(dateRemise)}'
          : 'dernière MAJ le ${formatToFrDate(info.dateMaj)}';
      final String statutLibelle = info.libelle;
      final Color color = ansmColor(statutLibelle);
      void onTap() {
        if (onOpenUrl != null) {
          onOpenUrl!(info.url);
        } else {
          openUrl(info.url);
        }
      }
      final String tooltipStatut = 'statut ANSM : ${ansmLabel(statutLibelle)} $extraInfo';
      line2Children.add(
        Tooltip(
          message: tooltipStatut,
          waitDuration: const Duration(milliseconds: 400),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ansmEmoji(statutLibelle),
                              style: const TextStyle(fontSize: 12),),
                          const SizedBox(width: 4),
                          Text(
                            ansmLabel(statutLibelle),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            extraInfo,
                            style: const TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Cliquer pour + d\'infos',
                  waitDuration: const Duration(milliseconds: 900),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5,),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: OffiboxColors.primary,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OffiboxColors.primary.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: OffiboxColors.primary,
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

    // Badge « plus d'infos » en ligne 2 après tous les autres badges (médicaments BDM).
    final showPlusInfosBdm = (statutsForCis != null && statutsForCis!.isNotEmpty) ||
        (tauxRemboursement != null && tauxRemboursement!.trim().isNotEmpty) ||
        (compositionLine != null && compositionLine!.trim().isNotEmpty) ||
        (listes != null && listes!.isNotEmpty);
    if (showPlusInfosBdm) {
      final isDisabled = item.isInactive || item.hospitalOnly == true || item.isNsfpEffective == true;
      if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
      line2Children.add(PlusInfosBadge(
        statuts: statutsForCis ?? const [],
        tauxRemboursement: tauxRemboursement,
        compositionLine: compositionLine,
        listes: listes ?? const [],
        isDisabled: isDisabled,
      ));
    }

    // Source : BDM affichée en ligne 3 après RCP et MEDDISPAR (voir result_line_3_actions.dart).
    if (line2Children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: hasBiosim ? 4 : 8,
        runSpacing: hasBiosim ? 4 : 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: line2Children,
      ),
    );
  }

    // ─────────────────────────────
    // 🔁 BDM / DM / LPP — code CIP (BDM), EAN (DM) en ligne 2 ; véto = pas de code en ligne 2 (GTIN/CIS retirés)
    // ─────────────────────────────
    final wrapChildren = <Widget>[
      if (item.cip13 != null && item.source != SourceType.veto)
        _CodeBadge(
          label: _codeLabel,
          value: _cleanCode(item.cip13!),
        ),
      if (item.cis != null && item.source != SourceType.veto)
        _CodeBadge(
          label: 'CIS',
          value: item.cis!,
        ),
    ];
    if (wrapChildren.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: wrapChildren,
      ),
    );
  }

  String get _codeLabel {
    switch (item.source) {
      case SourceType.veto:
        return 'GTIN';
      case SourceType.dm:
        return 'EAN';
      case SourceType.bdm:
      default:
        return 'CIP';
    }
  }
}

// ─────────────────────────────
// 🛑 BADGE ARRÊT DE COMMERCIALISATION (ligne 2 BDM, NSFP dans CIS_CIP_Dispo_Spec)
// ─────────────────────────────
class _ArretCommercialisationBadge extends StatelessWidget {
  const _ArretCommercialisationBadge({
    this.dateArret,
    this.url,
    this.onOpenUrl,
  });

  final String? dateArret;
  final String? url;
  final void Function(String)? onOpenUrl;

  static const _color = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    final label = (dateArret != null && dateArret!.trim().isNotEmpty)
        ? 'arrêt de commercialisation ($dateArret)'
        : 'arrêt de commercialisation';
    final canOpen = url != null && url!.trim().isNotEmpty && onOpenUrl != null;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
              fontFamily: 'Spinnaker',
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: canOpen
          ? 'Ouvrir la fiche ANSM (arrêt de commercialisation)'
          : 'Médicament en arrêt de commercialisation (CIS_CIP_Dispo_Spec)',
      child: canOpen
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onOpenUrl!(url!),
                child: content,
              ),
            )
          : content,
    );
  }
}

// ─────────────────────────────
// 🧬 BADGES BIOSIMILAIRE / BIORÉFÉRENT (ligne 2 BDM)
// ─────────────────────────────
class _BiosimilaireBadge extends StatelessWidget {
  const _BiosimilaireBadge({required this.bioreferent});

  final String bioreferent;

  static const _purple = Color(0xFF7C3AED);
  static const _url =
      'https://ansm.sante.fr/documents/reference/medicaments-biosimilaires';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openUrl(_url),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _purple),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧬', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'BIOSIMILAIRE de ${bioreferent.toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: _purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge « Infos dispensation » : ouvre une fenêtre blanche type plus d'infos avec le contenu de la colonne 5 (puces).
class _BiosimilaireInfosBadge extends StatelessWidget {
  const _BiosimilaireInfosBadge({required this.infoText});

  final String infoText;

  static const _purple = Color(0xFF7C3AED);

  void _showDialog(BuildContext context) {
    final bullets = infoText
        .split(RegExp(r'\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (bullets.isEmpty) bullets.add(infoText.trim());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius)),
        title: const Text(
          'INFOS DISPENSATION',
          style: TextStyle(fontFamily: 'Spinnaker', fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bullets
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Spinnaker',
                            height: 1.35,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            normalizeText(s),
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Spinnaker',
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDialog(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _purple.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 14, color: _purple),
              const SizedBox(width: 6),
              Text(
                'INFOS DISPENSATION',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Spinnaker',
                  fontWeight: FontWeight.w600,
                  color: _purple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge RCP (ligne 2, à côté du badge biosimilaire quand URL RCP présente).
// ignore: unused_element
class _RcpBadge extends StatelessWidget {
  const _RcpBadge({required this.url});

  final String url;

  static const _teal = Color(0xFF5A9094);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Accéder au RCP',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => openUrl(url),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _teal),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 14, color: _teal),
              SizedBox(width: 4),
              Text(
                'RCP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge rose "princeps: [nom]" pour les génériques (ex. princeps: Xanax). Clic → répertoire ANSM génériques.
class _GeneriqueEqualsBadge extends StatelessWidget {
  const _GeneriqueEqualsBadge({
    required this.princepsDisplayName,
    this.tooltipFullPrinceps,
  });

  final String princepsDisplayName;
  /// Libellé princeps complet (col B - col C) pour le tooltip.
  final String? tooltipFullPrinceps;

  static const _urlGeneriques =
      'https://ansm.sante.fr/documents/reference/repertoire-des-medicaments-generiques';
  static const _rose = Color(0xFFE91E8C);

  @override
  Widget build(BuildContext context) {
    final tooltip = tooltipFullPrinceps != null && tooltipFullPrinceps!.trim().isNotEmpty
        ? '${tooltipFullPrinceps!.trim()} — accès au répertoire des génériques'
        : 'accès au répertoire des génériques';
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => openUrl(_urlGeneriques),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _rose,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _rose),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'princeps: $princepsDisplayName',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne 2 princeps : libellé col 1 (avant parenthèses) + badge "princeps" (rose).
class _PrincepsLine2Widget extends StatelessWidget {
  const _PrincepsLine2Widget({required this.col1LabelBeforeParens});

  final String col1LabelBeforeParens;

  static const _rose = Color(0xFFE91E8C);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            col1LabelBeforeParens,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontFamily: 'Spinnaker',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _rose,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _rose),
          ),
          child: const Text(
            'princeps',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge MEDDISPAR (ligne 2, à la suite du badge générique princeps).
// ignore: unused_element
class _MeddisparBadge extends StatelessWidget {
  const _MeddisparBadge({required this.url});

  final String url;

  static const _orange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Fiche MEDDISPAR',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => openUrl(url),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _orange),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: _orange),
              SizedBox(width: 4),
              Text(
                'MEDDISPAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioreferentBadge extends StatelessWidget {
  const _BioreferentBadge();

  static const _purple = Color(0xFF7C3AED);
  static const _url =
      'https://www.ameli.fr/charente-maritime/pharmacien/exercice-professionnel/'
      'delivrance-produits-sante/regles-delivrance-prise-charge/'
      'medicaments-biosimilaires/regles-dispensation-et-substitution';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bioréférent',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => openUrl(_url),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _purple),
          ),
          child: const Text(
            'BIORÉFÉRENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: _purple,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────
// BADGE CODE AVEC COPIE (public pour ResultLine1)
// ─────────────────────────────
class CodeBadgeWithCopy extends StatelessWidget {
  const CodeBadgeWithCopy({
    super.key,
    required this.label,
    required this.value,
    required this.tooltip,
    this.leadingIcon,
    this.fontSize = 11,
  });

  final String label;
  final String value;
  final String tooltip;
  final IconData? leadingIcon;
  /// Taille de police du badge (défaut 11). Réduire à 10 en ligne 1 pour éviter la troncature.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final iconSize = fontSize.clamp(10.0, 12.0).round();
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 900),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label copié'),
              duration: const Duration(milliseconds: 900),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize <= 10 ? 6 : 10,
            vertical: fontSize <= 10 ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: iconSize.toDouble(), color: Colors.black54),
                SizedBox(width: fontSize <= 10 ? 3 : 4),
              ],
              Text(
                '$label : $value',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: fontSize <= 10 ? 4 : 6),
              Icon(Icons.copy, size: iconSize.toDouble(), color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────
// BADGE CODE (inchangé)
// ─────────────────────────────
class _CodeBadge extends StatelessWidget {
  final String label;
  final String value;

  const _CodeBadge({
    required this.label,
    required this.value,
  });

  bool get _isCip13 => label == 'CIP' && value.length == 13;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copier le code',
      waitDuration: const Duration(milliseconds: 900),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label copié'),
              duration: const Duration(milliseconds: 900),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCip13)
                _buildCipRichText()
              else
                Text(
                  '$label : $value',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.copy,
                size: 12,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 💊 Découpe CIP13 : 34009 1234567 8
  Widget _buildCipRichText() {
    final part1 = value.substring(0, 5);
    final cip7 = value.substring(5, 12);
    final last = value.substring(12);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          letterSpacing: 0.2,
        ),
        children: [
          const TextSpan(text: 'CIP : '),
          TextSpan(text: '$part1 '),
          TextSpan(
            text: cip7,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' $last'),
        ],
      ),
    );
  }
}
