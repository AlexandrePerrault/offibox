import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/search/result_action_registry.dart';
import 'package:offibox/ui/results/result_line_1.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/constants/ui_constants.dart';

/// Taille d'affichage pour les logos "Source :". Véto/LPP = 52 ; e-pansement = 52 * 1.5 (plus lisible).
const double _sourceLogoSize = 52;
const double _sourceLogoSizeDm = 52;
const double _sourceLogoSizeDmEpansement = 52 * 1.5; // 78
const String _externalLinkAsset = 'assets/icons/link-external.svg';
const String _dmSourceTooltip = 'Fiche produit';

/// URL et libellé pour la ligne "Sources :" des médicaments BDM (texte : Base de Données Publique des Médicaments, ANSM).
const String _bdmSourceUrl = 'https://base-donnees-publique.medicaments.gouv.fr/';
const String _bdmSourceLabel = 'Base de Données Publique des Médicaments, ANSM';
const String _bdmSourceTooltip = 'Base de données publique des médicaments';
const String _vetoSourceUrl = 'https://www.anses.fr/fr/content/lagence-nationale-du-medicament-veterinaire-missions-et-actions';
const String _vetoSourceAsset = 'assets/icons/anses-small.svg';
const String _dmSourceUrl = 'https://www.e-pansement.fr/';
const String _dmSourceAsset = 'assets/icons/e_pansement.png';
const String _lppSourceUrl = 'http://www.codage.ext.cnamts.fr/codif/tips/index.php?p_site=AMELI';
const String _lppSourceAsset = 'assets/icons/entete_ameli_gdr.gif';

class ResultLine3Actions extends StatelessWidget {
  final SearchResult item;
  /// CIS présents dans génériques 2026 : RCP et MEDDISPAR sont affichés en ligne 2, pas ici.
  final Set<String>? generiques2026CisSet;
  /// Quand true (résultat injecté dans la barre), affiche "Source :" + logo en italique (police plus petite).
  final bool isInjected;
  /// Ouverture de l'URL source au clic sur "Source :" / logo (si null, utilise openUrl).
  final void Function(String url)? onOpenUrl;
  /// URL fiche VOC patient (OMÉDIT) — pill "fiche à destination des patients" en ligne 3 si BDM.
  final String? vocPatientUrl;
  /// URL fiche VOC pro (OMÉDIT) — pill "fiche à destination des professionnels de santé" en ligne 3 si BDM.
  final String? vocProUrl;
  /// CIP13 → URL vidéo (videos.csv). Pill "vidéo de démonstration" en ligne 3 après RCP/MEDDISPAR si BDM.
  final Map<String, String>? videosByCip13;
  /// Clic sur le pill vidéo → ouvre le panneau vidéo thérapeutique.
  final void Function(String url)? onOpenTherapeuticVideo;

  const ResultLine3Actions({
    super.key,
    required this.item,
    this.generiques2026CisSet,
    this.isInjected = false,
    this.onOpenUrl,
    this.vocPatientUrl,
    this.vocProUrl,
    this.videosByCip13,
    this.onOpenTherapeuticVideo,
  });

  @override
Widget build(BuildContext context) {
  // Mots-clés / Sites web : rien en ligne 3 (libellé déjà en ligne 1, badges en ligne 2)
  if (item.source == SourceType.keyword || item.source == SourceType.siteWeb) {
    return const SizedBox.shrink();
  }
  // LPP : tout en ligne 2 (+ d'infos + Source logo) — pas de ligne 3
  if (item.source == SourceType.lpp) {
    return const SizedBox.shrink();
  }

  final cisKey = item.cis?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  // Masquer RCP/MEDDISPAR en ligne 3 uniquement pour les princeps génériques 2026 (affichés en ligne 2). Les biosimilaires gardent le hover pill MEDDISPAR.
  final hideRcpMeddispar = generiques2026CisSet != null && cisKey.isNotEmpty && generiques2026CisSet!.contains(cisKey);

  final actions = line3Actions
      .where((action) {
        if (!action.isVisible(item)) return false;
        if (hideRcpMeddispar && (action.label == 'RCP' || action.label == 'Fiche MEDDISPAR')) return false;
        return true;
      })
      .toList(growable: false);

  final hasCommentaire =
      item.commentaire != null && item.commentaire!.trim().isNotEmpty;
  // Ne pas afficher le bloc commentaire pour les mots-clés / sites web (déjà en ligne 1)
  final showCommentaire = hasCommentaire && item.source != SourceType.keyword && item.source != SourceType.siteWeb;

  // Source : + logo. BDM/véto = dans le Wrap ; LPP/DM (pansements) injectés = une ligne "Source :" + logo sous les résultats (comme médicaments).
  final bool isDm = item.source == SourceType.dm;
  final bool isVeto = item.source == SourceType.veto;
  final sourceRow = (item.source == SourceType.bdm || isVeto)
      ? null
      : _buildSourceRowWhenInjected();
  final Widget? _vetoSourceWidget = isVeto
      ? ResultLine3Actions.buildSourceRow(item, true, onOpenUrl)
      : null;
  final dmSourceNextToFiche = null; // Pansements : source affichée en ligne via sourceRow (e_pansement.png)
  final openUrlFn = onOpenUrl ?? openUrl;
  final bool useAnsmLogoForBdm = item.source == SourceType.bdm &&
      (generiques2026CisSet != null && cisKey.isNotEmpty && generiques2026CisSet!.contains(cisKey) ||
          item.isGeneric == true);
  final bool hasVocFiches = item.source == SourceType.bdm &&
      (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty || vocProUrl != null && vocProUrl!.trim().isNotEmpty);
  final Widget? _bdmSourceWidget = (item.source == SourceType.bdm)
      ? (useAnsmLogoForBdm
          ? ResultLine3Actions.buildBdmSourceRowWithAnsmLogo(onOpenUrl)
          : ResultLine3Actions.buildBdmSourceRow(onOpenUrl, showOmeditLogo: hasVocFiches))
      : null;
  final vocPills = <Widget>[];
  if (item.source == SourceType.bdm &&
      (vocPatientUrl != null && vocPatientUrl!.isNotEmpty || vocProUrl != null && vocProUrl!.isNotEmpty)) {
    const String _pdfRedLogoAsset = 'assets/icons/pdf_red.svg';
    if (vocPatientUrl != null && vocPatientUrl!.trim().isNotEmpty) {
      final url = vocPatientUrl!.trim();
      vocPills.add(
        HoverPillButton(
          label: 'fiche à destination des patients',
          icon: Icons.person_outline,
          tooltip: url,
          onTap: () => openUrlFn(url),
          maxLabelWidth: 380,
          trailingWidget: SvgPicture.asset(
            _pdfRedLogoAsset,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    if (vocProUrl != null && vocProUrl!.trim().isNotEmpty) {
      final url = vocProUrl!.trim();
      if (vocPills.isNotEmpty) vocPills.add(const SizedBox(width: 6));
      vocPills.add(
        HoverPillButton(
          label: 'fiche à destination des professionnels de santé',
          icon: Icons.medical_services_outlined,
          tooltip: url,
          onTap: () => openUrlFn(url),
          maxLabelWidth: 380,
          trailingWidget: SvgPicture.asset(
            _pdfRedLogoAsset,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }

  final cip13Key = item.cip13?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  final therapeuticVideoUrl = (item.source == SourceType.bdm &&
          videosByCip13 != null &&
          cip13Key.isNotEmpty &&
          onOpenTherapeuticVideo != null)
      ? videosByCip13![cip13Key]?.trim()
      : null;
  final bool hasVideoPill =
      therapeuticVideoUrl != null && therapeuticVideoUrl.isNotEmpty;

  // Ligne « biosimilaires » (répertoire + bonnes pratiques) en dessous des RCP / MEDDISPAR,
  // uniquement pour les médicaments princeps / génériques / biosimilaires / bioréférents.
  final bool isBdm = item.source == SourceType.bdm;
  final bool hasBiosimRelation = item.biosimilaireOf != null &&
      item.biosimilaireOf!.trim().isNotEmpty;
  final bool hasGenericRelation = item.isGeneric == true ||
      (item.princepsName != null && item.princepsName!.trim().isNotEmpty) ||
      (item.genericName != null && item.genericName!.trim().isNotEmpty) ||
      item.isBioreferent == true;
  final bool showBiosimLine = isBdm && (hasBiosimRelation || hasGenericRelation);

  if (actions.isEmpty &&
      !showCommentaire &&
      sourceRow == null &&
      dmSourceNextToFiche == null &&
      vocPills.isEmpty &&
      _bdmSourceWidget == null &&
      _vetoSourceWidget == null &&
      !hasVideoPill) {
    return const SizedBox.shrink();
  }

  final actionWidgets = actions.map<Widget>((action) {
    final onTap = action.onTap(item);
    final bool isRcpVeto =
        action.label == 'RCP VÉTO' && item.source == SourceType.veto;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoverPillButton(
          label: action.label,
          icon: action.icon,
          tooltip: action.tooltip,
          onTap: onTap,
          // Produits vétérinaires : badge external link à l'intérieur du HoverPillButton RCP VÉTO (couleur Offibox).
          trailingWidget: isRcpVeto
              ? SvgPicture.asset(
                  _externalLinkAsset,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(OffiboxColors.primary, BlendMode.srcIn),
                )
              : null,
        ),
        if (action.label == 'Mail' &&
            item.email != null &&
            item.email!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: offiboxCopyWidget(
              context: context,
              code: item.email!,
              tooltip: 'Copier le mail',
            ),
          ),
      ],
    );
  }).toList(growable: false);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (vocPills.isNotEmpty ||
          actionWidgets.isNotEmpty ||
          dmSourceNextToFiche != null ||
          _bdmSourceWidget != null ||
          _vetoSourceWidget != null ||
          hasVideoPill)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...actionWidgets,
            if (hasVideoPill) ...[
              if (actionWidgets.isNotEmpty) const SizedBox(width: 6),
              HoverPillButton(
                label: 'vidéo de démonstration',
                icon: Icons.video_library_outlined,
                tooltip:
                    "Outils d'aide à l'utilisation des thérapeutiques inhalées dans l'asthme et la BPCO chez l'adulte",
                onTap: () =>
                    onOpenTherapeuticVideo!(therapeuticVideoUrl!),
              ),
            ],
            if ((vocPills.isNotEmpty || dmSourceNextToFiche != null || _bdmSourceWidget != null || _vetoSourceWidget != null) &&
                (actionWidgets.isNotEmpty || hasVideoPill))
              const SizedBox(width: 6),
            ...vocPills,
            if (dmSourceNextToFiche != null) ...[
              if (vocPills.isNotEmpty || actionWidgets.isNotEmpty) const SizedBox(width: 6),
              dmSourceNextToFiche,
            ],
            // Source : après les badges (BDM = Base de Données + logo ; véto = ANSES).
            if (_bdmSourceWidget != null) ...[
              if (actionWidgets.isNotEmpty || vocPills.isNotEmpty || dmSourceNextToFiche != null) const SizedBox(width: 6),
              _bdmSourceWidget!,
            ],
            if (_vetoSourceWidget != null) ...[
              if (actionWidgets.isNotEmpty || vocPills.isNotEmpty || dmSourceNextToFiche != null || _bdmSourceWidget != null) const SizedBox(width: 6),
              _vetoSourceWidget!,
            ],
          ],
        ),

      // Ligne 4 : liens biosimilaires (ANSM) et bonnes pratiques de substitution (OMEDIT)
      if (showBiosimLine) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HoverPillButton(
              label: 'répertoire biosimilaires',
              icon: Icons.science_outlined,
              tooltip:
                  'Répertoire des médicaments biosimilaires (ANSM, à jour au 13/02/2026)',
              onTap: () => openUrlFn(
                'https://ansm.sante.fr/documents/reference/medicaments-biosimilaires',
              ),
            ),
            HoverPillButton(
              label: 'BONNES PRATIQUES DE SUBSTITUTION des biosimilaires',
              icon: Icons.article_outlined,
              tooltip: 'OMEDIT Île-de-France – bonnes pratiques de substitution (©)',
              onTap: () => openUrlFn(
                'https://www.omedit-idf.fr/wp-content/uploads/Bonnes-pratiques-de-substitution-des-biosimilaires-en-officine-06022026bis.pdf',
              ),
              maxLabelWidth: 360,
            ),
          ],
        ),
      ],

      // ⚠️ COMMENTAIRE COLONNE H (masqué pour mots-clés : déjà affiché en ligne 1)
      if (showCommentaire) ...[
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.commentaire!,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Spinnaker',
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],

      // Source : + logo (italique, police plus petite) quand le résultat est injecté (BDM / véto / LPP).
      if (sourceRow != null) ...[
        if (actions.isNotEmpty || showCommentaire) const SizedBox(height: 6),
        sourceRow,
      ],
    ],
  );
  }

  /// Retourne la ligne "Source :" + logo pour BDM, véto ou LPP en mode injecté, sinon null.
  Widget? _buildSourceRowWhenInjected() {
    return buildSourceRow(item, isInjected, onOpenUrl);
  }

  /// Widget "Source(s) :" + logo ou texte pour affichage en ligne 2/3. BDM = texte ; véto/LPP = logo ; DM = logo ×1,5 + icône external link (tooltip "Fiche produit").
  /// [logoSizeOverride] : taille personnalisée pour certains logos (ex. DM historique).
  static Widget? buildSourceRow(SearchResult item, bool isInjected, void Function(String url)? onOpenUrl, {double? logoSizeOverride}) {
    if (!isInjected) return null;
    switch (item.source) {
      case SourceType.bdm:
        return _buildSourceRowWithText(
          url: _bdmSourceUrl,
          label: _bdmSourceLabel,
          onOpenUrl: onOpenUrl,
          tooltip: _bdmSourceTooltip,
          prefix: 'Sources : ',
        );
      case SourceType.veto:
        return _buildSourceRowWithAsset(
          url: _vetoSourceUrl,
          asset: _vetoSourceAsset,
          onOpenUrl: onOpenUrl,
          tooltip: null,
        );
      case SourceType.dm:
        return _buildDmSourceRowWithExternalLink(item, onOpenUrl);
      case SourceType.lpp:
        return _buildSourceRowWithAsset(
          url: _lppSourceUrl,
          asset: _lppSourceAsset,
          onOpenUrl: onOpenUrl,
          tooltip: null,
          logoSize: _sourceLogoSize,
          preserveAspectRatio: true,
        );
      default:
        return null;
    }
  }

  /// Ligne "Sources : Base de Données Publique des Médicaments, ANSM" pour les médicaments.
  /// Si [showOmeditLogo] est true (produit avec fiche(s) VOC), affiche en plus le logo OMÉDIT.
  static Widget buildBdmSourceRow(void Function(String url)? onOpenUrl, {bool showOmeditLogo = false}) {
    const double logoSize = _sourceLogoSize;
    const String omeditAsset = 'assets/icons/omedit.png';
    final textRow = _buildSourceRowWithText(
      url: _bdmSourceUrl,
      label: _bdmSourceLabel,
      onOpenUrl: onOpenUrl,
      tooltip: _bdmSourceTooltip,
      prefix: 'Sources : ',
    );
    if (!showOmeditLogo) return textRow;
    const TextStyle commaStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'Spinnaker',
      fontStyle: FontStyle.italic,
      color: Colors.black54,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        textRow,
        Text(', ', style: commaStyle),
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            omeditAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: logoSize, height: logoSize),
          ),
        ),
      ],
    );
  }

  /// Variante historique « BDM + ANSM » : désormais même texte que [buildBdmSourceRow] (Sources : Base de Données Publique des Médicaments, ANSM).
  static Widget buildBdmSourceRowWithAnsmLogo(void Function(String url)? onOpenUrl) {
    return _buildSourceRowWithText(
      url: _bdmSourceUrl,
      label: _bdmSourceLabel,
      onOpenUrl: onOpenUrl,
      tooltip: _bdmSourceTooltip,
      prefix: 'Sources : ',
    );
  }

  static Widget _buildSourceRowWithText({
    required String url,
    required String label,
    required void Function(String url)? onOpenUrl,
    String? tooltip,
    String prefix = 'Source : ',
  }) {
    const double fontSize = 11;
    final openUrlFn = onOpenUrl ?? openUrl;
    return Tooltip(
      message: tooltip ?? url,
      child: InkWell(
        onTap: () => openUrlFn(url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prefix,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Spinnaker',
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Spinnaker',
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// DM (pansements) : "Source :" + logo e-pansement (×1,5) avec tooltip "Fiche produit" + icône external link (couleur Offibox).
  static Widget _buildDmSourceRowWithExternalLink(SearchResult item, void Function(String url)? onOpenUrl) {
    const double fontSize = 11;
    final openUrlFn = onOpenUrl ?? openUrl;
    final ficheUrl = item.url?.trim().isNotEmpty == true ? item.url! : _dmSourceUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Source : ',
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'Spinnaker',
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
          Tooltip(
            message: _dmSourceTooltip,
            child: InkWell(
              onTap: () => openUrlFn(ficheUrl),
              borderRadius: BorderRadius.circular(4),
              child: _sourceLogo(_dmSourceAsset, _sourceLogoSizeDmEpansement),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: _dmSourceTooltip,
            child: InkWell(
              onTap: () => openUrlFn(ficheUrl),
              borderRadius: BorderRadius.circular(4),
              child: SvgPicture.asset(
                _externalLinkAsset,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(OffiboxColors.primary, BlendMode.srcIn),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSourceRowWithAsset({
    required String url,
    required String asset,
    required void Function(String url)? onOpenUrl,
    String? tooltip,
    double? logoSize,
    bool preserveAspectRatio = false,
  }) {
    final size = logoSize ?? _sourceLogoSize;
    const double fontSize = 11;
    final openUrlFn = onOpenUrl ?? openUrl;
    return Tooltip(
      message: tooltip ?? url,
      child: InkWell(
        onTap: () => openUrlFn(url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Source : ',
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Spinnaker',
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              preserveAspectRatio ? _sourceLogoFull(asset, size) : _sourceLogo(asset, size),
            ],
          ),
        ),
      ),
    );
  }

  /// Logo source en proportions réelles (carré, rectangle, etc.) — hauteur fixe, largeur selon ratio.
  static Widget _sourceLogoFull(String assetPath, double height) {
    final path = assetPath.toLowerCase();
    final Widget raw = path.endsWith('.svg')
        ? SizedBox(
            height: height,
            child: SvgPicture.asset(
              assetPath,
              height: height,
              fit: BoxFit.contain,
            ),
          )
        : SizedBox(
            height: height,
            child: Image.asset(
              assetPath,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  SizedBox(height: height, width: height),
            ),
          );
    // Encapsule le logo dans un badge aux bords arrondis (cohérent avec le reste du site).
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 4),
      child: raw,
    );
  }

  /// Même taille visuelle pour tous les logos Source (BDM, véto ANSES, e-pansement, LPP).
  /// SVG et e-pansement en contain pour ne pas dépasser ; autres JPEG en cover.
  static Widget _sourceLogo(String assetPath, double size) {
    final path = assetPath.toLowerCase();
    final box = SizedBox(width: size, height: size);
    final Widget raw = path.endsWith('.svg')
        ? SizedBox(
            width: size,
            height: size,
            child: SvgPicture.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          )
        : SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              // e-pansement : contain comme le logo ANSES pour même taille visuelle
              fit: path.contains('e_pansement') ? BoxFit.contain : BoxFit.cover,
              errorBuilder: (_, __, ___) => box,
            ),
          );
    // Encapsule le logo dans un badge aux bords arrondis (cohérent avec le reste du site).
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: raw,
    );
  }
}
