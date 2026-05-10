import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/data/medipim_shared.dart';
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
import 'package:offibox/utils/normalize.dart' hide normalizePrincepsKey;
import 'package:offibox/data/ansm_rappels_loader.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/utils/ansm_rappel_match.dart';
import 'package:offibox/ui/results/plus_infos_badge.dart';
import 'package:offibox/ui/results/result_line_3_actions.dart';
import 'package:offibox/ui/spans/common_spans.dart';
import 'package:offibox/ui/widgets/offibox_tooltip.dart';
import 'package:offibox/ui/widgets/pharmaradio_flash_panel_below_bar.dart'
    show kPharmaradioFlashInfoUrl;
import 'package:offibox/constants/offibox_icons.dart';
import 'package:offibox/utils/phone_display_format.dart';
import 'package:offibox/utils/annuaire_email_kind.dart';

/// URL page rappels médicaments ANSM (fallback quand pas de rappel spécifique).
const String _kAnsmRappelsMedicamentsUrl = ansmInformationsMedicamentsUrl;

/// URLs des calendriers vaccinaux (badges pour les médicaments dont le libellé contient "vaccin").
const String kCalendrierVaccinal2025Url =
    'https://sante.gouv.fr/IMG/pdf/pdf_calendrier_vaccinal-12-2025.pdf';

/// Page « Carte postale » du calendrier simplifié (s’ouvre dans le navigateur ; le lien direct content/download pouvait échouer au clic).
const String kCalendrierSimplifieUrl =
    'https://www.santepubliquefrance.fr/determinants-de-sante/vaccination/documents/carte-postale/calendrier-simplifie-des-vaccinations-2025-carte-postale';

String normalizeAddress(String input) {
  return utf8.decode(latin1.encode(input), allowMalformed: true);
}

List<String> _extractFrenchPhoneCandidates(String raw) {
  final cleaned = raw.replaceAll('"', '').replaceAll("'", '').trim();
  if (cleaned.isEmpty) return const [];

  // Patterns like "04 92 12 34 56", "0492123456", "04.92.12.34.56", "04-92-12-34-56"
  final re = RegExp(r'\b0[1-9](?:[\s\.\-]*\d{2}){4}\b');
  final found = <String>[];
  for (final m in re.allMatches(cleaned)) {
    final s = m.group(0);
    if (s != null && s.trim().isNotEmpty) found.add(s.trim());
  }
  if (found.isNotEmpty) {
    final out = <String>[];
    final seen = <String>{};
    for (final f in found) {
      final key = f.replaceAll(RegExp(r'\D'), '');
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(f);
    }
    return out;
  }

  // Fallback: split on common separators.
  final parts = cleaned
      .split(RegExp(r'[\n;/,]| \| '))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return const [];
  final out = <String>[];
  final seen = <String>{};
  for (final p in parts) {
    final key = p.replaceAll(RegExp(r'\D'), '');
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(p);
  }
  return out;
}

Widget _annuaireUnifiedLine2(SearchResult item) {
  String normField(String? s) =>
      s?.replaceAll('"', '').replaceAll("'", '').trim() ?? '';

  // Adresse complète : address prioritaire ; fallback groupLabel si utile.
  final rawAddr = (item.address ?? '').trim();
  final addrPhysical = rawAddr.isNotEmpty
      ? rawAddr
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .where((s) => !s.toLowerCase().startsWith('coordonn'))
          .join(', ')
      : '';
  final rawGroup = (item.groupLabel ?? '').trim();
  final addressNorm = normalizeText(
    (addrPhysical.isNotEmpty ? addrPhysical : rawAddr).isNotEmpty
        ? (addrPhysical.isNotEmpty ? addrPhysical : rawAddr)
        : rawGroup,
  ).trim();

  final phones = _extractFrenchPhoneCandidates(item.phone ?? '');
  final phoneDigits = phones
      .map((s) => s.replaceAll(RegExp(r'\D'), ''))
      .where((s) => s.isNotEmpty)
      .toSet();
  final faxes = _extractFrenchPhoneCandidates(item.fax ?? '')
      .where((f) {
        final d = f.replaceAll(RegExp(r'\D'), '');
        return d.isNotEmpty && !phoneDigits.contains(d);
      })
      .toList(growable: false);

  final mails = <String>[];
  final seenMail = <String>{};
  void addMail(String raw) {
    final t = normField(raw);
    if (t.isEmpty || !t.contains('@')) return;
    final k = t.toLowerCase();
    if (seenMail.contains(k)) return;
    seenMail.add(k);
    mails.add(t);
  }

  addMail(normField(item.mssanteEmail));
  addMail(normField(item.email));
  final joined = item.annuaireAllEmailsJoined;
  if (joined != null && joined.trim().isNotEmpty) {
    for (final p in joined.split('|')) {
      addMail(annuaireEmailFromOriginEntry(p));
    }
  }

  if (addressNorm.isEmpty && phones.isEmpty && faxes.isEmpty && mails.isEmpty) {
    return const SizedBox.shrink();
  }

  const pillH = 30.8;
  final children = <Widget>[
    if (addressNorm.isNotEmpty)
      CodeBadgeWithCopy(
        label: '',
        showLabelInBadge: false,
        value: addressNorm,
        tooltip: "Copier l'adresse",
        leadingIcon: Icons.place_outlined,
        fontSize: 11,
        leadingIconSize: 14,
        height: pillH,
        shrinkWrap: true,
      ),
    for (final p in phones)
      CodeBadgeWithCopy(
        label: '',
        showLabelInBadge: false,
        value: formatPhoneDigitsInPairs(p),
        tooltip: 'Copier le téléphone',
        leadingIcon: Icons.phone_outlined,
        fontSize: 11,
        leadingIconSize: 14,
        height: pillH,
        shrinkWrap: true,
      ),
    for (final f in faxes)
      CodeBadgeWithCopy(
        label: '',
        showLabelInBadge: false,
        value: formatPhoneDigitsInPairs(f),
        tooltip: 'Copier le fax',
        leadingIcon: Icons.fax,
        fontSize: 11,
        leadingIconSize: 14,
        height: pillH,
        shrinkWrap: true,
      ),
    for (final em in mails)
      CodeBadgeWithCopy(
        label: '',
        showLabelInBadge: false,
        value: em,
        tooltip: annuaireEmailLooksLikeSecureMailbox(em)
            ? 'Copier la messagerie sécurisée'
            : 'Copier le courriel',
        leadingIcon:
            annuaireEmailLooksLikeSecureMailbox(em) ? Icons.verified_user : Icons.mail_outline,
        fontSize: 11,
        leadingIconSize: 14,
        height: pillH,
        shrinkWrap: true,
      ),
  ];

  return Padding(
    padding: const EdgeInsets.only(top: resultLineGap),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

/// Enlève tous les mots entre parenthèses (ex. "ZOLPIDEM (TARTRATE DE) 10 MG" → "ZOLPIDEM 10 MG").
String stripParenthesesFromGenericName(String s) {
  if (s.isEmpty) return s;
  return s
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Indique si le produit est le princeps (ex. STILNOX) ou un générique (ex. ZOLPIDEM ALMUS) pour un CIS présent dans generiques2026.
/// Utilisé pour le badge ligne 1 (Princeps vs Générique) et ligne 2.
bool isProductPrincepsForGenerique2026(
    SearchResult item, Generique2026Info? generique2026Info,) {
  if (generique2026Info == null) return false;
  final princepsLabel = generique2026Info.princepsDisplay.trim();
  final col1Label = col1BeforeParentheses(generique2026Info.genericNameColA);
  final dciFirstWord = col1Label.isNotEmpty
      ? dciFromGenericLabel(col1Label)
          .trim()
          .split(RegExp(r'\s+'))
          .first
          .toUpperCase()
      : '';
  final princepsFirstWord = princepsLabel.isNotEmpty
      ? princepsLabel.split(RegExp(r'\s+')).first.toUpperCase()
      : '';
  final productFirstWord =
      item.labelRaw.trim().split(RegExp(r'\s+')).first.toUpperCase();
  return princepsFirstWord.isNotEmpty &&
      productFirstWord == princepsFirstWord &&
      (dciFirstWord.isEmpty || productFirstWord != dciFirstWord);
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
    final part2 =
        t.substring(idx + sep.length).trim().split(RegExp(r'\s+')).first.trim();
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
  return path.endsWith('.xls') ||
      path.endsWith('.xlsx') ||
      path.endsWith('.ods');
}

/// True si l'URL pointe vers un document Word / Open Office texte (.doc, .docx, .odt).
bool _isWordUrl(String url) {
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.doc') ||
      path.endsWith('.docx') ||
      path.endsWith('.odt');
}

/// True si la fiche mots-clés affiche au moins une pill en ligne 2 (alignée sur la construction des [pills]).
/// Sert à placer le logo source en ligne 2 (à droite) plutôt qu’en ligne 1.
bool keywordItemHasLine2Pills(SearchResult item) {
  if (item.source != SourceType.keyword) return false;
  final urlLigne1 = item.url?.trim();
  var n = 0;
  if (urlLigne1 != null &&
      urlLigne1.isNotEmpty &&
      !_isYouTubeUrl(urlLigne1)) {
    if (_isPdfUrl(urlLigne1) ||
        _isWordUrl(urlLigne1) ||
        _isXlsUrl(urlLigne1)) {
      n++;
    }
  }
  if (item.badge1Name != null && item.badge1Url != null) {
    final skip =
        item.badge1Name == 'Lien' && item.badge1Url!.trim() == urlLigne1;
    if (!skip &&
        item.badge1Name!.trim().isNotEmpty &&
        item.badge1Url!.trim().isNotEmpty) {
      n++;
    }
  }
  if (item.badge2Name != null &&
      item.badge2Url != null &&
      item.badge2Name!.trim().isNotEmpty &&
      item.badge2Url!.trim().isNotEmpty) {
    n++;
  }
  if (item.badge3Name != null &&
      item.badge3Url != null &&
      item.badge3Name!.trim().isNotEmpty &&
      item.badge3Url!.trim().isNotEmpty) {
    n++;
  }
  if (item.badge4Name != null &&
      item.badge4Url != null &&
      item.badge4Name!.trim().isNotEmpty &&
      item.badge4Url!.trim().isNotEmpty) {
    n++;
  }
  if (item.badge5Name != null &&
      item.badge5Url != null &&
      item.badge5Name!.trim().isNotEmpty &&
      item.badge5Url!.trim().isNotEmpty) {
    n++;
  }
  if (item.badge6Name != null &&
      item.badge6Url != null &&
      item.badge6Name!.trim().isNotEmpty &&
      item.badge6Url!.trim().isNotEmpty) {
    n++;
  }
  if (n > 0) return true;
  // Fallback aligné sur keyword : pill « site internet » YouTube si aucune autre pill.
  if (urlLigne1 != null &&
      urlLigne1.isNotEmpty &&
      _isYouTubeUrl(urlLigne1)) {
    return true;
  }
  return false;
}

/// Logo PDF rouge (asset local) pour le badge "document" et fiches VOC.
Widget _pdfIconWidget() {
  return SvgPicture.asset(
    kPdfRedIconAsset,
    width: 16,
    height: 16,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) =>
        Icon(Icons.picture_as_pdf, size: 16, color: Colors.red.shade700),
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
    errorBuilder: (_, __, ___) =>
        const Icon(Icons.open_in_new, size: 20, color: OffiboxColors.primary),
  );
}


/// Icône téléchargement pour les badges type « télécharger Myris pour PC ».
Widget _downloadIconWidget() {
  return const Icon(Icons.download, size: 20, color: OffiboxColors.primary);
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
    if (up == 'MG' || up == 'G' || up == 'MCG' || up == 'µG' || up == 'UI') {
      break;
    }
    kept.add(p);
  }
  return kept.isEmpty ? parts.first : kept.join(' ');
}

/// Extrait le(s) DCI depuis la chaîne composition BDM (format "DCI : dosage" ou "DCI1 : d1 ; DCI2 : d2").
/// Retourne une chaîne pour le badge, ex. "travoprost" ou "paracetamol, cafeine".
String dciFromCompositionLine(String compositionLine) {
  final raw = compositionLine.trim();
  if (raw.isEmpty) return '';
  final segments = raw
      .split(RegExp(r'\s*;\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
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
  final void Function(
          BuildContext context, String url, String labName, String? iconUrl,)?
      onOpenEspacePro;

  /// Si fourni, au clic sur le badge "Catalogue" on affiche le panneau catalogue sous la barre au lieu d'ouvrir l'URL.
  final VoidCallback? onOpenCataloguePanel;

  /// Si fourni, en ligne 2 catalogue on affiche le badge "disponibilité produits" ; au clic ouvre le panneau titre + image sous la barre.
  final VoidCallback? onOpenDisponibiliteProduits;

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

  /// Liste des rappels médicaments ANSM (pour URL du badge rappel, sans limite de durée).
  final List<AnsmRappelItem>? medicamentRappels;

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

  /// CIP13 du registre ANSM « groupes hybrides » — le badge rose affiche « hybride » seulement si le CIP est listé.
  final Set<String> ansmHybridesCip13;

  /// Annuaire RPPS (résultat injecté) : une entrée par structure d’exercice (même RPPS). Null en liste de résultats.
  final List<SearchResult>? annuaireRppsStructureLines;

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
    this.onOpenDisponibiliteProduits,
    this.onOpenYouTubeVideo,
    this.videosByCip13,
    this.onOpenTherapeuticVideo,
    this.onOpenPharmaradioFlash,
    this.isInjected = false,
    this.recalledProductNames,
    this.ansmLastRappel,
    this.medicamentRappels,
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
    this.ansmHybridesCip13 = const {},
    this.annuaireRppsStructureLines,
  });

  static String _annuaireRppsRowLine(SearchResult r) {
    final hasStr = r.groupLabel != null && r.groupLabel!.trim().isNotEmpty;
    final hasAd = r.address != null && r.address!.trim().isNotEmpty;
    return [
      if (hasStr) normalizeText(r.groupLabel!),
      if (hasAd) normalizeText(r.address!),
    ].join(hasStr && hasAd ? ' — ' : '');
  }

  static String _annuaireRppsMapsQuery(SearchResult r) {
    final hasStructure = r.groupLabel?.trim().isNotEmpty ?? false;
    final hasPhysicalAddress = r.address?.trim().isNotEmpty ?? false;
    var mapsQuery = [
      if (hasStructure) normalizeText(r.groupLabel!),
      if (hasPhysicalAddress) normalizeText(r.address!),
    ].where((s) => s.trim().isNotEmpty).join(' — ');
    if (mapsQuery.isEmpty) {
      final addr = (r.address ?? '').trim();
      final group = (r.groupLabel ?? '').trim();
      final fromAddr = addr
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .where((s) => !s.toLowerCase().startsWith('coordonnées'))
          .join(', ')
          .trim();
      mapsQuery = fromAddr.isNotEmpty ? fromAddr : group;
    }
    return mapsQuery.trim();
  }

  /// Ligne « structure » seule (sans adresse) — affichage ligne 2 barre injectée RPPS.
  static String _annuaireRppsStructureNameLine(SearchResult r) {
    final g = (r.groupLabel ?? '').trim();
    return g.isEmpty ? '' : normalizeText(g);
  }

  /// Adresse d’exercice seule — sous le nom de structure en ligne 2.
  static String _annuaireRppsAddressLine(SearchResult r) {
    final a = (r.address ?? '').trim();
    return a.isEmpty ? '' : normalizeText(a);
  }

  String _cleanCode(String value) {
    return value.replaceAll('"', '').replaceAll("'", '');
  }

  String? _annuaireSpecialiteFromLabel(String labelRaw) {
    final t = labelRaw.trim();
    if (t.isEmpty) return null;
    final comma = t.indexOf(',');
    if (comma >= 0 && comma + 1 < t.length) {
      final s = t.substring(comma + 1).trim();
      if (s.isNotEmpty) return s;
    }
    final sep = t.indexOf(' - ');
    if (sep >= 0 && sep + 3 < t.length) {
      final s = t.substring(sep + 3).trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  bool _isAnsmHybridCip13(SearchResult r) {
    if (r.source != SourceType.bdm || r.isGeneric != true) return false;
    final c = r.cip13?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (c.length != 13) return false;
    return ansmHybridesCip13.contains(c);
  }

  bool get _hasAnyCode {
    // 🏥 Organismes : adresse ou badge taux de remboursement ; injecté : + tél/fax (ligne 2)
    if (item.source == SourceType.amc || item.source == SourceType.amo) {
      final hasAddress =
          item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
      final hasTauxRemb = item.badge2Name != null &&
          item.badge2Url != null &&
          item.badge2Name!.trim().isNotEmpty &&
          item.badge2Url!.trim().isNotEmpty;
      if (isInjected) {
        final phoneRaw =
            (item.phone ?? '').replaceAll('"', '').replaceAll("'", '').trim();
        final faxRaw =
            (item.fax ?? '').replaceAll('"', '').replaceAll("'", '').trim();
        final hasPhone = phoneRaw.isNotEmpty;
        final hasFax = faxRaw.isNotEmpty && faxRaw != phoneRaw;
        return hasAddress || hasPhone || hasFax;
      }
      return hasAddress || hasTauxRemb;
    }

    // 🟪 Annuaires — ligne 2 = adresse (RPPS/FHIR : sans tél/fax). Tél/fax RPPS/FHIR + CSV centres en ligne 3.
    if (item.source == SourceType.pharmacovigilance ||
        item.source == SourceType.centresAntiPoison ||
        item.source == SourceType.chu ||
        item.source == SourceType.ceipAddictovigilance ||
        item.source == SourceType.ars ||
        item.source == SourceType.annuaireSanteRpps ||
        item.source == SourceType.annuairePharmacieFhir) {
      final isRppsStyle = item.source == SourceType.annuaireSanteRpps ||
          item.source == SourceType.annuairePharmacieFhir;
      if (isInjected && isRppsStyle) {
        if (item.source == SourceType.annuaireSanteRpps) {
          final rows = (annuaireRppsStructureLines != null &&
                  annuaireRppsStructureLines!.isNotEmpty)
              ? annuaireRppsStructureLines!
              : <SearchResult>[item];
          bool rowHasLoc(SearchResult r) {
            final g = (r.groupLabel ?? '').trim();
            final a = (r.address ?? '').trim();
            return g.isNotEmpty || a.isNotEmpty;
          }
          final rpps = (item.cip13 ?? '').replaceAll(RegExp(r'\D'), '');
          return rows.any(rowHasLoc) || rpps.length == 11;
        }
        final specialite = _annuaireSpecialiteFromLabel(item.label);
        final rpps = (item.cip13 ?? '').replaceAll(RegExp(r'\D'), '');
        return (specialite != null && specialite.isNotEmpty) || rpps.length == 11;
      }
      if (item.source == SourceType.annuaireSanteRpps ||
          item.source == SourceType.annuairePharmacieFhir) {
        final hasStructure =
            item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
        final hasPhysicalAddress =
            item.address != null && item.address!.trim().isNotEmpty;
        return hasStructure || hasPhysicalAddress;
      }
      return item.groupLabel != null && item.groupLabel!.isNotEmpty;
    }

    // 🩹 DM : en liste, EAN en ligne 1 uniquement ; en barre injectée, codes + fiche en ligne 2
    if (item.source == SourceType.dm) {
      if (!isInjected) return false;
      return item.cip13 != null && item.cip13!.trim().isNotEmpty;
    }
    // 🐾 Véto : en barre injectée, ligne 2 = RCP VÉTO + GTIN/CIS si présents
    if (item.source == SourceType.veto) {
      if (isInjected) {
        final rcp = (item.rcpVetoUrl ?? item.url)?.trim();
        final hasRcp = rcp != null && rcp.isNotEmpty;
        final hasGtin = item.cip13 != null && item.cip13!.trim().isNotEmpty;
        final hasCis = item.cis != null && item.cis!.trim().isNotEmpty;
        return hasRcp || hasGtin || hasCis;
      }
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

    // 🏷️ Mots-clés : ligne 2 = HoverPill(s) col F/G, H/I, J/K, L/M, N/O, P/Q
    if (item.source == SourceType.keyword) {
      return (item.badge1Url ??
                  item.badge2Url ??
                  item.badge3Url ??
                  item.badge4Url ??
                  item.badge5Url ??
                  item.badge6Url ??
                  item.url)
              ?.trim()
              .isNotEmpty ??
          false;
    }

    // 📋 Codes actes : pas de ligne 2 (tout en ligne 1 : Code — Libellé — Tarif)
    if (item.source == SourceType.codesActes ||
        item.source == SourceType.analysesBiologiques) {
      return false;
    }

    // 🌿 Compléments alimentaires Vidal : ligne 2 = badge Composition + site web Vidal
    if (item.source == SourceType.vidalComplements) {
      return item.url?.trim().isNotEmpty ?? false;
    }

    // 🩺 RecoMédicales : ligne 2 = Source : recomedicales.fr (italique)
    if (item.source == SourceType.recomedicales) {
      return item.url?.trim().isNotEmpty ?? false;
    }

    // 🌐 Sites web : ligne 2 = HoverPill(s) col F/G, H/I, J/K, L/M, N/O, P/Q
    if (item.source == SourceType.siteWeb) {
      return (item.badge1Name != null &&
              item.badge1Url != null &&
              item.badge1Name!.trim().isNotEmpty &&
              item.badge1Url!.trim().isNotEmpty) ||
          (item.badge2Name != null &&
              item.badge2Url != null &&
              item.badge2Name!.trim().isNotEmpty &&
              item.badge2Url!.trim().isNotEmpty) ||
          (item.badge3Name != null &&
              item.badge3Url != null &&
              item.badge3Name!.trim().isNotEmpty &&
              item.badge3Url!.trim().isNotEmpty) ||
          (item.badge4Name != null &&
              item.badge4Url != null &&
              item.badge4Name!.trim().isNotEmpty &&
              item.badge4Url!.trim().isNotEmpty) ||
          (item.badge5Name != null &&
              item.badge5Url != null &&
              item.badge5Name!.trim().isNotEmpty &&
              item.badge5Url!.trim().isNotEmpty) ||
          (item.badge6Name != null &&
              item.badge6Url != null &&
              item.badge6Name!.trim().isNotEmpty &&
              item.badge6Url!.trim().isNotEmpty);
    }

    // 🏭 Catalogues laboratoires : ligne 2 = HoverPill(s) Espace pro, Catalogue, etc. (F, G, H, I/J, K/L)
    if (item.source == SourceType.catalogue) {
      return (item.badge1Url ??
                  item.badge2Url ??
                  item.badge3Url ??
                  item.badge4Url ??
                  item.badge5Url ??
                  item.badge6Url)
              ?.trim()
              .isNotEmpty ??
          false;
    }

    // 📦 CERP (CERP.csv Madouest + CO&PHARM 2026) : ligne 2 = badge(s) avec URL au clic
    if (item.source == SourceType.cerp) {
      return (item.badge1Url ?? item.badge2Url ?? item.url)
              ?.trim()
              .isNotEmpty ??
          false;
    }

    if (item.source == SourceType.weleda) {
      return isInjected;
    }

    return item.cip13 != null || item.cis != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyCode) return const SizedBox.shrink();

    // ─────────────────────────────
    // 🩹 DM — vue injectée : éviter les doublons avec le panneau Medipim (photo + infos).
    // On n'affiche plus EAN/ACL ici.
    // ─────────────────────────────
    if (item.source == SourceType.dm && isInjected) {
      return const SizedBox.shrink();
    }

    // ─────────────────────────────
    // 🌿 Weleda — composition + CIP13/CIS (CSV weleda_w_cip13.csv / API si besoin).
    // ─────────────────────────────
    if (item.source == SourceType.weleda && isInjected) {
      final comp = (item.groupLabel ?? '').trim();
      final cipDigits = item.cip13?.replaceAll(RegExp(r'\D'), '') ?? '';
      final hasCip =
          cipDigits.length == 13 && cipDigits.startsWith('34009');
      final cis = (item.cis ?? '').trim();

      final children = <Widget>[];
      if (comp.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              comp,
              style: TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 11,
                height: 1.25,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        );
      }
      if (hasCip) {
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CodeBadge(
                label: 'CIP',
                value: _cleanCode(item.cip13!),
              ),
              if (cis.isNotEmpty)
                _CodeBadge(
                  label: 'CIS',
                  value: cis,
                ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    }

    // ─────────────────────────────
    // 🐾 Véto — vue injectée : ligne 2 = RCP VÉTO + GTIN / CIS
    // (source véto native OU produit Medipim vétérinaire)
    // ─────────────────────────────
    final isMedipimVeto =
        item.source == SourceType.bdm &&
            medipimCategoryPathIsVeterinary(item.medipimCategoryPath);
    if ((item.source == SourceType.veto || isMedipimVeto) && isInjected) {
      final rcpUrl = (item.rcpVetoUrl ?? item.url)?.trim();
      final code =
          item.cip13?.replaceAll('"', '').replaceAll("'", '').trim() ?? '';
      final hasGtin = code.isNotEmpty;
      final cis = item.cis?.trim() ?? '';
      final hasCis = cis.isNotEmpty;
      if ((rcpUrl == null || rcpUrl.isEmpty) && !hasGtin && !hasCis) {
        return const SizedBox.shrink();
      }
      final children = <Widget>[];
      if (rcpUrl != null && rcpUrl.isNotEmpty) {
        children.add(
          HoverPillButton(
            label: 'RCP',
            icon: Icons.description_outlined,
            iconWidget: _externalLinkIconWidget(),
            tooltip: 'Résumé des caractéristiques du produit',
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(rcpUrl);
              } else {
                openUrl(rcpUrl);
              }
            },
          ),
        );
      }
      if (hasGtin) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(
          CodeBadgeWithCopy(
            label: 'GTIN',
            value: code,
            tooltip: 'Copier le GTIN',
            fontSize: 10,
          ),
        );
      }
      if (hasCis) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(
          CodeBadgeWithCopy(
            label: 'CIS',
            value: cis,
            tooltip: 'Copier le CIS',
            fontSize: 10,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
    }

    // ─────────────────────────────
    // 🏥 AMC-AMO — liste : ADRESSE + taux (ligne 2) ; injecté : ADRESSE puis Tél/Fax compacts (ligne 2–3 visuelles)
    // ─────────────────────────────
    if (item.source == SourceType.amc || item.source == SourceType.amo) {
      final hasAddress =
          item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
      // En vue injectée : badge "taux de remboursement" en ligne 3 (result_action_registry).
      final hasTauxRemb = !isInjected &&
          item.badge2Name != null &&
          item.badge2Url != null &&
          item.badge2Name!.trim().isNotEmpty &&
          item.badge2Url!.trim().isNotEmpty;

      final phoneRaw =
          (item.phone ?? '').replaceAll('"', '').replaceAll("'", '').trim();
      final faxRaw =
          (item.fax ?? '').replaceAll('"', '').replaceAll("'", '').trim();
      final showPhone = phoneRaw.isNotEmpty;
      final showFax = faxRaw.isNotEmpty && faxRaw != phoneRaw;

      if (isInjected) {
        if (!hasAddress && !showPhone && !showFax) {
          return const SizedBox.shrink();
        }
        const pillH = 30.8;
        final lineChildren = <Widget>[];
        if (hasAddress) {
          final address = normalizeText(item.groupLabel!);
          lineChildren.add(
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
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
        if (showPhone || showFax) {
          if (lineChildren.isNotEmpty) {
            lineChildren.add(const SizedBox(height: 6));
          }
          lineChildren.add(
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showPhone)
                  CodeBadgeWithCopy(
                    label: 'Tél',
                    value: formatPhoneDigitsInPairs(phoneRaw),
                    tooltip: 'Copier le numéro',
                    leadingIcon: Icons.phone,
                    fontSize: 11,
                    leadingIconSize: 14,
                    height: pillH,
                    shrinkWrap: true,
                  ),
                if (showFax)
                  CodeBadgeWithCopy(
                    label: 'Fax',
                    value: formatPhoneDigitsInPairs(faxRaw),
                    tooltip: 'Copier le fax',
                    leadingIcon: Icons.fax,
                    fontSize: 11,
                    leadingIconSize: 14,
                    height: pillH,
                    shrinkWrap: true,
                  ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: resultLineGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: lineChildren,
          ),
        );
      }

      if (!hasAddress && !hasTauxRemb) return const SizedBox.shrink();

      final children = <Widget>[];
      if (hasAddress) {
        final address = normalizeText(item.groupLabel!);
        children.addAll([
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
        ]);
      }
      if (hasTauxRemb) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 12));
        final url = item.badge2Url!.trim();
        children.add(HoverPillButton(
          label: item.badge2Name!.trim(),
          icon: Icons.open_in_new,
          iconWidget: _externalLinkIconWidget(),
          tooltip: 'Ouvrir le taux de remboursement',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(url);
            } else {
              openUrl(url);
            }
          },
        ),);
      }
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
    // 🟪 Annuaires — ADRESSE ligne 2 (RPPS/FHIR sans tél/fax ici) ; tél/fax ligne 3 ; CEIP-A/ARS + badge site
    // ─────────────────────────────
    if (item.source == SourceType.pharmacovigilance ||
        item.source == SourceType.centresAntiPoison ||
        item.source == SourceType.chu ||
        item.source == SourceType.ceipAddictovigilance ||
        item.source == SourceType.ars ||
        item.source == SourceType.annuaireSanteRpps ||
        item.source == SourceType.annuairePharmacieFhir ||
        item.source == SourceType.pmi ||
        item.source == SourceType.centresSanteSexuelle ||
        item.source == SourceType.centresVaccinations) {
      // Panneau de résultats : seules lignes 1 & 2 sont visibles → tout le contact doit être ici.
      if (item.source == SourceType.pmi ||
          item.source == SourceType.centresSanteSexuelle ||
          item.source == SourceType.centresVaccinations ||
          !isInjected) {
        return _annuaireUnifiedLine2(item);
      }
      final isAnnuaireRpps = item.source == SourceType.annuaireSanteRpps;
      final isAnnuairePharmacieFhir =
          item.source == SourceType.annuairePharmacieFhir;
      final isRppsStyle = isAnnuaireRpps || isAnnuairePharmacieFhir;
      final hasStructure =
          item.groupLabel != null && item.groupLabel!.trim().isNotEmpty;
      final hasPhysicalAddress =
          item.address != null && item.address!.trim().isNotEmpty;

      bool rowHasLocation(SearchResult r) {
        final g = (r.groupLabel ?? '').trim();
        final a = (r.address ?? '').trim();
        return g.isNotEmpty || a.isNotEmpty;
      }

      final rppsStructureRows = isAnnuaireRpps
          ? ((annuaireRppsStructureLines != null &&
                  annuaireRppsStructureLines!.isNotEmpty)
              ? annuaireRppsStructureLines!
              : <SearchResult>[item])
          : const <SearchResult>[];

      // Annuaire RPPS / officines FHIR : adresse physique (item.address) prioritaire ; sinon structure (groupLabel). Autres annuaires : groupLabel = adresse.
      final address = isRppsStyle
          ? (hasPhysicalAddress
              ? normalizeText(item.address!)
              : (hasStructure ? normalizeText(item.groupLabel!) : ''))
          : (hasStructure ? normalizeText(item.groupLabel!) : '');
      final hasAddress = isAnnuaireRpps
          ? rppsStructureRows.any(rowHasLocation)
          : (hasStructure || hasPhysicalAddress);
      final isLiberal = item.commentaire?.trim() == 'mode=liberal';
      final phoneRaw =
          (item.phone ?? '').replaceAll('"', '').replaceAll("'", '').trim();
      final faxRaw =
          (item.fax ?? '').replaceAll('"', '').replaceAll("'", '').trim();
      // Annuaire RPPS / officines FHIR : tél/fax en ligne 3. CRPV/CEIP-A/ARS : fax si libéral (ligne 2 si adresse).
      final showFax = isRppsStyle
          ? (faxRaw.isNotEmpty && faxRaw != phoneRaw)
          : ((isLiberal ||
                  item.source == SourceType.pharmacovigilance ||
                  item.source == SourceType.ceipAddictovigilance ||
                  item.source == SourceType.ars) &&
              faxRaw.isNotEmpty &&
              faxRaw != phoneRaw);
      final showPhone = phoneRaw.isNotEmpty;

      if (!hasAddress && !showPhone && !showFax) {
        return const SizedBox.shrink();
      }

      const copyStructureTooltip = 'Copier structure et adresse';
      const copyStructureSnack = 'Structure et adresse copiés';

      final locRppsRows = isAnnuaireRpps
          ? rppsStructureRows.where(rowHasLocation).toList()
          : const <SearchResult>[];
      final multiRppsStructures = locRppsRows.length > 1;

      final children = <Widget>[
        if (isAnnuaireRpps && locRppsRows.isNotEmpty) ...[
          if (multiRppsStructures)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: Text(
                'Structures d’exercice',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                  fontFamily: 'Spinnaker',
                ),
              ),
            ),
          for (var i = 0; i < locRppsRows.length; i++) ...[
            Builder(
              builder: (context) {
                final r = locRppsRows[i];
                final rowMapsPill = multiRppsStructures
                    ? annuaireLocaliserGoogleMapsPill(
                        addressQuery: _annuaireRppsMapsQuery(r),
                        onOpenUrl: onOpenUrl,
                      )
                    : null;
                final structName = _annuaireRppsStructureNameLine(r);
                final addrLine = _annuaireRppsAddressLine(r);
                final bodyStyle = const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontFamily: 'Spinnaker',
                );
                final addrStyle = TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87.withValues(alpha: 0.85),
                  fontFamily: 'Spinnaker',
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!multiRppsStructures)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'structure : ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontFamily: 'Spinnaker',
                          ),
                        ),
                      ),
                    if (multiRppsStructures)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontFamily: 'Spinnaker',
                          ),
                        ),
                      ),
                    Expanded(
                      child: OffiboxTooltip(
                        message: copyStructureTooltip,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final toCopy = _annuaireRppsRowLine(r);
                            Clipboard.setData(ClipboardData(text: toCopy));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(copyStructureSnack),
                                duration: Duration(milliseconds: 900),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (structName.isNotEmpty)
                                  Text(structName, style: bodyStyle),
                                if (addrLine.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: structName.isNotEmpty ? 3 : 0,
                                    ),
                                    child: Text(addrLine, style: addrStyle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (rowMapsPill != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: rowMapsPill,
                      ),
                  ],
                );
              },
            ),
            if (multiRppsStructures && i < locRppsRows.length - 1)
              const SizedBox(height: 6),
          ],
          // RPPS : affiché une seule fois en haut à droite de la ligne 1
          // (via ResultLine1 → CodeBadgeWithCopy « RPPS »). Le badge qui
          // s'affichait ici dupliquait le RPPS sous la structure injectée.
        ],
        if (isAnnuairePharmacieFhir && hasPhysicalAddress) ...[
          Text(
            'structure : ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontFamily: 'Spinnaker',
            ),
          ),
          OffiboxTooltip(
            message: 'Copier l\'adresse',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                final raw = item.address!.trim();
                final physical = raw
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .where((s) => !s.toLowerCase().startsWith('coordonn'))
                    .join(', ');
                final toCopy = normalizeText(physical.isNotEmpty ? physical : raw);
                Clipboard.setData(ClipboardData(text: toCopy));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse copiée'),
                    duration: Duration(milliseconds: 900),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  normalizeText(
                    item.address!
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .where((s) => !s.toLowerCase().startsWith('coordonn'))
                        .join(', '),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontFamily: 'Spinnaker',
                  ),
                ),
              ),
            ),
          ),
        ],
        if (hasAddress && address.isNotEmpty && !isRppsStyle) ...[
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
        // RPPS / officines FHIR : tél / fax en ligne 3 — [ResultLine3Actions].
        // Tél / Fax (CRPV, anti-poison, CHU, CEIP-A, ARS) : ligne 3 — [ResultLine3Actions].
        // Mail sécurisé + Localiser : ligne 3 ([ResultLine3Actions]).
        // CEIP-A : badge "site internet" → addictovigilance.fr
        if (item.source == SourceType.ceipAddictovigilance &&
            (item.url?.trim().isNotEmpty ?? false)) ...[
          if (hasAddress || showPhone || showFax) const SizedBox(width: 10),
          HoverPillButton(
            label: 'site internet',
            icon: Icons.language,
            iconWidget: _externalLinkIconWidget(),
            tooltip: 'https://addictovigilance.fr/',
            onTap: () => openUrl(item.url!.trim()),
          ),
        ],
        // ARS : badge "site internet" → URL du CSV
        if (item.source == SourceType.ars &&
            (item.url?.trim().isNotEmpty ?? false)) ...[
          if (hasAddress || showPhone || showFax) const SizedBox(width: 10),
          HoverPillButton(
            label: 'site internet',
            icon: Icons.language,
            iconWidget: _externalLinkIconWidget(),
            tooltip: item.url!.trim(),
            onTap: () => openUrl(item.url!.trim()),
          ),
        ],
      ];

      if (children.isEmpty) return const SizedBox.shrink();

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
        icon: _isPdfUrl(item.url!) || _isXlsUrl(item.url!)
            ? null
            : iconForUrl(item.url!),
        iconWidget: _isPdfUrl(item.url!)
            ? _pdfIconWidget()
            : _isXlsUrl(item.url!)
                ? _excelIconWidget()
                : _externalLinkIconWidget(),
        tooltip: '↗ accès nomenclature LPP',
        onTap: () {
          if (onOpenUrl != null) {
            onOpenUrl!(item.url!.trim());
          } else {
            openUrl(item.url!.trim());
          }
        },
      );
      final sourceWidget = isInjected
          ? ResultLine3Actions.buildSourceRow(item, isInjected, onOpenUrl)
          : null;
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
      final isNewFromColD = (item.groupLabel ?? '').trim().toLowerCase() == 'oui';
      final keywordSourceLabel = item.laboratory.trim();
      final showKeywordSourceLabel = isInjected && keywordSourceLabel.isNotEmpty;
      Widget? keywordLibelleRow;
      if (!isInjected) {
        final com = item.commentaire?.trim() ?? '';
        final libelle = (com.toUpperCase().startsWith('HAS|')
                ? item.label
                : (item.commentaire ?? item.label))
            .trim();
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
                  if (isNewFromColD) ...[
                    nouveauSquareSpan(),
                    const TextSpan(text: ' '),
                  ],
                  keywordPlusAndOutilsMetierSpan(),
                  TextSpan(text: ' ${libelle.toUpperCase()}'),
                  if (item.keywordAppearanceDate != null &&
                      item.keywordAppearanceDate!.trim().isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Tooltip(
                        message: item.keywordAppearanceDate!.trim(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2,),
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
        final useNativeIconColors =
            showYouTubeIcon || isPdf || isWord || isXls;
        pills.add(
          HoverPillButton(
            label: name,
            maxLabelWidth: maxLabelWidth,
            icon: showYouTubeIcon || isPdf || isWord || isXls
                ? null
                : iconForUrl(url),
            iconWidget: showYouTubeIcon
                ? SvgPicture.asset(
                    'assets/icons/youtube.svg',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.play_circle, size: 24, color: Colors.red),
                  )
                : isPdf
                    ? _pdfIconWidget()
                    : isWord
                        ? _pdfIconWidget()
                        : isXls
                            ? _excelIconWidget()
                            : _externalLinkIconWidget(),
            applyForegroundTintToIcon: !useNativeIconColors,
            tooltip: '↗ $urlTrim',
            onTap: () {
              if (useYouTubePanel) {
                onOpenYouTubeVideo!(urlTrim);
              } else if (onOpenUrl != null) {
                onOpenUrl!(urlTrim);
              } else {
                openUrl(urlTrim);
              }
            },
          ),
        );
      }

      // Pill pour url principale (col E) : PDF → "document" ; Word/ODT → "document" ; XLS/ODS → "tableur"
      if (urlLigne1 != null &&
          urlLigne1.isNotEmpty &&
          !_isYouTubeUrl(urlLigne1)) {
        if (_isPdfUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'document',
              iconWidget: _pdfIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le document PDF',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        } else if (_isWordUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'document',
              iconWidget: _pdfIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le document (Word / Open Office)',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        } else if (_isXlsUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'tableur',
              iconWidget: _excelIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le fichier Excel / tableur',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        }
        // Sinon (URL site web) : pas de pill "site internet", l’icône external link en ligne 1 suffit
      }
      // Badge 1 (col E/F) — sauf si c'est le fallback "Lien" pour urlLigne1
      if (item.badge1Name != null && item.badge1Url != null) {
        final skip =
            item.badge1Name == 'Lien' && item.badge1Url!.trim() == urlLigne1;
        if (!skip) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge1Name!, item.badge1Url!,
              isYouTube: _isYouTubeUrl(item.badge1Url!),);
        }
      }
      if (item.badge2Name != null && item.badge2Url != null) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge2Name!, item.badge2Url!,
            isYouTube: _isYouTubeUrl(item.badge2Url!),);
      }
      if (item.badge3Name != null && item.badge3Url != null) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge3Name!, item.badge3Url!,
            isYouTube: _isYouTubeUrl(item.badge3Url!),);
      }
      if (item.badge4Name != null && item.badge4Url != null) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge4Name!, item.badge4Url!,
            isYouTube: _isYouTubeUrl(item.badge4Url!),);
      }
      if (item.badge5Name != null && item.badge5Url != null) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge5Name!, item.badge5Url!,
            isYouTube: _isYouTubeUrl(item.badge5Url!),);
      }
      if (item.badge6Name != null && item.badge6Url != null) {
        if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
        addPill(item.badge6Name!, item.badge6Url!,
            isYouTube: _isYouTubeUrl(item.badge6Url!),);
      }
      // Fallback : si aucune pill et qu'on a url ligne 1 (YouTube ou PDF/Word/tableur uniquement)
      if (pills.isEmpty && urlLigne1 != null && urlLigne1.isNotEmpty) {
        if (_isYouTubeUrl(urlLigne1)) {
          addPill('site internet', urlLigne1, isYouTube: true);
        } else if (_isPdfUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'document',
              iconWidget: _pdfIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le document PDF',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        } else if (_isWordUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'document',
              iconWidget: _pdfIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le document (Word / Open Office)',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        } else if (_isXlsUrl(urlLigne1)) {
          pills.add(
            HoverPillButton(
              label: 'tableur',
              iconWidget: _excelIconWidget(),
              applyForegroundTintToIcon: false,
              tooltip: 'Ouvrir le fichier Excel / tableur',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(urlLigne1.trim());
                } else {
                  openUrl(urlLigne1.trim());
                }
              },
            ),
          );
        }
        // URL site web : pas de pill "site internet", l’icône external link en ligne 1 suffit
      }
      final keywordIconAsset = item.iconUrl?.trim() ?? '';
      final hasKeywordIcon = keywordIconAsset.isNotEmpty &&
          (keywordIconAsset.toLowerCase().contains('assets/') ||
              keywordIconAsset.contains('.png') ||
              keywordIconAsset.contains('.svg') ||
              keywordIconAsset.contains('.webp') ||
              keywordIconAsset.contains('.jpg'));
      final showLogoOnLine2 = hasKeywordIcon &&
          (!isInjected || keywordItemHasLine2Pills(item));

      if (keywordLibelleRow != null ||
          pills.isNotEmpty ||
          (hasKeywordIcon && !isInjected) ||
          showKeywordSourceLabel) {
        final pillsWrap = pills.isNotEmpty
            ? Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: pills,
              )
            : const SizedBox.shrink();

        final Widget secondLine;
        if (showLogoOnLine2) {
          secondLine = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: pillsWrap),
              keywordSourceLogoBox(iconAssetPath: keywordIconAsset),
            ],
          );
        } else if (pills.isNotEmpty) {
          secondLine = pillsWrap;
        } else {
          secondLine = const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: resultLineGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (keywordLibelleRow != null) keywordLibelleRow,
              if (pills.isNotEmpty || showLogoOnLine2) secondLine,
              if (showKeywordSourceLabel)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'source : $keywordSourceLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Spinnaker',
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }

    // ─────────────────────────────
    // 🩺 RecoMédicales — ligne 2 : Source : recomedicales.fr (italique)
    // ─────────────────────────────
    if (item.source == SourceType.recomedicales) {
      final url = item.url?.trim();
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Spinnaker',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            children: [
              TextSpan(
                text: 'Source : ',
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.black54,),
              ),
              TextSpan(
                text: 'recomedicales.fr',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─────────────────────────────
    // 🌿 Compléments alimentaires Vidal — ligne 2 : badge Composition (source Vidal italic) + site web Vidal
    // ─────────────────────────────
    if (item.source == SourceType.vidalComplements) {
      final url = item.url?.trim();
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      final nom = item.label.trim();
      return Padding(
        padding: const EdgeInsets.only(top: resultLineGap),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black26),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Spinnaker',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(text: 'Composition : '),
                    TextSpan(text: nom.isNotEmpty ? nom : '—'),
                    const TextSpan(text: ' '),
                    const TextSpan(
                      text: 'Vidal',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            HoverPillButton(
              label: 'site web Vidal',
              icon: Icons.open_in_new,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Ouvrir la fiche Vidal',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(url);
                } else {
                  openUrl(url);
                }
              },
            ),
          ],
        ),
      );
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
        pills.add(
          HoverPillButton(
            label: 'Flash info du jour',
            icon: Icons.newspaper,
            tooltip: 'Afficher le flash info Pharmaradio sous la barre',
            onTap: onOpenPharmaradioFlash!,
          ),
        );
        pills.add(
          HoverPillButton(
            label: 'Player Pharmaradio',
            icon: Icons.play_circle_outline,
            iconWidget: _externalLinkIconWidget(),
            tooltip: 'Écouter Pharmaradio',
            onTap: () => openUrlExternal(kPharmaradioFlashInfoUrl),
          ),
        );
      }
      void addPill(String name, String url, {bool isYouTube = false}) {
        if (name.isEmpty || url.isEmpty) return;
        if (isPharmaradio && name.toLowerCase().contains('flash info du jour')) {
          return;
        }
        final urlTrim = url.trim();
        final useYouTubePanel = isYouTube && onOpenYouTubeVideo != null;
        // Toujours afficher l'icône YouTube quand l'URL est une vidéo,
        // même dans la liste de résultats (avant injection dans la barre).
        final showYouTubeIcon = isYouTube;
        final isPdf = _isPdfUrl(url);
        final isWord = _isWordUrl(url);
        final isXls = _isXlsUrl(url);
        final maxLabelWidth = (isXls || isPdf || isWord) ? 500.0 : null;
        final useNativeIconColors =
            showYouTubeIcon || isPdf || isWord || isXls;
        pills.add(
          HoverPillButton(
            label: name,
            maxLabelWidth: maxLabelWidth,
            icon: showYouTubeIcon || isPdf || isWord || isXls
                ? null
                : iconForUrl(url),
            iconWidget: showYouTubeIcon
                ? SvgPicture.asset(
                    'assets/icons/youtube.svg',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.play_circle, size: 24, color: Colors.red),
                  )
                : isPdf
                    ? _pdfIconWidget()
                    : isWord
                        ? _pdfIconWidget()
                        : isXls
                            ? _excelIconWidget()
                            : _externalLinkIconWidget(),
            applyForegroundTintToIcon: !useNativeIconColors,
            tooltip: '↗ $urlTrim',
            onTap: () {
              if (useYouTubePanel) {
                onOpenYouTubeVideo!(urlTrim);
              } else if (onOpenUrl != null) {
                onOpenUrl!(urlTrim);
              } else {
                openUrl(urlTrim);
              }
            },
          ),
        );
      }

      // Ne pas ajouter de pill "site internet" quand l'icône external link est déjà en ligne 1 (item.url)
      final hasMainUrl = item.url != null && item.url!.trim().isNotEmpty;
      bool skipSiteInternetPill(String name) =>
          hasMainUrl && name.toLowerCase().trim() == 'site internet';
      if (item.badge1Name != null &&
          item.badge1Url != null &&
          item.badge1Name!.trim().isNotEmpty &&
          item.badge1Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge1Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge1Name!.trim(), item.badge1Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge1Url!),);
        }
      }
      if (item.badge2Name != null &&
          item.badge2Url != null &&
          item.badge2Name!.trim().isNotEmpty &&
          item.badge2Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge2Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge2Name!.trim(), item.badge2Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge2Url!),);
        }
      }
      if (item.badge3Name != null &&
          item.badge3Url != null &&
          item.badge3Name!.trim().isNotEmpty &&
          item.badge3Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge3Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge3Name!.trim(), item.badge3Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge3Url!),);
        }
      }
      if (item.badge4Name != null &&
          item.badge4Url != null &&
          item.badge4Name!.trim().isNotEmpty &&
          item.badge4Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge4Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge4Name!.trim(), item.badge4Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge4Url!),);
        }
      }
      if (item.badge5Name != null &&
          item.badge5Url != null &&
          item.badge5Name!.trim().isNotEmpty &&
          item.badge5Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge5Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge5Name!.trim(), item.badge5Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge5Url!),);
        }
      }
      if (item.badge6Name != null &&
          item.badge6Url != null &&
          item.badge6Name!.trim().isNotEmpty &&
          item.badge6Url!.trim().isNotEmpty) {
        if (!skipSiteInternetPill(item.badge6Name!.trim())) {
          if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
          addPill(item.badge6Name!.trim(), item.badge6Url!.trim(),
              isYouTube: _isYouTubeUrl(item.badge6Url!),);
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
      // Tooltip : picto lien externe (↗) + URL + mention "lien externe" et ouverture sous la barre.
      String cataloguePillTooltip(String url, {String? label}) {
        const String externalPicto =
            '↗ '; // picto lien externe (au repos + dans le tooltip)
        final u = url.trim();
        if (onOpenUrl != null) {
          final base = u.isEmpty
              ? 'Ouvrir dans la fenêtre sous la barre'
              : '$u\n\nLien externe — Ouvrir dans la fenêtre sous la barre';
          return '$externalPicto$base';
        }
        return u.isEmpty
            ? '$externalPicto${label ?? 'Ouvrir le lien'}'
            : '$externalPicto$u';
      }

      void addCataloguePill(String name, String url) {
        if (name.isEmpty || url.isEmpty) return;
        final isPdf = _isPdfUrl(url);
        final isWord = _isWordUrl(url);
        final isXls = _isXlsUrl(url);
        final maxLabelWidth = (isXls || isPdf || isWord) ? 500.0 : null;
        final isCatalogueBadge = name == 'Catalogue';
        // Toujours afficher l’icône lien externe pour les URL (au repos) ; tooltip avec URL + "lien externe — ouvrir sous la barre".
        final isDownload = name.toLowerCase().contains('télécharg');
        final linkIcon = isDownload
            ? _downloadIconWidget()
            : (isPdf
                ? _pdfIconWidget()
                : isWord
                    ? _pdfIconWidget()
                    : isXls
                        ? _excelIconWidget()
                        : _externalLinkIconWidget());
        final nativeColorIcon = isPdf || isWord || isXls;
        if (isCatalogueBadge && onOpenCataloguePanel != null) {
          cataloguePills.add(
            HoverPillButton(
              label: name,
              maxLabelWidth: maxLabelWidth,
              icon: isPdf || isWord || isXls ? null : Icons.open_in_new,
              iconWidget: linkIcon,
              applyForegroundTintToIcon: !nativeColorIcon,
              tooltip: cataloguePillTooltip(url, label: name),
              onTap: onOpenCataloguePanel!,
            ),
          );
          return;
        }
        cataloguePills.add(
          HoverPillButton(
            label: name,
            maxLabelWidth: maxLabelWidth,
            icon: isPdf || isWord || isXls ? null : Icons.open_in_new,
            iconWidget: linkIcon,
            applyForegroundTintToIcon: !nativeColorIcon,
            tooltip: cataloguePillTooltip(url),
            onTap: () {
              if (onOpenUrl != null) {
                onOpenUrl!(url.trim());
              } else {
                openUrl(url.trim());
              }
            },
          ),
        );
      }

      if (item.badge1Name != null && item.badge1Url != null) {
        final isEspacePro = item.badge1Name == 'Espace pro';
        final badge1Url = item.badge1Url!;
        final tooltipEspacePro = cataloguePillTooltip(badge1Url);
        // Quand onOpenUrl est fourni : ouvrir dans la fenêtre sous la barre (remplace le contenu au clic suivant).
        if (isEspacePro && onOpenUrl != null) {
          cataloguePills.add(
            HoverPillButton(
              label: item.badge1Name!,
              icon: Icons.open_in_new,
              iconWidget: _externalLinkIconWidget(),
              tooltip: tooltipEspacePro,
              onTap: () => onOpenUrl!(badge1Url.trim()),
            ),
          );
        } else if (isEspacePro && onOpenEspacePro != null) {
          cataloguePills.add(
            HoverPillButton(
              label: item.badge1Name!,
              icon: Icons.open_in_new,
              iconWidget: _externalLinkIconWidget(),
              tooltip: tooltipEspacePro,
              onTap: () {
                onOpenEspacePro!(
                  context,
                  badge1Url.trim(),
                  item.label.trim().isNotEmpty
                      ? item.label
                      : item.labelRaw.trim(),
                  item.iconUrl,
                );
              },
            ),
          );
        } else if (isEspacePro) {
          cataloguePills.add(
            HoverPillButton(
              label: item.badge1Name!,
              icon: Icons.open_in_new,
              iconWidget: _externalLinkIconWidget(),
              tooltip: tooltipEspacePro,
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(badge1Url.trim());
                } else {
                  openUrl(badge1Url.trim());
                }
              },
            ),
          );
        } else {
          addCataloguePill(item.badge1Name!, item.badge1Url!);
        }
      }
      if (item.badge2Name != null && item.badge2Url != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        addCataloguePill(item.badge2Name!, item.badge2Url!);
      }
      if (item.badge3Name != null && item.badge3Url != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        addCataloguePill(item.badge3Name!, item.badge3Url!);
      }
      if (item.badge4Name != null && item.badge4Url != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        addCataloguePill(item.badge4Name!, item.badge4Url!);
      }
      if (item.badge5Name != null && item.badge5Url != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        addCataloguePill(item.badge5Name!, item.badge5Url!);
      }
      if (item.badge6Name != null && item.badge6Url != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        addCataloguePill(item.badge6Name!, item.badge6Url!);
      }
      if (onOpenDisponibiliteProduits != null) {
        if (cataloguePills.isNotEmpty) {
          cataloguePills.add(const SizedBox(width: 6));
        }
        cataloguePills.add(
          HoverPillButton(
            label: 'disponibilité produits',
            icon: Icons.inventory_2_outlined,
            tooltip:
                'Ouvrir la disponibilité produits (semaine 13) dans la fenêtre sous la barre',
            onTap: onOpenDisponibiliteProduits!,
          ),
        );
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
    // 📦 CERP (CERP.csv + CO&PHARM 2026) — ligne 2 : EAN/CIP + badge(s) avec URL au clic
    // ─────────────────────────────
    if (item.source == SourceType.cerp) {
      final cerpWidgets = <Widget>[];
      final cipCode = item.cip13
          ?.replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll(RegExp(r'\s'), '');
      if (cipCode != null && cipCode.isNotEmpty) {
        final label = cipCode.length == 13 ? 'EAN' : 'CIP';
        cerpWidgets.add(CodeBadgeWithCopy(
          label: label,
          value: cipCode,
          tooltip: 'Copier le code $label',
          fontSize: 10,
        ),);
      }
      void addCerpPill(String name, String url) {
        if (name.isEmpty || url.isEmpty) return;
        final urlTrim = url.trim();
        cerpWidgets.add(HoverPillButton(
          label: name,
          icon: _isPdfUrl(urlTrim) ? null : iconForUrl(urlTrim),
          iconWidget:
              _isPdfUrl(urlTrim) ? _pdfIconWidget() : _externalLinkIconWidget(),
          tooltip: '↗ $urlTrim',
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl!(urlTrim);
            } else {
              openUrl(urlTrim);
            }
          },
        ),);
      }

      if (item.badge1Name != null &&
          item.badge1Url != null &&
          item.badge1Url!.trim().isNotEmpty) {
        addCerpPill(item.badge1Name!.trim(), item.badge1Url!.trim());
      }
      if (item.badge2Name != null &&
          item.badge2Url != null &&
          item.badge2Url!.trim().isNotEmpty) {
        addCerpPill(item.badge2Name!.trim(), item.badge2Url!.trim());
      }
      if (cerpWidgets.isEmpty &&
          item.url != null &&
          item.url!.trim().isNotEmpty) {
        addCerpPill('Ouvrir', item.url!.trim());
      }
      if (cerpWidgets.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: resultLineGap),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: cerpWidgets,
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
      final hasBiosim =
          item.biosimilaireOf != null && item.biosimilaireOf!.trim().isNotEmpty;
      final hasBioref = item.isBioreferent == true;

      final line2Children = <Widget>[];

      // CIP badge en début de ligne 2 (déplacé depuis ligne 1 pour éviter la troncature).
      // Parapharmacie / cosmétique / pansements Medipim : pas de 2ᵉ ligne CIP (EAN déjà en ligne 1).
      final cipCode = item.cip13?.replaceAll('"', '').replaceAll("'", '');
      final cipDigits = cipCode?.replaceAll(RegExp(r'\D'), '') ?? '';
      final hasMedipimMeta = ((item.medipimProductId ?? '').trim().isNotEmpty) ||
          item.medipimCategoryPath != null;
      final isLikelyParapharmLike =
          medipimCategoryPathIsBeautyOrDressing(item.medipimCategoryPath) ||
              (hasMedipimMeta && !cipDigits.startsWith('34009'));
      if (cipCode != null &&
          cipCode.isNotEmpty &&
          !isLikelyParapharmLike) {
        line2Children.add(
          CodeBadgeWithCopy(
            label: 'CIP',
            value: cipCode,
            tooltip: 'Copier le CIP',
            fontSize: 10,
            shrinkWrap: isInjected,
          ),
        );
      }

      /// Fiches OMÉDIT (VOC) : affichées sur une dernière ligne dédiée pour ne pas empiéter sur le texte « mise à jour ».
      final vocLineChildren = <Widget>[];

      final showPlusInfosBdm = (statutsForCis != null &&
              statutsForCis!.isNotEmpty) ||
          (tauxRemboursement != null && tauxRemboursement!.trim().isNotEmpty) ||
          (compositionLine != null && compositionLine!.trim().isNotEmpty) ||
          (listes != null && listes!.isNotEmpty);

      // Badges S/AS, EXCEPTION, OTC/Libre accès, PIH, HOP : affichés uniquement en ligne 1 (ResultLine1), pas ici.

      // Badge « arrêt de commercialisation » pour tout produit dont le CIS est dans CIS_CIP_Dispo_Spec (BDPM).
      final isArretCommercialisation = cisKey.isNotEmpty &&
          (cisArretCommercialisation?.contains(cisKey) ?? false);
      final arretInfo =
          (isArretCommercialisation && arretCommercialisationByCis != null)
              ? arretCommercialisationByCis![cisKey]
              : null;
      if (isArretCommercialisation) {
        line2Children.add(
          _ArretCommercialisationBadge(
            dateArret: arretInfo?.dateArret,
            url: arretInfo?.url,
            onOpenUrl: onOpenUrl,
          ),
        );
        line2Children.add(const SizedBox(width: 6));
      }

      // Produit concerné par un rappel de lot ANSM : badge rouge "rappel de lot" (ligne 2), sans limite de durée.
      final matchesLastRappel = ansmLastRappel != null &&
          isProductConcernedByLastRappel(item, ansmLastRappel!);
      final inCsvRappel = recalledProductNames != null &&
          item.labelRaw.trim().isNotEmpty &&
          recalledProductNames!
              .contains(normalizeProductNameForRappel(item.labelRaw));
      final isConcerned = matchesLastRappel || inCsvRappel;
      final rappelUrl =
          (medicamentRappels != null && medicamentRappels!.isNotEmpty
                  ? findMatchingRappel(item, medicamentRappels!)?.url
                  : null) ??
              ansmLastRappel?.url ??
              _kAnsmRappelsMedicamentsUrl;

      if (isConcerned && rappelUrl.isNotEmpty) {
        if (line2Children.isNotEmpty) {
          line2Children.add(const SizedBox(width: 6));
        }
        line2Children.add(
          _RappelDeLotBadge(
            url: rappelUrl,
            onOpenUrl: onOpenUrl,
          ),
        );
      }

      // Badge génériques 2026 : princeps et génériques partagent le même CIS. On distingue par le 1er mot du libellé.
      // - Générique (libellé commence par DCI, ex. ZOLPIDEM) → badge "princeps : [nom]" (rose).
      // - Princeps (libellé commence par nom princeps, ex. STILNOX) → badge "générique : [nom]" (rose).
      final generique2026Info =
          (generiques2026ByCis != null && cisKey.isNotEmpty)
              ? generiques2026ByCis![cisKey]
              : null;
      bool isProductPrinceps = false;
      if (generique2026Info != null) {
        isProductPrinceps =
            isProductPrincepsForGenerique2026(item, generique2026Info);
        final princepsLabel = generique2026Info.princepsDisplay.trim();
        final col1Label =
            col1BeforeParentheses(generique2026Info.genericNameColA);

        if (isProductPrinceps && col1Label.isNotEmpty) {
          // Produit princeps (ex. STILNOX) : badge "générique : [nom]" (rose).
          final dci = dciFromGenericLabel(col1Label);
          final dciStr = dci.trim().isNotEmpty ? dci : col1Label;
          final genericName = generiques2026PrincepsKeyToGenericName != null
              ? generiques2026PrincepsKeyToGenericName![
                  normalizePrincepsKey(princepsLabel)]
              : generique2026Info.genericNameColA;
          line2Children
              .add(_PrincepsLine2Widget(dci: dciStr, onDciTap: onDciTap));
          if (genericName != null && genericName.isNotEmpty) {
            line2Children.add(const SizedBox(width: 6));
            line2Children.add(_PrincepsEqualsGeneriqueBadge(
              genericDisplayName: shortGenericDisplayForBadge(genericName),
              tooltipFullGeneric: genericName,
              dciForTap: dciStr,
              onDciTap: onDciTap,
              isAnsmHybridCip: _isAnsmHybridCip13(item),
            ),);
          }
          if (showPlusInfosBdm) {
            line2Children.add(const SizedBox(width: 6));
            final isDisabled = item.isInactive ||
                item.hospitalOnly == true ||
                item.isNsfpEffective == true;
            line2Children.add(PlusInfosBadge(
              statuts: statutsForCis ?? const [],
              tauxRemboursement: tauxRemboursement,
              compositionLine: compositionLine,
              listes: listes ?? const [],
              isDisabled: isDisabled,
            ),);
          }
        } else if (princepsLabel.isNotEmpty && !isProductPrinceps) {
          // Produit générique : badge "princeps : [nom]" (rose).
          final shortName = shortPrincepsDisplayForBadge(princepsLabel);
          String tooltip = princepsLabel;
          String dciToTap = '';
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
        }
        if (item.url != null &&
            item.url!.trim().isNotEmpty &&
            !medipimCategoryPathIsBeautyOrDressing(item.medipimCategoryPath)) {
          if (line2Children.isNotEmpty) {
            line2Children.add(const SizedBox(width: 6));
          }
          line2Children.add(
            HoverPillButton(
              label: 'RCP',
              icon: Icons.description_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Accéder au RCP',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.url!.trim());
                } else {
                  openUrl(item.url!.trim());
                }
              },
            ),
          );
        }

        // Vidéo de démonstration (videos.csv) : afficher à droite de RCP quand injecté.
        if (isInjected &&
            onOpenTherapeuticVideo != null &&
            videosByCip13 != null &&
            item.cip13 != null) {
          final cip = item.cip13!.replaceAll(RegExp(r'\D'), '').trim();
          final vurl = cip.isNotEmpty ? videosByCip13![cip]?.trim() : null;
          if (vurl != null && vurl.isNotEmpty) {
            if (line2Children.isNotEmpty) {
              line2Children.add(const SizedBox(width: 6));
            }
            line2Children.add(
              HoverPillButton(
                label: 'vidéo de démonstration',
                icon: Icons.video_library_outlined,
                iconWidget: _externalLinkIconWidget(),
                tooltip:
                    "Outils d'aide à l'utilisation des thérapeutiques inhalées (SPLF)",
                onTap: () => onOpenTherapeuticVideo!(vurl),
                maxLabelWidth: 240,
              ),
            );
          }
        }
        if (item.meddisparUrl != null && item.meddisparUrl!.trim().isNotEmpty) {
          if (line2Children.isNotEmpty) {
            line2Children.add(const SizedBox(width: 6));
          }
          line2Children.add(
            HoverPillButton(
              label: 'MEDDISPAR',
              icon: Icons.warning_amber_rounded,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Fiche MEDDISPAR',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.meddisparUrl!.trim());
                } else {
                  openUrl(item.meddisparUrl!.trim());
                }
              },
            ),
          );
        }
        // OMÉDIT (VOC) : fiches patient/pro sur une dernière ligne dédiée (voir plus bas, vocLineChildren).
        if (isInjected) {
          const maxLabelWidth = 380.0;
          if (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty) {
            if (vocLineChildren.isNotEmpty) {
              vocLineChildren.add(const SizedBox(width: 6));
            }
            final url = vocPatientUrl!.trim();
            vocLineChildren.add(
              HoverPillButton(
                label: 'fiche à destination des patients (OMEDIT)',
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
              ),
            );
          }
          if (vocProUrl != null && vocProUrl!.trim().isNotEmpty) {
            if (vocLineChildren.isNotEmpty) {
              vocLineChildren.add(const SizedBox(width: 6));
            }
            final url = vocProUrl!.trim();
            vocLineChildren.add(
              HoverPillButton(
                label:
                    'fiche à destination des professionnels de santé (OMEDIT)',
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
              ),
            );
          }
        }
        // Badges calendriers vaccinaux pour médicaments dont le libellé contient "vaccin".
        final labelForVaccin = '${item.label} ${item.labelRaw}'.toLowerCase();
        if (item.source == SourceType.bdm &&
            labelForVaccin.contains('vaccin')) {
          if (line2Children.isNotEmpty) {
            line2Children.add(const SizedBox(width: 6));
          }
          line2Children.add(
            HoverPillButton(
              label: 'Calendrier vaccinal 2025',
              icon: Icons.calendar_month_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Calendrier vaccinal 2025 (version Décembre 2025)',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(kCalendrierVaccinal2025Url);
                } else {
                  openUrl(kCalendrierVaccinal2025Url);
                }
              },
            ),
          );
          line2Children.add(const SizedBox(width: 6));
          line2Children.add(
            HoverPillButton(
              label: 'Calendrier simplifié',
              icon: Icons.calendar_view_month_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Calendrier simplifié des vaccinations',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(kCalendrierSimplifieUrl);
                } else {
                  openUrl(kCalendrierSimplifieUrl);
                }
              },
            ),
          );
        }
      } else {
        // Fallback : pas d'entrée 2026 par CIS (CSV 2026 clé = CIS du générique). Afficher princeps/générique depuis item ou map princeps → générique.
        if (item.isGeneric == true &&
            item.princepsName != null &&
            item.princepsName!.trim().isNotEmpty) {
          final princepsLabel = item.princepsName!.trim();
          final shortName = shortPrincepsDisplayForBadge(princepsLabel);
          line2Children.add(
            _GeneriqueEqualsBadge(
              princepsDisplayName: shortName,
              tooltipFullPrinceps: princepsLabel,
              dciForTap: '',
              onDciTap: onDciTap,
            ),
          );
        } else if (item.isGeneric != true &&
            hasBiosim != true &&
            hasBioref != true) {
          final genericNameFromMap =
              (generiques2026PrincepsKeyToGenericName != null &&
                      item.labelRaw.trim().isNotEmpty)
                  ? generiques2026PrincepsKeyToGenericName![
                      normalizePrincepsKey(item.labelRaw).trim()]
                  : null;
          final genericName =
              (item.genericName != null && item.genericName!.trim().isNotEmpty)
                  ? item.genericName!.trim()
                  : genericNameFromMap;
          if (genericName != null && genericName.isNotEmpty) {
            final dciStr = shortGenericDisplayForBadge(genericName);
            line2Children.add(
              _PrincepsLine2Widget(
                dci: dciStr,
                onDciTap: onDciTap,
              ),
            );
            line2Children.add(const SizedBox(width: 6));
            line2Children.add(
              _PrincepsEqualsGeneriqueBadge(
                genericDisplayName: shortGenericDisplayForBadge(genericName),
                tooltipFullGeneric: genericName,
                dciForTap: dciStr,
                onDciTap: onDciTap,
                isAnsmHybridCip: _isAnsmHybridCip13(item),
              ),
            );
            if (showPlusInfosBdm) {
              line2Children.add(const SizedBox(width: 6));
              final isDisabled = item.isInactive ||
                  item.hospitalOnly == true ||
                  item.isNsfpEffective == true;
              line2Children.add(
                PlusInfosBadge(
                  statuts: statutsForCis ?? const [],
                  tauxRemboursement: tauxRemboursement,
                  compositionLine: compositionLine,
                  listes: listes ?? const [],
                  isDisabled: isDisabled,
                ),
              );
            }
          }
        }
      }
      // Badges biosimilaire + OMEDIT + RCP + MEDDISPAR regroupés : on veut que RCP et OMEDIT
      // tiennent sur la même ligne (pas de wrap intermédiaire). Ces badges sont ajoutés ici
      // puis la suite du flux saute les insertions dupliquées grâce à [biosimRcpBadgesAdded].
      final spacingBetweenBadges = hasBiosim ? 2.0 : 3.0;
      var biosimRcpBadgesAdded = false;
      if (hasBiosim) {
        line2Children
            .add(_BiosimilaireBadge(bioreferent: item.biosimilaireOf!));
        final biosimInfo = (biosimilairesInfoByCip != null &&
                item.cip13 != null)
            ? biosimilairesInfoByCip![item.cip13!.replaceAll(RegExp(r'\D'), '')]
            : null;
        if (biosimInfo != null && biosimInfo.trim().isNotEmpty) {
          line2Children.add(SizedBox(width: spacingBetweenBadges));
          line2Children.add(_BiosimilaireInfosBadge(infoText: biosimInfo));
        }
        line2Children.add(SizedBox(width: spacingBetweenBadges));
        line2Children.add(
          HoverPillButton(
            label: 'OMEDIT',
            icon: Icons.article_outlined,
            trailingWidget: _pdfIconWidget(),
            tooltip:
                'Bonnes pratiques de substitution en officine (OMEDIT, mars 2026)',
            maxLabelWidth: 200,
            onTap: () {
              final u = kOmeditBiosimSubstitutionPdfUrl;
              if (onOpenUrl != null) {
                onOpenUrl!(u);
              } else {
                openUrl(u);
              }
            },
          ),
        );
        // RCP directement à droite d’OMEDIT pour rester sur la même ligne (Wrap).
        if (item.url != null &&
            item.url!.trim().isNotEmpty &&
            !medipimCategoryPathIsBeautyOrDressing(item.medipimCategoryPath)) {
          line2Children.add(SizedBox(width: spacingBetweenBadges));
          line2Children.add(
            HoverPillButton(
              label: 'RCP',
              icon: Icons.description_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Accéder au RCP',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.url!.trim());
                } else {
                  openUrl(item.url!.trim());
                }
              },
            ),
          );
        }
        if (item.meddisparUrl != null && item.meddisparUrl!.trim().isNotEmpty) {
          line2Children.add(SizedBox(width: spacingBetweenBadges));
          line2Children.add(
            HoverPillButton(
              label: 'MEDDISPAR',
              icon: Icons.warning_amber_rounded,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Fiche MEDDISPAR',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.meddisparUrl!.trim());
                } else {
                  openUrl(item.meddisparUrl!.trim());
                }
              },
            ),
          );
        }
        biosimRcpBadgesAdded = true;
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
        if (line2Children.isNotEmpty) {
          line2Children.add(SizedBox(width: spacingBetweenBadges));
        }
        final String dateRemise =
            info.dateRemise.trim().isNotEmpty ? info.dateRemise : info.dateMaj;
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

        final String tooltipStatut =
            'statut ANSM : ${ansmLabel(statutLibelle)} $extraInfo';
        line2Children.add(
          OffiboxTooltip(
            message: tooltipStatut,
            waitDuration: const Duration(milliseconds: 400),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ansmEmoji(statutLibelle),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ansmLabel(statutLibelle),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: color,
                              fontFamily: 'Spinnaker',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              extraInfo,
                              style: const TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: OffiboxColors.primary,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OffiboxColors.primary
                                  .withValues(alpha: 0.15),
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
        );
      }

      // Badge « plus d'infos » en ligne 2 (après les autres badges). Déjà ajouté à droite du badge DCI pour les princeps.
      if (showPlusInfosBdm &&
          (generique2026Info == null || !isProductPrinceps)) {
        final isDisabled = item.isInactive ||
            item.hospitalOnly == true ||
            item.isNsfpEffective == true;
        if (line2Children.isNotEmpty) {
          line2Children.add(SizedBox(width: spacingBetweenBadges));
        }
        line2Children.add(
          PlusInfosBadge(
            statuts: statutsForCis ?? const [],
            tauxRemboursement: tauxRemboursement,
            compositionLine: compositionLine,
            listes: listes ?? const [],
            isDisabled: isDisabled,
          ),
        );
      }

      // Non génériques : RCP et MEDDISPAR sur la même ligne que + d'infos (ligne 2).
      // En cas de biosimilaire, ces badges ont déjà été ajoutés juste après OMEDIT
      // pour garantir qu’ils restent sur la même ligne — on saute donc ici.
      if (generique2026Info == null) {
        if (!biosimRcpBadgesAdded &&
            item.url != null &&
            item.url!.trim().isNotEmpty &&
            !medipimCategoryPathIsBeautyOrDressing(item.medipimCategoryPath)) {
          if (line2Children.isNotEmpty) {
            line2Children.add(SizedBox(width: spacingBetweenBadges));
          }
          line2Children.add(
            HoverPillButton(
              label: 'RCP',
              icon: Icons.description_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Accéder au RCP',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.url!.trim());
                } else {
                  openUrl(item.url!.trim());
                }
              },
            ),
          );
        }
        // Vidéo de démonstration (videos.csv) : afficher à droite de RCP quand injecté.
        if (isInjected &&
            onOpenTherapeuticVideo != null &&
            videosByCip13 != null &&
            item.cip13 != null) {
          final cip = item.cip13!.replaceAll(RegExp(r'\D'), '').trim();
          final vurl = cip.isNotEmpty ? videosByCip13![cip]?.trim() : null;
          if (vurl != null && vurl.isNotEmpty) {
            if (line2Children.isNotEmpty) {
              line2Children.add(SizedBox(width: spacingBetweenBadges));
            }
            line2Children.add(
              HoverPillButton(
                label: 'vidéo de démonstration',
                icon: Icons.video_library_outlined,
                iconWidget: _externalLinkIconWidget(),
                tooltip:
                    "Outils d'aide à l'utilisation des thérapeutiques inhalées (SPLF)",
                onTap: () => onOpenTherapeuticVideo!(vurl),
                maxLabelWidth: 240,
              ),
            );
          }
        }
        if (!biosimRcpBadgesAdded &&
            item.meddisparUrl != null &&
            item.meddisparUrl!.trim().isNotEmpty) {
          if (line2Children.isNotEmpty) {
            line2Children.add(SizedBox(width: spacingBetweenBadges));
          }
          line2Children.add(
            HoverPillButton(
              label: 'MEDDISPAR',
              icon: Icons.warning_amber_rounded,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Fiche MEDDISPAR',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(item.meddisparUrl!.trim());
                } else {
                  openUrl(item.meddisparUrl!.trim());
                }
              },
            ),
          );
        }
        // OMÉDIT (VOC) : fiches patient/pro sur une dernière ligne dédiée (voir plus bas, vocLineChildren).
        if (isInjected) {
          const maxLabelWidth = 380.0;
          if (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty) {
            if (vocLineChildren.isNotEmpty) {
              vocLineChildren.add(SizedBox(width: spacingBetweenBadges));
            }
            final url = vocPatientUrl!.trim();
            vocLineChildren.add(
              HoverPillButton(
                label: 'fiche à destination des patients (OMEDIT)',
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
              ),
            );
          }
          if (vocProUrl != null && vocProUrl!.trim().isNotEmpty) {
            if (vocLineChildren.isNotEmpty) {
              vocLineChildren.add(SizedBox(width: spacingBetweenBadges));
            }
            final url = vocProUrl!.trim();
            vocLineChildren.add(
              HoverPillButton(
                label:
                    'fiche à destination des professionnels de santé (OMEDIT)',
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
              ),
            );
          }
        }
        // Badges calendriers vaccinaux pour médicaments BDM dont le libellé contient "vaccin".
        final labelForVaccin = '${item.label} ${item.labelRaw}'.toLowerCase();
        if (item.source == SourceType.bdm &&
            labelForVaccin.contains('vaccin')) {
          if (line2Children.isNotEmpty) {
            line2Children.add(SizedBox(width: spacingBetweenBadges));
          }
          line2Children.add(
            HoverPillButton(
              label: 'Calendrier vaccinal 2025',
              icon: Icons.calendar_month_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Calendrier vaccinal 2025 (version Décembre 2025)',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(kCalendrierVaccinal2025Url);
                } else {
                  openUrl(kCalendrierVaccinal2025Url);
                }
              },
            ),
          );
          line2Children.add(SizedBox(width: spacingBetweenBadges));
          line2Children.add(
            HoverPillButton(
              label: 'Calendrier simplifié',
              icon: Icons.calendar_view_month_outlined,
              iconWidget: _externalLinkIconWidget(),
              tooltip: 'Calendrier simplifié des vaccinations',
              onTap: () {
                if (onOpenUrl != null) {
                  onOpenUrl!(kCalendrierSimplifieUrl);
                } else {
                  openUrl(kCalendrierSimplifieUrl);
                }
              },
            ),
          );
        }

        // Logo source Claude Bernard affiché en ligne 3 (result_line_3_actions.dart) — pas en ligne 2.
      }

      // Source : BDM affichée en ligne 3 après RCP et MEDDISPAR (voir result_line_3_actions.dart).
      if (line2Children.isEmpty && vocLineChildren.isEmpty) {
        return const SizedBox.shrink();
      }

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
    // 🔁 BDM / LPP / liste — CIP (BDM), EAN (DM liste) ; DM/véto injectés traités plus haut
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
              fontWeight: FontWeight.w400,
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
            const Icon(Icons.medication_rounded, size: 14, color: _purple),
            const SizedBox(width: 6),
            Text(
              'BIOSIMILAIRE de ${bioreferent.toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: _purple,
                fontFamily: 'Spinnaker',
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),),
        title: const Text(
          'INFOS DISPENSATION',
          style:
              TextStyle(fontFamily: 'Spinnaker', fontWeight: FontWeight.w600),
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
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
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
                  fontWeight: FontWeight.w400,
                  color: _teal,
                  fontFamily: 'Spinnaker',
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
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontFamily: 'Spinnaker',
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
      'https://ansm.sante.fr/documents/reference/registre-des-groupes-hybrides';
  static const _rose = Color(0xFFF06292); // rose clair (Material Pink 300)
  static const double _pillHeight = 30.8;

  @override
  Widget build(BuildContext context) {
    final tooltip = tooltipFullPrinceps != null &&
            tooltipFullPrinceps!.trim().isNotEmpty
        ? '${tooltipFullPrinceps!.trim()}\n\nclic : ouvrir le registre des groupes hybrides'
        : 'acces au registre des groupes hybrides';
    return OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () {
          openUrl(_urlGeneriques);
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
              const Icon(Icons.medication_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'princeps : $princepsDisplayName',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  fontFamily: 'Spinnaker',
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
    this.isAnsmHybridCip = false,
  });

  final String genericDisplayName;
  final String? tooltipFullGeneric;
  final String dciForTap;
  final void Function(String)? onDciTap;
  final bool isAnsmHybridCip;

  static const _urlGeneriques =
      'https://ansm.sante.fr/documents/reference/registre-des-groupes-hybrides';
  static const _rose = Color(0xFFF06292); // rose clair (Material Pink 300)
  static const double _pillHeight = 30.8;

  @override
  Widget build(BuildContext context) {
    final labelKind = isAnsmHybridCip ? 'hybride' : 'générique';
    final tooltip = tooltipFullGeneric != null &&
            tooltipFullGeneric!.trim().isNotEmpty
        ? '${isAnsmHybridCip ? 'Hybride' : 'Générique'} : ${tooltipFullGeneric!.trim()}\n\n'
            'clic : ouvrir le registre des groupes hybrides'
        : 'clic : ouvrir le registre des groupes hybrides';

    return OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () {
          openUrl(_urlGeneriques);
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
              const Icon(Icons.medication_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '$labelKind : $genericDisplayName',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  fontFamily: 'Spinnaker',
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
  return parts.isNotEmpty
      ? parts.first.toUpperCase()
      : genericName.toUpperCase();
}

/// Ligne 2 princeps : badge rose clair ": DCI : avec la composition [composition]" (même style que l’ancien badge princeps).
class _PrincepsLine2Widget extends StatelessWidget {
  const _PrincepsLine2Widget({
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
          fontWeight: FontWeight.w400,
          color: _teal,
          fontFamily: 'Spinnaker',
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
          message: onDciTap != null
              ? 'afficher la liste des génériques'
              : badgeLabel,
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
                  fontWeight: FontWeight.w400,
                  color: _orange,
                  fontFamily: 'Spinnaker',
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medication_rounded, size: 13, color: _purple),
              SizedBox(width: 5),
              Text(
                'BIORÉFÉRENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                  color: _purple,
                  fontFamily: 'Spinnaker',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────
// BADGE CODE AVEC COPIE (public pour ResultLine1) — "copié" inline avec animation fondu
// ─────────────────────────────
class CodeBadgeWithCopy extends StatefulWidget {
  const CodeBadgeWithCopy({
    super.key,
    required this.label,
    required this.value,
    required this.tooltip,
    this.leadingIcon,
    this.fontSize = 11,
    this.leadingIconSize,
    this.height,
    this.onTap,
    this.copyable = true,
    this.shrinkWrap = false,
    /// Si false : affiche seulement [value] (pas « label : value »), pour PMI / santé sexuelle.
    this.showLabelInBadge = true,
  });

  final String label;
  final String value;
  final String tooltip;
  final IconData? leadingIcon;
  final double fontSize;
  final double? leadingIconSize;
  final double? height;

  /// Si false : pas d’icône copier ni action (ex. ville annuaire affichage seulement).
  final bool copyable;

  /// Si true : badge à largeur intrinsèque (pas d’étirement pleine ligne du parent).
  final bool shrinkWrap;

  /// Afficher « label : value » ; si false, seulement la valeur (icône optionnelle conservée).
  final bool showLabelInBadge;

  /// Callback additionnel appelé après la copie.
  final VoidCallback? onTap;

  @override
  State<CodeBadgeWithCopy> createState() => _CodeBadgeWithCopyState();
}

class _CodeBadgeWithCopyState extends State<CodeBadgeWithCopy>
    with SingleTickerProviderStateMixin {
  bool _showCopied = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onCopy() {
    if (!widget.copyable) return;
    Clipboard.setData(ClipboardData(text: widget.value));
    widget.onTap?.call();
    setState(() => _showCopied = true);
    _animController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) setState(() => _showCopied = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCipBadge = widget.label.trim().toUpperCase() == 'CIP';
    final useCompact = widget.height != null;
    final effectiveFontSize = (useCompact ? 10.0 : widget.fontSize) -
        (isCipBadge ? 0.5 : 0.0);
    final iconSize =
        (widget.leadingIconSize ?? effectiveFontSize.clamp(10.0, 12.0))
            .toDouble();
    final effectiveIconSize = useCompact ? 14.0 : iconSize;
    final double padH =
        useCompact ? 8.0 : (isCipBadge ? 7.0 : (effectiveFontSize <= 10 ? 6.0 : 10.0));
    final double padV = useCompact
        ? (widget.height! - effectiveIconSize) / 2
        : (effectiveFontSize <= 10 ? 2.0 : 4.0);

    final textStyle = TextStyle(
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      fontFamily: 'Spinnaker',
    );
    final valueText = widget.showLabelInBadge && widget.label.trim().isNotEmpty
        ? '${widget.label} : ${widget.value}'
        : widget.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded =
            !widget.shrinkWrap && constraints.maxWidth.isFinite && !isCipBadge;

        Widget content = Container(
          width: bounded ? double.infinity : null,
          padding: EdgeInsets.symmetric(
              horizontal: padH, vertical: padV.clamp(2.0, 12.0),),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon,
                    size: effectiveIconSize, color: Colors.black54,),
                SizedBox(width: effectiveFontSize <= 10 ? 3 : 4),
              ],
              if (bounded)
                Expanded(
                  child: Text(
                    valueText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: textStyle,
                  ),
                )
              else
                Text(valueText, style: textStyle),
              if (widget.copyable) ...[
                SizedBox(width: effectiveFontSize <= 10 ? 4 : 6),
                Icon(Icons.copy, size: effectiveIconSize, color: Colors.black54),
              ],
            ],
          ),
        );

        if (widget.height != null) {
          content =
              SizedBox(height: widget.height, child: Center(child: content));
        }

        final tooltipChild = OffiboxTooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 900),
          child: widget.copyable
              ? InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _onCopy,
                  child: content,
                )
              : content,
        );

        if (!bounded) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tooltipChild,
              if (_showCopied) ...[
                const SizedBox(width: 6),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _CopiedIndicator(),
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: tooltipChild),
            if (_showCopied) ...[
              const SizedBox(width: 6),
              FadeTransition(
                opacity: _fadeAnim,
                child: _CopiedIndicator(),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Widget "copié" (checkmark + texte) — style barre, bordure verte, halo.
class _CopiedIndicator extends StatelessWidget {
  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _green, width: 1),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: _green),
          SizedBox(width: 4),
          Text(
            'copié',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────
// BADGE CODE (CIP/CIS ligne 2) — "copié" inline avec animation fondu
// ─────────────────────────────
class _CodeBadge extends StatefulWidget {
  final String label;
  final String value;

  const _CodeBadge({
    required this.label,
    required this.value,
  });

  @override
  State<_CodeBadge> createState() => _CodeBadgeState();
}

class _CodeBadgeState extends State<_CodeBadge>
    with SingleTickerProviderStateMixin {
  bool _showCopied = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isCip13 => widget.label == 'CIP' && widget.value.length == 13;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _showCopied = true);
    _animController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) setState(() => _showCopied = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OffiboxTooltip(
          message: 'Copier le code',
          waitDuration: const Duration(milliseconds: 900),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _onCopy,
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
                      '${widget.label} : ${widget.value}',
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
        ),
        if (_showCopied) ...[
          const SizedBox(width: 6),
          FadeTransition(
            opacity: _fadeAnim,
            child: _CopiedIndicator(),
          ),
        ],
      ],
    );
  }

  /// 💊 Découpe CIP13 : 34009 1234567 8
  Widget _buildCipRichText() {
    final part1 = widget.value.substring(0, 5);
    final cip7 = widget.value.substring(5, 12);
    final last = widget.value.substring(12);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          letterSpacing: 0.2,
          fontFamily: 'Spinnaker',
          fontWeight: FontWeight.w400,
        ),
        children: [
          const TextSpan(text: 'CIP : '),
          TextSpan(text: '$part1 '),
          TextSpan(
            text: cip7,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: 'Spinnaker',
            ),
          ),
          TextSpan(text: ' $last'),
        ],
      ),
    );
  }
}
