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
import 'package:offibox/ui/widgets/offibox_tooltip.dart';
import 'package:offibox/ui/widgets/pharmaradio_flash_panel_below_bar.dart' show kPharmaradioFlashInfoUrl;
import 'package:offibox/ui/spans/common_spans.dart';
import 'package:offibox/utils/normalize.dart' show normalizePrincepsKey;

/// URLs des calendriers vaccinaux (badges pour les médicaments dont le libellé contient "vaccin").
const String kCalendrierVaccinal2025Url =
    'https://sante.gouv.fr/IMG/pdf/pdf_calendrier_vaccinal-12-2025.pdf';
/// Page « Carte postale » du calendrier simplifié (s’ouvre dans le navigateur ; le lien direct content/download pouvait échouer au clic).
const String kCalendrierSimplifieUrl =
    'https://www.santepubliquefrance.fr/determinants-de-sante/vaccination/documents/carte-postale/calendrier-simplifie-des-vaccinations-2025-carte-postale';

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

/// Formate le nom princeps (ex. "STILNOX" → "Stilnox") pour l'affichage du badge "princeps : X".
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
  return path.endsWith('.xls') || path.endsWith('.xlsx') || path.endsWith('.ods');
}

/// True si l'URL pointe vers un document Word / Open Office texte (.doc, .docx, .odt).
bool _isWordUrl(String url) {
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.doc') || path.endsWith('.docx') || path.endsWith('.odt');
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

/// Extrait une DCI depuis un libellé générique (col A du CSV génériques 2026).
/// Ex: "ACIDE ACETYLSALICYLIQUE 75 MG" -> "ACIDE ACETYLSALICYLIQUE"
String dciFromGenericLabel(String label) {
  final t = label.trim();
  if (t.isEmpty) return '';
  final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final kept = <String>[];
  for (final p in parts) {
    // Dès qu'on voit un dosage/numéro, on s'arrête.
    if (RegExp(r'^\d').hasMatch(p) || RegExp(r'\d').hasMatch(p)) break;
    // Stop sur unités usuelles si jamais le CSV ne met pas de nombre (rare)
    final up = p.toUpperCase();
    if (up == 'MG' || up == 'G' || up == 'MCG' || up == 'µG' || up == 'UI') break;
    kept.add(p);
  }
  return kept.isEmpty ? parts.first : kept.join(' ');
}

/// Extrait le(s) DCI depuis la chaîne composition BDM (format "DCI : dosage" ou "DCI1 : d1 ; DCI2 : d2").
/// Retourne une chaîne pour le badge, ex. "travoprost" ou "paracetamol, cafeine".
String dciFromCompositionLine(String compositionLine) {
  final raw = compositionLine.trim();
  if (raw.isEmpty) return '';
  final segments = raw.split(RegExp(r'\s*;\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty);
  final dcis = <String>[];
  for (final seg in segments) {
    final idx = seg.indexOf(':');
    if (idx > 0) {
      final dci = seg.substring(0, idx).trim();
      if (dci.isNotEmpty) dcis.add(dci.toLowerCase());
    } else if (seg.isNotEmpty) {
      dcis.add(seg.toLowerCase());
    }
  }
  return dcis.join(', ');
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
  /// Vidéo de démonstration (videos.csv) : affichée en ligne 2 quand injecté, à droite de RCP.
  final Map<String, String>? videosByCip13;
  /// Au clic sur le pill « vidéo de démonstration » : affiche le panneau vidéo thérapeutique.
  final void Function(String url)? onOpenTherapeuticVideo;
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
  /// URL fiche VOC patient (OMÉDIT) — affichée en ligne 2 quand injecté.
  final String? vocPatientUrl;
  /// URL fiche VOC pro (OMÉDIT) — affichée en ligne 2 quand injecté.
  final String? vocProUrl;
  /// Au clic sur le badge DCI (princeps) : lance une recherche avec la DCI pour afficher les génériques sous la barre.
  final void Function(String dci)? onDciTap;

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
    this.videosByCip13,
    this.onOpenTherapeuticVideo,
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
    this.vocPatientUrl,
    this.vocProUrl,
    this.onDciTap,
  });

  String _cleanCode(String value) {
    return value.replaceAll('"', '').replaceAll("'", '');
  }

  bool get _hasAnyCode {
  // 🏥 Organismes : uniquement si adresse
  if (item.source == SourceType.amc || item.source == SourceType.amo) {
    return item.groupLabel != null && item.groupLabel!.isNotEmpty;
  }

  // 🟪 Annuaires (CRPV, Centres anti poison, CHU, CEIP-A) — ligne 2 = adresse ; annuaire RPPS + tél/fax (sans doublon)
  if (item.source == SourceType.pharmacovigilance ||
      item.source == SourceType.centresAntiPoison ||
      item.source == SourceType.chu ||
      item.source == SourceType.ceipAddictovigilance ||
      item.source == SourceType.annuaireSanteRpps) {
    if (item.source == SourceType.annuaireSanteRpps) {
      final hasAddress = item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
      final hasPhone = item.phone != null && item.phone!.trim().isNotEmpty;
      final isLiberal = item.commentaire?.trim() == 'mode=liberal';
      final hasFax = isLiberal && item.fax != null && item.fax!.trim().isNotEmpty;
      return hasAddress || hasPhone || hasFax;
    }
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

  // 📋 Codes actes : pas de ligne 2 (tout en ligne 1 : Code — Libellé — Tarif)
  if (item.source == SourceType.codesActes) {
    return false;
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
      padding: const EdgeInsets.only(top: resultLineGap),
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
          OffiboxTooltip(
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
  // 🟪 Annuaires (CRPV, Centres anti poison, CHU, CEIP-A) — ADRESSE (ligne 2) ; annuaire RPPS + Tél/Fax ; CEIP-A + badge "site internet"
  // ─────────────────────────────
  if (item.source == SourceType.pharmacovigilance ||
      item.source == SourceType.centresAntiPoison ||
      item.source == SourceType.chu ||
      item.source == SourceType.ceipAddictovigilance ||
      item.source == SourceType.annuaireSanteRpps) {
    final hasAddress = item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
    final address = hasAddress ? normalizeText(item.groupLabel!) : '';
    final isAnnuaireRpps = item.source == SourceType.annuaireSanteRpps;
    final isLiberal = item.commentaire?.trim() == 'mode=liberal';
    final phoneRaw = (item.phone ?? '').replaceAll('"', '').replaceAll("'", '').trim();
    final faxRaw = (item.fax ?? '').replaceAll('"', '').replaceAll("'", '').trim();
    // Tél/Fax annuaire RPPS : affichés en ligne 3 (badges comme RPPS/MSS), pas ici. CRPV et CEIP-A : afficher fax si présent.
    final showFax = !isAnnuaireRpps && (isLiberal || item.source == SourceType.pharmacovigilance || item.source == SourceType.ceipAddictovigilance) && faxRaw.isNotEmpty && faxRaw != phoneRaw;
    final showPhone = !isAnnuaireRpps && phoneRaw.isNotEmpty;

    if (!hasAddress && !showPhone && !showFax) return const SizedBox.shrink();

    final children = <Widget>[
      if (isAnnuaireRpps && hasAddress) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black26),
          ),
          child: const Text(
            'Structure',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 6),
      ],
      if (hasAddress) ...[
        Text(
          address,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontFamily: 'Spinnaker',
          ),
        ),
        OffiboxTooltip(
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
      if (showPhone) ...[
        if (hasAddress) const SizedBox(width: 10),
        CodeBadgeWithCopy(
          label: 'Tél',
          value: phoneRaw,
          tooltip: 'Copier le numéro',
          leadingIcon: Icons.phone,
        ),
      ],
      if (showFax) ...[
        if (showPhone || hasAddress) const SizedBox(width: 6),
        CodeBadgeWithCopy(
          label: 'Fax',
          value: faxRaw,
          tooltip: 'Copier le fax',
          leadingIcon: Icons.fax,
        ),
      ],
      // CEIP-A : badge "site internet" → addictovigilance.fr
      if (item.source == SourceType.ceipAddictovigilance && (item.url?.trim().isNotEmpty ?? false)) ...[
        if (hasAddress || showPhone || showFax) const SizedBox(width: 10),
        HoverPillButton(
          label: 'site internet',
          icon: Icons.language,
          tooltip: 'https://addictovigilance.fr/',
          onTap: () => openUrl(item.url!.trim()),
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: resultLineGap),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: children,
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
      padding: const EdgeInsets.only(top: resultLineGap),
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
  // 🏷️ Mots-clés — ligne 2 : en liste = common span + libellé (col B) ; puis pills (col D, E/F, G/H, I/J)
  // ─────────────────────────────
  if (item.source == SourceType.keyword) {
    final pills = <Widget>[];
    final urlLigne1 = item.url?.trim();
    Widget? keywordLibelleRow;
    if (!isInjected) {
      final libelle = (item.commentaire ?? item.label).trim();
      if (libelle.isNotEmpty) {
        keywordLibelleRow = Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              children: [
                keywordPlusAndOutilsMetierSpan(),
                TextSpan(text: ' ${libelle.toUpperCase()}'),
                if (item.keywordAppearanceDate != null && item.keywordAppearanceDate!.trim().isNotEmpty) ...[
                  const TextSpan(text: ' '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Tooltip(
                      message: item.keywordAppearanceDate!.trim(),
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
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    void addPill(String name, String url, {bool isYouTube = false}) {
      if (name.isEmpty || url.isEmpty) return;
      final urlTrim = url.trim();
      final useYouTubePanel = isYouTube && onOpenYouTubeVideo != null;
      // Toujours afficher l'icône YouTube quand l'URL est une vidéo,
      // même dans la liste de résultats (avant injection dans la barre).
      final showYouTubeIcon = isYouTube;
      final isPdf = _isPdfUrl(url);
      final isWord = _isWordUrl(url);
      final isXls = _isXlsUrl(url);
      // XLS/PDF/Word : afficher tout le libellé (badge hover pill) — pas de troncature à 160px
      final maxLabelWidth = (isXls || isPdf || isWord) ? 500.0 : null;
      pills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: showYouTubeIcon || isPdf || isWord || isXls ? null : iconForUrl(url),
        iconWidget: showYouTubeIcon
            ? SvgPicture.asset(
                'assets/icons/youtube.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              )
            : isPdf
                ? _pdfIconWidget()
                : isWord
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

    // Pill pour url principale (col E) : PDF → "document" ; Word/ODT → "document" ; XLS/ODS → "tableur"
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
        ),);
      } else if (_isWordUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'document',
          iconWidget: _pdfIconWidget(),
          tooltip: 'Ouvrir le document (Word / Open Office)',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ),);
      } else if (_isXlsUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'tableur',
          iconWidget: _excelIconWidget(),
          tooltip: 'Ouvrir le fichier Excel / tableur',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ),);
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
    // Fallback : si aucune pill et qu'on a url ligne 1 (YouTube ou PDF/Word/tableur uniquement)
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
        ),);
      } else if (_isWordUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'document',
          iconWidget: _pdfIconWidget(),
          tooltip: 'Ouvrir le document (Word / Open Office)',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ),);
      } else if (_isXlsUrl(urlLigne1)) {
        pills.add(HoverPillButton(
          label: 'tableur',
          iconWidget: _excelIconWidget(),
          tooltip: 'Ouvrir le fichier Excel / tableur',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlLigne1.trim());
            } else {
              openUrl(urlLigne1.trim());
            }
          },
        ),);
      }
      // URL site web : pas de pill "site internet", l’icône external link en ligne 1 suffit
    }
    if (keywordLibelleRow != null || pills.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (keywordLibelleRow != null) keywordLibelleRow,
            if (pills.isNotEmpty)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: pills,
              ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────
  // 🌐 Sites web — ligne 2 : en liste = common span + libellé (col B) ; puis HoverPill(s) E/F, G/H, I/J
  // ─────────────────────────────
  if (item.source == SourceType.siteWeb) {
    final pills = <Widget>[];
    Widget? siteWebLibelleRow;
    if (!isInjected) {
      final libelle = (item.commentaire ?? item.label).trim();
      if (libelle.isNotEmpty) {
        siteWebLibelleRow = Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              children: [
                siteInternetBadgeSpan(),
                TextSpan(text: ' ${libelle.toUpperCase()}'),
              ],
            ),
          ),
        );
      }
    }
    final isPharmaradio = item.label.toLowerCase().contains('pharmaradio') ||
        (item.commentaire?.toLowerCase().contains('pharmaradio') ?? false) ||
        item.labelRaw.toLowerCase().contains('pharmaradio');
    if (isPharmaradio && onOpenPharmaradioFlash != null) {
      pills.add(HoverPillButton(
        label: 'Flash info du jour',
        icon: Icons.newspaper,
        tooltip: 'Afficher le flash info Pharmaradio sous la barre',
        onTap: onOpenPharmaradioFlash!,
      ),);
      pills.add(HoverPillButton(
        label: 'Player Pharmaradio',
        icon: Icons.play_circle_outline,
        tooltip: 'Écouter Pharmaradio',
        onTap: () => openUrlExternal(kPharmaradioFlashInfoUrl),
      ),);
    }
    void addPill(String name, String url, {bool isYouTube = false}) {
      if (name.isEmpty || url.isEmpty) return;
      if (isPharmaradio && name.toLowerCase().contains('flash info du jour')) return;
      final urlTrim = url.trim();
      final useYouTubePanel = isYouTube && onOpenYouTubeVideo != null;
      // Toujours afficher l'icône YouTube quand l'URL est une vidéo,
      // même dans la liste de résultats (avant injection dans la barre).
      final showYouTubeIcon = isYouTube;
      final isPdf = _isPdfUrl(url);
      final isWord = _isWordUrl(url);
      final isXls = _isXlsUrl(url);
      final maxLabelWidth = (isXls || isPdf || isWord) ? 500.0 : null;
      pills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: showYouTubeIcon || isPdf || isWord || isXls ? null : iconForUrl(url),
        iconWidget: showYouTubeIcon
            ? SvgPicture.asset(
                'assets/icons/youtube.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              )
            : isPdf
                ? _pdfIconWidget()
                : isWord
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
    // Ne pas ajouter de pill "site internet" quand l'icône external link est déjà en ligne 1 (item.url)
    final hasMainUrl = item.url != null && item.url!.trim().isNotEmpty;
    bool skipSiteInternetPill(String name) =>
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
    if (siteWebLibelleRow != null || pills.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (siteWebLibelleRow != null) siteWebLibelleRow,
            if (pills.isNotEmpty)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: pills,
              ),
          ],
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
      final isWord = _isWordUrl(url);
      final isXls = _isXlsUrl(url);
      // XLS/PDF/Word : afficher tout le libellé du badge
      final maxLabelWidth = (isXls || isPdf || isWord) ? 500.0 : null;
      final isCatalogueBadge = name == 'Catalogue';
      if (isCatalogueBadge && onOpenCataloguePanel != null) {
        cataloguePills.add(HoverPillButton(
          label: name,
          maxLabelWidth: maxLabelWidth,
          icon: isPdf || isWord || isXls ? null : iconForUrl(url),
          iconWidget: isPdf ? _pdfIconWidget() : isWord ? _pdfIconWidget() : isXls ? _excelIconWidget() : _externalLinkIconWidget(),
          tooltip: url,
          onTap: onOpenCataloguePanel!,
        ),);
        return;
      }
      cataloguePills.add(HoverPillButton(
        label: name,
        maxLabelWidth: maxLabelWidth,
        icon: isPdf || isWord || isXls ? null : iconForUrl(url),
        iconWidget: isPdf ? _pdfIconWidget() : isWord ? _pdfIconWidget() : isXls ? _excelIconWidget() : _externalLinkIconWidget(),
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
          icon: _isPdfUrl(item.badge1Url!) || _isWordUrl(item.badge1Url!) || _isXlsUrl(item.badge1Url!) ? null : iconForUrl(item.badge1Url!),
          iconWidget: _isPdfUrl(item.badge1Url!) ? _pdfIconWidget() : _isWordUrl(item.badge1Url!) ? _pdfIconWidget() : _isXlsUrl(item.badge1Url!) ? _excelIconWidget() : _externalLinkIconWidget(),
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
          icon: _isPdfUrl(item.badge1Url!) || _isWordUrl(item.badge1Url!) || _isXlsUrl(item.badge1Url!) ? null : iconForUrl(item.badge1Url!),
          iconWidget: _isPdfUrl(item.badge1Url!) ? _pdfIconWidget() : _isWordUrl(item.badge1Url!) ? _pdfIconWidget() : _isXlsUrl(item.badge1Url!) ? _excelIconWidget() : _externalLinkIconWidget(),
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
        padding: const EdgeInsets.only(top: resultLineGap),
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
    /// Fiches OMÉDIT (VOC) : affichées sur une dernière ligne dédiée pour ne pas empiéter sur le texte « mise à jour ».
    final vocLineChildren = <Widget>[];

    final showPlusInfosBdm = (statutsForCis != null && statutsForCis!.isNotEmpty) ||
        (tauxRemboursement != null && tauxRemboursement!.trim().isNotEmpty) ||
        (compositionLine != null && compositionLine!.trim().isNotEmpty) ||
        (listes != null && listes!.isNotEmpty);

    // Badges S/AS, EXCEPTION, OTC, PIH, HOP : affichés uniquement en ligne 1 (ResultLine1), pas ici.

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
      ),);
      line2Children.add(const SizedBox(width: 6));
    }

    // Produit concerné par un rappel de lot ANSM : badge rouge "rappel de lot" (ligne 2), même taille que RCP, < 2 mois uniquement.
    final matchesLastRappel = ansmLastRappel != null &&
        isProductConcernedByLastRappel(item, ansmLastRappel!);
    final inCsvRappel = recalledProductNames != null &&
        item.labelRaw.trim().isNotEmpty &&
        recalledProductNames!.contains(normalizeProductNameForRappel(item.labelRaw));
    final isConcerned = matchesLastRappel || inCsvRappel;
    final rappelMoins2Mois = ansmLastRappel != null && isRappelRecent(ansmLastRappel!, maxDays: 60);
    final rappelUrl = ansmLastRappel?.url.trim();

    if (isConcerned && rappelMoins2Mois && rappelUrl != null && rappelUrl.isNotEmpty) {
      if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));
      line2Children.add(_RappelDeLotBadge(
        url: rappelUrl,
        onOpenUrl: onOpenUrl,
      ),);
    }

    // Badge générique 2026 : "princeps : [nom princeps col. princeps A]" (rose), pas la DCI ; RCP et MEDDISPAR en HoverPill
    final generique2026Info = (generiques2026ByCis != null && cisKey.isNotEmpty)
        ? generiques2026ByCis![cisKey]
        : null;
        if (generique2026Info != null) {
      if (item.isGeneric == true) {
        // Génériques : on n'affiche plus la DCI, mais uniquement le badge rose "princeps : [nom]".
        // Au temps pour moi, tu as dit : "pour le  générique : à la place du badge DCi : princeps : le princeps"
        final princepsLabel = generique2026Info.princepsDisplay.trim();
        if (princepsLabel.isNotEmpty) {
          final shortName = shortPrincepsDisplayForBadge(princepsLabel);
          
          String tooltip = princepsLabel;
          String dciToTap = '';
          final col1Label = col1BeforeParentheses(generique2026Info.genericNameColA);
          if (col1Label.isNotEmpty) {
             final dci = dciFromGenericLabel(col1Label);
             dciToTap = dci.trim().isNotEmpty ? dci : col1Label;
             tooltip = 'DCI : $dciToTap\n\n(Princeps complet : $princepsLabel)';
          }
          
          line2Children.add(_GeneriqueEqualsBadge(
            princepsDisplayName: shortName,
            tooltipFullPrinceps: tooltip,
            dciForTap: dciToTap,
            onDciTap: onDciTap,
          ),);
          // On rajoute également le badge DCI classique (bleu) au clic car on veut garder le clic de la dci pour générique si possible
          if (dciToTap.isNotEmpty) {
            line2Children.add(const SizedBox(width: 6));
            line2Children.add(_PrincepsLine2Widget(
              dci: dciToTap,
              onDciTap: onDciTap,
            ),);
          }
        }
      } else {
        // Princeps : on affiche la DCI (au clic), ET on affiche le premier générique connu (en rose) au lieu du badge DCI standard.
        // On récupère le groupe générique (col A).
        final col1Label = col1BeforeParentheses(generique2026Info.genericNameColA);
        if (col1Label.isNotEmpty) {
          final dci = dciFromGenericLabel(col1Label);
          final dciStr = dci.trim().isNotEmpty ? dci : col1Label;
          
          // Récupérer le nom du générique (on l'affiche dans un badge rose)
          final genericName = generiques2026PrincepsKeyToGenericName != null 
              ? generiques2026PrincepsKeyToGenericName![normalizePrincepsKey(generique2026Info.princepsDisplay)] 
              : null;
              
          if (genericName != null && genericName.isNotEmpty) {
            line2Children.add(_PrincepsLine2Widget(
              dci: dciStr,
              onDciTap: onDciTap,
            ),);
            // On ajoute le common span DCI (bleu)
            line2Children.add(const SizedBox(width: 6));
            line2Children.add(_PrincepsEqualsGeneriqueBadge(
              genericDisplayName: shortGenericDisplayForBadge(genericName),
              tooltipFullGeneric: genericName,
              dciForTap: dciStr,
              onDciTap: onDciTap,
            ),);
          } else {
            // S'il n'y a pas de générique connu (ou introuvable), on affiche le badge DCI classique
            line2Children.add(_PrincepsLine2Widget(
              dci: dciStr,
              onDciTap: onDciTap,
            ),);
          }
          
          if (showPlusInfosBdm) {
            line2Children.add(const SizedBox(width: 6));
            final isDisabled = item.isInactive || item.hospitalOnly == true || item.isNsfpEffective == true;
            line2Children.add(PlusInfosBadge(
              statuts: statutsForCis ?? const [],
              tauxRemboursement: tauxRemboursement,
              compositionLine: compositionLine,
              listes: listes ?? const [],
              isDisabled: isDisabled,
            ),);
          }
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

      // Vidéo de démonstration (videos.csv) : afficher à droite de RCP quand injecté.
      if (isInjected &&
          onOpenTherapeuticVideo != null &&
          videosByCip13 != null &&
          item.cip13 != null) {
        final cip = item.cip13!.replaceAll(RegExp(r'\D'), '').trim();
        final vurl = cip.isNotEmpty ? videosByCip13![cip]?.trim() : null;
        if (vurl != null && vurl.isNotEmpty) {
          if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));
          line2Children.add(HoverPillButton(
            label: 'vidéo de démonstration',
            icon: Icons.video_library_outlined,
            tooltip: "Outils d'aide à l'utilisation des thérapeutiques inhalées (SPLF)",
            onTap: () => onOpenTherapeuticVideo!(vurl),
            maxLabelWidth: 240,
          ),);
        }
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
      // OMÉDIT (VOC) : fiches patient/pro sur une dernière ligne dédiée (voir plus bas, vocLineChildren).
      if (isInjected) {
        const maxLabelWidth = 380.0;
        if (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty) {
          if (vocLineChildren.isNotEmpty) vocLineChildren.add(const SizedBox(width: 6));
          final url = vocPatientUrl!.trim();
          vocLineChildren.add(HoverPillButton(
            label: 'fiche à destination des patients OMÉDIT',
            icon: Icons.person_outline,
            tooltip: url,
            maxLabelWidth: maxLabelWidth,
            trailingWidget: _pdfIconWidget(),
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(url);
              } else {
                openUrl(url);
              }
            },
          ),);
        }
        if (vocProUrl != null && vocProUrl!.trim().isNotEmpty) {
          if (vocLineChildren.isNotEmpty) vocLineChildren.add(const SizedBox(width: 6));
          final url = vocProUrl!.trim();
          vocLineChildren.add(HoverPillButton(
            label: 'fiche à destination des professionnels de santé OMÉDIT',
            icon: Icons.medical_services_outlined,
            tooltip: url,
            maxLabelWidth: maxLabelWidth,
            trailingWidget: _pdfIconWidget(),
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(url);
              } else {
                openUrl(url);
              }
            },
          ),);
        }
      }
      // Badges calendriers vaccinaux pour médicaments dont le libellé contient "vaccin".
      final labelForVaccin = '${item.label} ${item.labelRaw}'.toLowerCase();
      if (item.source == SourceType.bdm && labelForVaccin.contains('vaccin')) {
        if (line2Children.isNotEmpty) line2Children.add(const SizedBox(width: 6));
        line2Children.add(HoverPillButton(
          label: 'Calendrier vaccinal 2025',
          icon: Icons.calendar_month_outlined,
          tooltip: 'Calendrier vaccinal 2025 (version Décembre 2025)',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(kCalendrierVaccinal2025Url);
            } else {
              openUrl(kCalendrierVaccinal2025Url);
            }
          },
        ),);
        line2Children.add(const SizedBox(width: 6));
        line2Children.add(HoverPillButton(
          label: 'Calendrier simplifié',
          icon: Icons.calendar_view_month_outlined,
          tooltip: 'Calendrier simplifié des vaccinations',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(kCalendrierSimplifieUrl);
            } else {
              openUrl(kCalendrierSimplifieUrl);
            }
          },
        ),);
      }
    }
    // Badge biosimilaire de [bioréférent]. RCP et MEDDISPAR restent en ligne 3 (hover pills).
    // Espacement réduit entre badges pour biosimilaires afin de laisser la place à l’icône Source BDNM.
    final spacingBetweenBadges = hasBiosim ? 2.0 : 3.0;
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
        OffiboxTooltip(
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
                          horizontal: 6, vertical: 3,),
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
                OffiboxTooltip(
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

    // Badge « plus d'infos » en ligne 2 (après les autres badges). Déjà ajouté à droite du badge DCI pour les princeps.
    if (showPlusInfosBdm && (generique2026Info == null || item.isGeneric == true)) {
      final isDisabled = item.isInactive || item.hospitalOnly == true || item.isNsfpEffective == true;
      if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
      line2Children.add(PlusInfosBadge(
        statuts: statutsForCis ?? const [],
        tauxRemboursement: tauxRemboursement,
        compositionLine: compositionLine,
        listes: listes ?? const [],
        isDisabled: isDisabled,
      ),);
    }

    // Non génériques : RCP et MEDDISPAR sur la même ligne que + d'infos (ligne 2).
    if (generique2026Info == null) {
      if (item.url != null && item.url!.trim().isNotEmpty) {
        if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
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

      // Vidéo de démonstration (videos.csv) : afficher à droite de RCP quand injecté.
      if (isInjected &&
          onOpenTherapeuticVideo != null &&
          videosByCip13 != null &&
          item.cip13 != null) {
        final cip = item.cip13!.replaceAll(RegExp(r'\D'), '').trim();
        final vurl = cip.isNotEmpty ? videosByCip13![cip]?.trim() : null;
        if (vurl != null && vurl.isNotEmpty) {
          if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
          line2Children.add(HoverPillButton(
            label: 'vidéo de démonstration',
            icon: Icons.video_library_outlined,
            tooltip: "Outils d'aide à l'utilisation des thérapeutiques inhalées (SPLF)",
            onTap: () => onOpenTherapeuticVideo!(vurl),
            maxLabelWidth: 240,
          ),);
        }
      }
      if (item.meddisparUrl != null && item.meddisparUrl!.trim().isNotEmpty) {
        if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
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
      // OMÉDIT (VOC) : fiches patient/pro sur une dernière ligne dédiée (voir plus bas, vocLineChildren).
      if (isInjected) {
        const maxLabelWidth = 380.0;
        if (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty) {
          if (vocLineChildren.isNotEmpty) vocLineChildren.add(SizedBox(width: spacingBetweenBadges));
          final url = vocPatientUrl!.trim();
          vocLineChildren.add(HoverPillButton(
            label: 'fiche à destination des patients OMÉDIT',
            icon: Icons.person_outline,
            tooltip: url,
            maxLabelWidth: maxLabelWidth,
            trailingWidget: _pdfIconWidget(),
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(url);
              } else {
                openUrl(url);
              }
            },
          ),);
        }
        if (vocProUrl != null && vocProUrl!.trim().isNotEmpty) {
          if (vocLineChildren.isNotEmpty) vocLineChildren.add(SizedBox(width: spacingBetweenBadges));
          final url = vocProUrl!.trim();
          vocLineChildren.add(HoverPillButton(
            label: 'fiche à destination des professionnels de santé OMÉDIT',
            icon: Icons.medical_services_outlined,
            tooltip: url,
            maxLabelWidth: maxLabelWidth,
            trailingWidget: _pdfIconWidget(),
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(url);
              } else {
                openUrl(url);
              }
            },
          ),);
        }
      }
      // Badges calendriers vaccinaux pour médicaments BDM dont le libellé contient "vaccin".
      final labelForVaccin = '${item.label} ${item.labelRaw}'.toLowerCase();
      if (item.source == SourceType.bdm && labelForVaccin.contains('vaccin')) {
        if (line2Children.isNotEmpty) line2Children.add(SizedBox(width: spacingBetweenBadges));
        line2Children.add(HoverPillButton(
          label: 'Calendrier vaccinal 2025',
          icon: Icons.calendar_month_outlined,
          tooltip: 'Calendrier vaccinal 2025 (version Décembre 2025)',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(kCalendrierVaccinal2025Url);
            } else {
              openUrl(kCalendrierVaccinal2025Url);
            }
          },
        ),);
        line2Children.add(SizedBox(width: spacingBetweenBadges));
        line2Children.add(HoverPillButton(
          label: 'Calendrier simplifié',
          icon: Icons.calendar_view_month_outlined,
          tooltip: 'Calendrier simplifié des vaccinations',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(kCalendrierSimplifieUrl);
            } else {
              openUrl(kCalendrierSimplifieUrl);
            }
          },
        ),);
      }
    }

    // Source : BDM affichée en ligne 3 après RCP et MEDDISPAR (voir result_line_3_actions.dart).
    if (line2Children.isEmpty && vocLineChildren.isEmpty) return const SizedBox.shrink();

    final runSpacing = hasBiosim ? 2.0 : 3.0;
    final spacing = hasBiosim ? 2.0 : 4.0;
    if (vocLineChildren.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: line2Children,
        ),
      );
    }
    // Fiches OMÉDIT sur une dernière ligne dédiée pour ne pas empiéter sur le texte « mise à jour ».
    return Padding(
      padding: const EdgeInsets.only(top: resultLineGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line2Children.isNotEmpty)
            Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: line2Children,
            ),
          if (line2Children.isNotEmpty) SizedBox(height: runSpacing),
          Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: vocLineChildren,
          ),
        ],
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
      padding: const EdgeInsets.only(top: resultLineGap),
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

    return OffiboxTooltip(
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

/// Badge « dispensation biosimilaire » rose (même couleur que « biosimilaire de ») : tooltip « infos dispensation », au clic ouvre la fenêtre avec le contenu colonne 5 (puces).
class _BiosimilaireInfosBadge extends StatelessWidget {
  const _BiosimilaireInfosBadge({required this.infoText});

  final String infoText;

  static const _rose = Color(0xFFC2185B);

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
    return OffiboxTooltip(
      message: 'infos dispensation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDialog(context),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _rose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _rose, width: 1),
            ),
            child: const Text(
              'dispensation biosimilaire',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Spinnaker',
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: _rose,
              ),
            ),
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
    return OffiboxTooltip(
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

/// Badge rouge "rappel de lot" (ligne 2), même taille que RCP. Tooltip "plus d'infos", clic → lien ANSM.
class _RappelDeLotBadge extends StatelessWidget {
  const _RappelDeLotBadge({required this.url, this.onOpenUrl});

  final String url;
  final void Function(String url)? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return OffiboxTooltip(
      message: 'plus d\'infos',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () {
          if (onOpenUrl != null) {
            onOpenUrl!(url);
          } else {
            openUrl(url);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: OffiboxWindowUI.tickerInfosRed,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'rappel de lot',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge rose "princeps : [nom]" pour les génériques (ex. princeps : Stilnox). Clic → répertoire ANSM génériques.
class _GeneriqueEqualsBadge extends StatelessWidget {
  const _GeneriqueEqualsBadge({
    super.key,
    required this.princepsDisplayName,
    this.tooltipFullPrinceps,
    this.dciForTap = '',
    this.onDciTap,
  });

  final String princepsDisplayName;
  /// Libellé princeps complet (col B - col C) pour le tooltip.
  final String? tooltipFullPrinceps;
  final String dciForTap;
  final void Function(String)? onDciTap;

  static const _urlGeneriques =
      'https://ansm.sante.fr/documents/reference/repertoire-des-medicaments-generiques';
  static const _rose = Color(0xFFE91E8C);
  static const double _pillHeight = 30.8;

  @override
  Widget build(BuildContext context) {
    final tooltip = tooltipFullPrinceps != null && tooltipFullPrinceps!.trim().isNotEmpty
        ? '${tooltipFullPrinceps!.trim()}\n\nclic : rechercher la DCI (ou accès au répertoire)'
        : 'accès au répertoire des génériques';
    return OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () {
          if (onDciTap != null && dciForTap.isNotEmpty) {
            onDciTap!(dciForTap);
          } else {
            openUrl(_urlGeneriques);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: _pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
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
                'princeps : $princepsDisplayName',
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

/// Badge rose "générique : [nom]" pour les princeps. Clic → recherche de la DCI (ou accès répertoire).
class _PrincepsEqualsGeneriqueBadge extends StatelessWidget {
  const _PrincepsEqualsGeneriqueBadge({
    required this.genericDisplayName,
    this.tooltipFullGeneric,
    required this.dciForTap,
    this.onDciTap,
  });

  final String genericDisplayName;
  final String? tooltipFullGeneric;
  final String dciForTap;
  final void Function(String)? onDciTap;

  static const _urlGeneriques =
      'https://ansm.sante.fr/documents/reference/repertoire-des-medicaments-generiques';
  static const _rose = Color(0xFFE91E8C);
  static const double _pillHeight = 30.8;

  @override
  Widget build(BuildContext context) {
    final tooltip = tooltipFullGeneric != null && tooltipFullGeneric!.trim().isNotEmpty
        ? 'DCI : $dciForTap\n\n(ex. de générique : ${tooltipFullGeneric!.trim()})'
        : 'DCI : $dciForTap';
    
    return OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () {
          if (onDciTap != null) {
            onDciTap!(dciForTap);
          } else {
            openUrl(_urlGeneriques);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: _pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
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
                'générique : $genericDisplayName',
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

/// Renvoie le premier mot du libellé pour affichage dans le badge
String shortGenericDisplayForBadge(String genericName) {
  if (genericName.isEmpty) return '';
  final parts = genericName.split(RegExp(r'\s+'));
  return parts.isNotEmpty ? parts.first.toUpperCase() : genericName.toUpperCase();
}

/// Ligne 2 princeps : badge rose clair ": DCI : avec la composition [composition]" (même style que l’ancien badge princeps).
class _PrincepsLine2Widget extends StatelessWidget {
  const _PrincepsLine2Widget({
    super.key,
    required this.dci,
    this.onDciTap,
  });

  /// DCI (ex. "ZOLPIDEM") pour le libellé "DCI : zolpidem ".
  final String dci;
  /// Au clic : lance une recherche avec la DCI pour afficher les génériques sous la barre.
  final void Function(String dci)? onDciTap;

  static const _teal = Color(0xFF5A9094);
  static const double _pillHeight = 30.8;

  @override
  Widget build(BuildContext context) {
    final dciLower = dci.trim().toLowerCase();
    final badgeLabel = 'DCI : $dciLower ';
    final pill = Container(
      height: _pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _teal.withValues(alpha: 0.4), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _teal,
        ),
      ),
    );
    final wrapped = onDciTap != null
        ? InkWell(
            onTap: () => onDciTap!(dciLower),
            borderRadius: BorderRadius.circular(999),
            child: pill,
          )
        : pill;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OffiboxTooltip(
          message: onDciTap != null ? 'afficher la liste des génériques' : badgeLabel,
          waitDuration: const Duration(milliseconds: 500),
          child: wrapped,
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
    return OffiboxTooltip(
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
    return OffiboxTooltip(
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
    this.leadingIconSize,
  });

  final String label;
  final String value;
  final String tooltip;
  final IconData? leadingIcon;
  /// Taille de police du badge (défaut 11). Réduire à 10 en ligne 1 pour éviter la troncature.
  final double fontSize;
  /// Taille des icônes (leading + copy). Si null, dérivée de [fontSize].
  final double? leadingIconSize;

  @override
  Widget build(BuildContext context) {
    final iconSize = (leadingIconSize ?? fontSize.clamp(10.0, 12.0)).toDouble();
    return OffiboxTooltip(
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
                Icon(leadingIcon, size: iconSize, color: Colors.black54),
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
              Icon(Icons.copy, size: iconSize, color: Colors.black54),
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
    return OffiboxTooltip(
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
