// ============================================================================
// 🧱 COMMON SPANS — OFFIBOX (API STABLE)
// ============================================================================
// - UI PUR (aucune logique métier)
// - Aucun accès à State / modèles / SourceType
// - Réutilisable partout (desktop / mobile)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/ui/widgets/offibox_tooltip.dart';
import 'package:offibox/utils/open_url.dart';

/// 🎨 COULEUR OFFIBOX
const Color offiboxTeal = Color(0xFF5A9094);

/// ============================================================================
/// 🧱 BADGE CONTAINER (WIDGET PUR)
/// ============================================================================
Widget badgeContainer({
  required String text,
  Color background = const Color(0xFFE8F3F4),
  Color border = offiboxTeal,
  Color textColor = offiboxTeal,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: textColor,
      ),
    ),
  );
}

// BADGE GENERIQUE POUR TOUS LES CAS// 
WidgetSpan squareTagSpan({
  required String label,
  required Color color,
  required String tooltip,
  String? url,
}) {
  final content = IntrinsicWidth(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0.3,
          fontFamily: 'Spinnaker',
        ),
      ),
    ),
  );

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: url == null
          ? content
          : GestureDetector(
              onTap: () => openUrl(url),
              child: content,
            ),
    ),
  );
}

/// Même rendu que [squareTagSpan] mais en [Widget] pour utilisation en ligne 2 (Row/Wrap), ex. badges métier BDM.
Widget squareTagWidget({
  required String label,
  required Color color,
  required String tooltip,
  String? url,
}) {
  final content = IntrinsicWidth(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0.3,
          fontFamily: 'Spinnaker',
        ),
      ),
    ),
  );
  return OffiboxTooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 300),
    child: url == null
        ? content
        : GestureDetector(
            onTap: () => openUrl(url),
            child: content,
          ),
  );
}



/// ============================================================================
/// 🧩 BADGE SPAN (INTERNE)
/// ============================================================================
WidgetSpan _badgeSpan(String text) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: badgeContainer(text: text),
    ),
  );
}

/// ============================================================================
/// 🧬 GÉNÉRIQUE / PRINCEPS (SPANS PUBLICS)
/// ============================================================================
WidgetSpan? genericBadgeSpan({
  required bool isGeneric,
  required String? princepsName,
}) {
  if (isGeneric && princepsName != null && princepsName.isNotEmpty) {
    return _badgeSpan('PRINCEPS : ${princepsName.toUpperCase()}');
  }
  return null;
}

WidgetSpan? princepsBadgeSpan({
  required bool isGeneric,
  required String? genericName,
}) {
  if (!isGeneric && genericName != null && genericName.isNotEmpty) {
    return _badgeSpan('GÉNÉRIQUE : ${genericName.toUpperCase()}');
  }
  return null;
}

/// ============================================================================
/// 🟪 BIORÉFÉRENT
/// ============================================================================
InlineSpan bioreferentBadgeSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => openUrl(
          'https://www.ameli.fr/charente-maritime/pharmacien/'
          'exercice-professionnel/delivrance-produits-sante/'
          'regles-delivrance-prise-charge/'
          'medicaments-biosimilaires/'
          'regles-dispensation-et-substitution',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF7C3AED)),
          ),
          child: const Text(
            'BIORÉFÉRENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Color(0xFF7C3AED),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 🩸 Médicaments dérivés du sang (MDS)
/// Utilise item.isMds (défini par le mapper BDM)
InlineSpan? bloodPictoSpan(SearchResult item) {
  if (item.isMds != true) return null;

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: OffiboxTooltip(
        message: 'Médicament dérivé du sang',
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => openUrl(
            'https://www.meddispar.fr/Medicaments-derives-du-sang/Contexte#nav-buttons',
          ),
          borderRadius: BorderRadius.circular(12),
          child: const Text(
            '🩸',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    ),
  );
}

//NSFP// 
WidgetSpan nsfpIconSpan({
  String tooltip = 'Ne se fait plus',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          '❌',
          style: TextStyle(fontSize: 14),
        ),
      ),
    ),
  );
}


/// ============================================================================
/// 📄 ICÔNES PDF / LIEN EXTERNE
/// ============================================================================
WidgetSpan pdfIconSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SvgPicture.asset(
        'assets/icons/pdf_red.svg',
        width: 20,
        height: 20,
      ),
    ),
  );
}

WidgetSpan externalLinkIconSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SvgPicture.asset(
        'assets/icons/link-external.svg',
        width: 20,
        height: 20,
        colorFilter:
            const ColorFilter.mode(offiboxTeal, BlendMode.srcIn),
      ),
    ),
  );
}

/// ============================================================================
/// 🔗 MARKERS CLIQUABLES (EMOJI)
/// ============================================================================
WidgetSpan clickableMarkerSpan({
  required String emoji,
  String? tooltip,
  required String url,
}) {
  final content = InkWell(
    onTap: () => openUrl(url),
    child: Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    ),
  );
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: (tooltip != null && tooltip.isNotEmpty)
        ? OffiboxTooltip(message: tooltip, child: content)
        : content,
  );
}
// HOPITAL//

WidgetSpan hopSquareSpan({
  String tooltip = 'Réservé à l’usage hospitalier',
}) {
  return squareTagSpan(
    label: 'HOP',
    color: Colors.blue.shade700,
    tooltip: tooltip,
  );
}

/// Générique (ligne 1 BDM) : blanc sur fond #08CDC5.
WidgetSpan geSquareSpan({
  String tooltip = 'Générique',
}) {
  return squareTagSpan(
    label: 'Gé',
    color: const Color(0xFF08CDC5),
    tooltip: tooltip,
  );
}

/// Générique (ligne 1 BDM, source fic03spe) : blanc sur fond vert.
WidgetSpan geSquareSpanGreen({
  String tooltip = 'Générique',
}) {
  return squareTagSpan(
    label: 'Gé',
    color: const Color(0xFF2E7D32),
    tooltip: tooltip,
  );
}

/// Princeps (ligne 1 BDM) : blanc sur fond #92BFD6.
WidgetSpan princepsSquareSpan({
  String tooltip = 'Princeps',
}) {
  return squareTagSpan(
    label: 'Princeps',
    color: const Color(0xFF92BFD6),
    tooltip: tooltip,
  );
}

  // 🟦 EXCEPTION//
WidgetSpan exceptionSquareSpan({
  String tooltip = 'Médicament d’exception',
}) {
  return squareTagSpan(
    label: 'EXCEPTION',
    color: Colors.blue.shade600,
    tooltip: tooltip,
    url:
    'https://www.meddispar.fr/Medicaments-d-exception/Criteres#nav-buttons',
  );
}


// 🟧 PIH — Prescription Initiale Hospitalière
WidgetSpan pihSquareSpan({
  String tooltip = 'Prescription initiale hospitalière',
}) {
  return squareTagSpan(
    label: 'PIH',
    color: Colors.orange.shade700,
    tooltip: tooltip,
    url:
        'https://www.meddispar.fr/Medicaments-a-prescription-restreinte/'
        'Medicaments-a-prescription-initiale-hospitaliere/'
        'Criteres#nav-buttons',
  );
}


// 🟪 SURVEILLANCE PARTICULIÈRE — Médicament sous surveillance particulière
WidgetSpan surveillanceSquareSpan({
  String tooltip = 'Médicament nécessitant une surveillance particulière',
}) {
  return squareTagSpan(
    label: 'SURV',
    color: const Color(0xFF8E44AD), // mauve
    tooltip: tooltip,
    url:
        'https://www.meddispar.fr/Medicaments-a-prescription-restreinte/Medicaments-necessitant-une-surveillance-particuliere-pendant-le-traitement/Criteres#nav-buttons',
  );
}



//🟩 OTC/AUTRE//

WidgetSpan otcSquareSpan({
  String tooltip = 'OTC / autre / NR',
}) {
  return squareTagSpan(
    label: 'OTC/autre',
    color: Colors.lightGreenAccent.shade700, // 🟩 vert fluo
    tooltip: tooltip,
    url: 'https://ansm.sante.fr/',
  );
}


// 🩸 MDS — Médicaments dérivés du sang
WidgetSpan mdsSquareSpan({
  String tooltip = 'Médicament dérivé du sang',
}) {
  return squareTagSpan(
    label: 'MDS',
    color: Colors.deepOrange.shade700,
    tooltip: tooltip,
    url:
        'https://www.meddispar.fr/Medicaments-derives-du-sang/Contexte#nav-buttons',
  );
}

// STUPS//

WidgetSpan stupSquareSpan({
  String tooltip =
      'Médicament stupéfiant ou assimilé stupéfiant',
}) {
  return squareTagSpan(
    label: 'S/AS',
    color: Colors.red.shade700,
    tooltip: tooltip,
    url:
        'https://www.meddispar.fr/Substances-veneneuses/Medicaments-stupefiants-et-assimiles/Criteres#nav-buttons',
  );
}

/// 🔴 MTE — Médicaments à marge thérapeutique étroite (non substituables)
/// Liste CNOP : lacosamide, oxcarbazépine, lamotrigine, prégabaline, etc.
WidgetSpan mteSquareSpan({
  String tooltip = 'Médicaments à marge thérapeutique étroite',
}) {
  return squareTagSpan(
    label: 'MTE',
    color: Colors.red.shade700,
    tooltip: tooltip,
    url:
        'https://www.ordre.pharmacien.fr/les-communications/focus-sur/les-actualites/la-liste-des-medicaments-a-marge-therapeutique-etroite-non-substituables-est-etendue',
  );
}

WidgetSpan dmSquareSpan({
  String tooltip = 'Dispositifs médicaux',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.teal.shade600, // 🩹 vert/bleu médical
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );
}




WidgetSpan vetoSquareSpan({
  String tooltip = 'Médicaments vétérinaires',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: OffiboxTooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF7B4FA3), // 💜 mauve Offibox
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'VETO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );
}




/// ============================================================================
/// 💊 PILLS INLINE
/// ============================================================================
WidgetSpan pillSpan({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
  required String tooltip,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: HoverPillButton(
        label: label,
        icon: icon,
        tooltip: tooltip,
        onTap: onTap,
      ),
    ),
  );
}

WidgetSpan copyPillSpan({
  required String value,
  required String tooltip,
}) {
  return pillSpan(
    label: 'COPIER',
    icon: Icons.copy,
    tooltip: tooltip,
    onTap: () {
      Clipboard.setData(ClipboardData(text: value));
    },
  );
}

/// ============================================================================
/// 🆔 CIP SPANS (UI PUR)
/// ============================================================================
List<InlineSpan> cip13ParensSpans(String cip13) {
  final clean = cip13.replaceAll(RegExp(r'\D'), '');
  if (clean.length != 13) return [];

  return [
    const TextSpan(text: '  (CIP : '),
    TextSpan(text: clean.substring(0, 5)),
    const TextSpan(text: ' '),
    TextSpan(
      text: clean.substring(5, 12),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    const TextSpan(text: ' '),
    TextSpan(text: clean.substring(12)),
    const TextSpan(text: ')'),
  ];
}
// ============================================================================
// 🏥 MUTUELLE — BADGE MUT (BASÉ SUR squareTagSpan)
// ============================================================================
WidgetSpan amcMutSquareSpan({
  String tooltip = 'Mutuelle',
  String? url,
}) {
  return squareTagSpan(
    label: 'MUT',
    color: const Color(0xFF1B6B4F), // 🟢 vert foncé mutuelle
    tooltip: tooltip,
    url: url,
  );
}

// ============================================================================
// 🏥 AMO — BADGE AMO (BASÉ SUR squareTagSpan)
// ============================================================================

WidgetSpan amoMutSquareSpan({
  String tooltip = 'Organisme principal',
  String? url,
}) {
  return squareTagSpan(
    label: 'AMO',
    color: const Color(0xFF1B6B4F), // 🟢 vert foncé mutuelle
    tooltip: tooltip,
    url: url,
  );
}


/// 📘 LPP — badge même taille que les autres squareTagSpan, libellé "LPP" en blanc.
WidgetSpan lppSquareSpan({
  String tooltip = 'Code LPP',
}) {
  return squareTagSpan(
    label: 'LPP',
    color: Colors.orange.shade700,
    tooltip: tooltip,
    // Pas de url : le lien vers la fiche est sur le pill "+ d'infos" (ligne 2).
  );
}

/// 🟢 Mots-clés — badge "outils métier" (vert)
WidgetSpan outilsMetierSpan({
  String tooltip = 'Outils métier',
}) {
  return squareTagSpan(
    label: 'OUTILS MÉTIER',
    color: const Color(0xFF1B6B4F),
    tooltip: tooltip,
  );
}

/// 📋 Codes actes pharmacie — badge "codes actes" (style outils métier, bleu-vert)
WidgetSpan codesActesBadgeSpan({
  String tooltip = 'Codes actes pharmacie',
}) {
  return squareTagSpan(
    label: 'CODES ACTES',
    color: const Color(0xFF0D7377),
    tooltip: tooltip,
  );
}

/// 🌐 Sites web — badge "site internet" (rose #ED1566, texte blanc)
WidgetSpan siteInternetBadgeSpan({
  String tooltip = 'Site internet',
}) {
  return squareTagSpan(
    label: 'site internet',
    color: const Color(0xFFED1566),
    tooltip: tooltip,
  );
}

/// Taille unique des logos injectés (sites web + outils métier) : boîte 50px, image 40px (agrandis pour visibilité).
const double injectedLogoBoxSize = 50;
const double injectedLogoInnerSize = 40;

/// Zoom x1.5 du logo au survol (tooltip) pour le rendre bien visible.
const double logoTooltipZoomScale = 1.5;

/// Wrapper logo + tooltip : au survol, zoom x1.5 du logo et affichage du tooltip.
Widget logoWithTooltipZoom({
  required Widget child,
  required String tooltip,
}) {
  return _LogoTooltipZoom(child: child, tooltip: tooltip);
}

class _LogoTooltipZoom extends StatefulWidget {
  const _LogoTooltipZoom({required this.child, required this.tooltip});

  final Widget child;
  final String tooltip;

  @override
  State<_LogoTooltipZoom> createState() => _LogoTooltipZoomState();
}

class _LogoTooltipZoomState extends State<_LogoTooltipZoom> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: OffiboxTooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: AnimatedScale(
          scale: _hovered ? logoTooltipZoomScale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 🌐 Sites web — pictogramme écran (monitor_www) même taille que les logos outils métier / sites web.
WidgetSpan siteWebPictogramSpan({
  String tooltip = 'Site internet',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: logoWithTooltipZoom(
        tooltip: tooltip,
        child: Container(
          width: injectedLogoBoxSize,
          height: injectedLogoBoxSize,
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
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset(
                'assets/icons/monitor_www.png',
                width: injectedLogoInnerSize,
                height: injectedLogoInnerSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.monitor_outlined,
                  size: injectedLogoInnerSize,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 🟢 Icône + en gras vert (pour mots-clés) — taille doublée (36px)
WidgetSpan keywordPlusIconSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        '+',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
          fontFamily: 'Spinnaker',
        ),
      ),
    ),
  );
}

/// Taille fixe pour les icônes mots-clés en ligne 1 (alignée gelule 20px et badges S/AS).
const double keywordIconBoxWidth = 120;
const double keywordIconBoxHeight = 28;

/// 🟢 Mots-clés — icône + et badge "outils métier" même taille que gelule et S/AS
WidgetSpan keywordPlusAndOutilsMetierSpan({
  String tooltip = 'Outils métier',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: keywordIconBoxHeight,
            child: Center(
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  fontFamily: 'Spinnaker',
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Center(
            child: OffiboxTooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B6B4F),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OUTILS MÉTIER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: 0.3,
                    fontFamily: 'Spinnaker',
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

/// Taille du logo keyword (outils métier) en ligne 1 — même que injectedLogo* pour uniformité avec sites web.
const double keywordLogoBoxSize = injectedLogoBoxSize;
const double keywordLogoInnerSize = injectedLogoInnerSize;

/// Normalise un chemin d'asset (antislashs → slashes) pour le bundle Flutter.
String _normalizeAssetPath(String path) => path.trim().replaceAll(r'\', '/');

/// 🟢 Mots-clés — logo (asset) dans un widget blanc à bords arrondis et légère ombre, taille uniforme avec sites web. Zoom x1.5 au tooltip.
WidgetSpan keywordLogoWrappedSpan({
  required String iconAssetPath,
  String? tooltip,
}) {
  final path = _normalizeAssetPath(iconAssetPath);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: logoWithTooltipZoom(
        tooltip: tooltip ?? 'Outils métier',
        child: Container(
          width: injectedLogoBoxSize,
          height: injectedLogoBoxSize,
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
            child: Image.asset(
              path,
              width: injectedLogoInnerSize,
              height: injectedLogoInnerSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 🟢 Mots-clés — icône personnalisée (ex. BDNM) dans la barre, même emplacement fixe que le bloc +
WidgetSpan keywordCustomIconSpan({required String iconAssetPath}) {
  final path = _normalizeAssetPath(iconAssetPath);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: SizedBox(
      width: keywordIconBoxWidth,
      height: keywordIconBoxHeight,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// 🧪 Catalogues laboratoires — badge LABORATOIRE (mauve #9155A7)
WidgetSpan laboratoireSpan({
  String tooltip = 'Catalogue laboratoire',
}) {
  return squareTagSpan(
    label: 'LABORATOIRE',
    color: const Color(0xFF9155A7),
    tooltip: tooltip,
  );
}

/// 🏷️ CO&PHARM — badge "produit" (bleu lagon, texte blanc)
WidgetSpan produitSpan({
  String tooltip = 'Produit Co&Pharm',
}) {
  return squareTagSpan(
    label: 'produit',
    color: const Color(0xFF00B4D8), // bleu lagon
    tooltip: tooltip,
  );
}

/// 🟪 Annuaire (CRPV — centres régionaux de pharmacovigilance)
WidgetSpan annuaireSquareSpan({
  String tooltip = 'Annuaire',
}) {
  return squareTagSpan(
    label: 'annuaire',
    color: const Color(0xFF351AB7),
    tooltip: tooltip,
  );
}

/// Badge "Signaler un événement sanitaire indésirable" — clic → portail signalement.
WidgetSpan signalerEvenementSanitaireBadgeSpan({
  String tooltip = 'pharmacovigilance, matériovigilance…',
  String url = 'https://signalement.social-sante.gouv.fr/espace-declaration/guidage?profil=PROFESSIONNEL_SANTE',
}) {
  return squareTagSpan(
    label: 'Signaler un événement sanitaire indésirable',
    color: const Color(0xFF351AB7),
    tooltip: tooltip,
    url: url,
  );
}

/// Icône "+ d'infos" CRPV — clic → page ANSM déclaration professionnel de santé.
WidgetSpan crpvPlusInfosIconSpan({
  String tooltip = 'Comment déclarer un effet indésirable (ANSM)',
  String url = 'https://ansm.sante.fr/documents/reference/declarer-un-effet-indesirable/comment-declarer-si-vous-etes-professionnel-de-sante',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OffiboxTooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => openUrl(url),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF351AB7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF351AB7)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF351AB7)),
                SizedBox(width: 4),
                Text(
                  '+ d\'infos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF351AB7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}






InlineSpan amcVitaleIconSpan({
  double size = 18,
  String tooltip = 'Tiers payant',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OffiboxTooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: SvgPicture.asset(
          'assets/icons/carte_vitale.svg',
          width: size,
          height: size,
        ),
      ),
    ),
  );
}

