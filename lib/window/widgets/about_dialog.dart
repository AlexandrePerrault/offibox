import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/open_url.dart';

/// Date de version au format JJ/MM/AAAA (à mettre à jour à chaque release / build).
const String kVersionDate = '27/02/2026';

/// URL officielle de la base de données publique des médicaments.
const String kBdpmBaseUrl = 'http://base-donnees-publique.medicaments.gouv.fr';

/// Texte des mentions légales / termes du contrat de licence (données BDPM).
String getMentionsLegalesBdpmText() => '''
Termes du contrat de licence — Données BDPM

Conformément à l'article L. 161-40-1 du code de la sécurité sociale dans sa rédaction issue de l'article 8 de la loi n° 2011-2012 du 29/12/2011, l'information contenue dans la base de données publique des médicaments (BDPM) est mise à disposition des usagers au moyen des fichiers offerts au téléchargement libre et gratuit.

Vous êtes libres de :
• Reproduire, diffuser, redistribuer et exploiter les données

À condition de :
• Ne pas altérer les données, ne pas en dénaturer leur sens, mentionner impérativement la source de ces données (base de données publique des médicaments — $kBdpmBaseUrl) et la date de leur mise à jour (Article 12 de la loi n°78-753 du 17 juillet 1978 - loi CADA). Toutefois, il est rappelé que cette mention ne confère aucun caractère officiel à la réutilisation de ces données, et ne doit pas suggérer une quelconque reconnaissance ou caution du "Réutilisateur" par l'ANSM, la HAS ou l'UNCAM.

• De vous assurer de la mise à jour des données téléchargées non seulement par rapport à chaque mise à jour périodique de la BDPM, mais aussi et surtout par rapport à des modifications qui ont pu intervenir, entre deux mises à jour périodiques de la BDPM, sur les informations concernant un ou plusieurs médicaments. La responsabilité de l'ANSM, de la HAS et de la CNAMTS ne saurait être engagée en cas de mise à disposition d'informations n'ayant pas bénéficié de toutes les mises à jour à la date de leur utilisation que ce soit en simple consultation ou en intégration dans un système d'information.

En téléchargeant les données mises à disposition sur ce site, vous acceptez les conditions mentionnées ci-dessus et le texte complet de la licence ouverte (PDF, 528 Ko).

Format de données et lien entre les différents fichiers :
Le lien suivant vous permet d'accéder à un fichier décrivant le contenu, le format et les liens existants entre les fichiers mis à disposition : $kBdpmBaseUrl
''';

/// Familles affichées dans l'ordre (label, source). Dernière ligne = GIE sesame vitale (AMO).
const List<({String label, SourceType source})> _aboutFamilies = [
  (label: 'Médicaments (BDM)', source: SourceType.bdm),
  (label: 'Dispositifs médicaux', source: SourceType.dm),
  (label: 'Médicaments vétérinaires', source: SourceType.veto),
  (label: 'codes LPP', source: SourceType.lpp),
  (label: 'Mutuelles (AMC)', source: SourceType.amc),
  (label: 'Annuaire', source: SourceType.pharmacovigilance),
  (label: 'Centres anti poison', source: SourceType.centresAntiPoison),
  (label: 'CHU', source: SourceType.chu),
  (label: 'Mots-clés', source: SourceType.keyword),
  (label: 'Sites web', source: SourceType.siteWeb),
  (label: 'Catalogues laboratoires', source: SourceType.catalogue),
  (label: 'GIE sesame vitale', source: SourceType.amo),
];

/// Nombre de codes actes (référentiel Pharmaprat, fichier data/codes_actes_pharmacie.csv).
const int kCodesActesCount = 77;

bool _isPdfUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.pdf');
}

/// Nombre de résultats dont l’URL (ou catalogueUrl) pointe vers un PDF.
int countPdfDocumentUrls(List<SearchResult> allResults) {
  return allResults
      .where((r) =>
          r.isPdf == true ||
          _isPdfUrl(r.url) ||
          _isPdfUrl(r.catalogueUrl))
      .length;
}

/// Compte les résultats par famille pour l'À propos.
List<({String label, int count})> countByFamilyForAbout(List<SearchResult> allResults) {
  final fromSources = _aboutFamilies
      .map((e) => (
            label: e.label,
            count: allResults.where((r) => r.source == e.source).length,
          ),)
      .toList();
  final pdfCount = countPdfDocumentUrls(allResults);
  return [
    ...fromSources,
    (label: 'Codes actes', count: kCodesActesCount),
    (label: 'Documents PDF', count: pdfCount),
  ];
}

/// Dialogue À propos : logo à gauche, version + date, liste des produits indexés par famille.
class OffiboxAboutDialog extends StatelessWidget {
  const OffiboxAboutDialog({
    super.key,
    required this.version,
    required this.versionDate,
    required this.countsByFamily,
  });

  final String version;
  final String versionDate;
  final List<({String label, int count})> countsByFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Couleur texte pleine opacité pour éviter un rendu pâle selon le thème
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 1.0);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + version + date à gauche
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/logo_offibox.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.medication, size: 72, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                version,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                versionDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Titre + liste des familles à droite
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Produits indexés par famille',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                ...countsByFamily.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              e.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${e.count}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _showMentionsLegalesDialog(context),
          child: const Text('Mentions légales'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Ouvre le dialogue « Termes du contrat de licence » (données BDPM).
void _showMentionsLegalesDialog(BuildContext context) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mentions légales — Termes du contrat de licence'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      content: SizedBox(
        width: 520,
        height: 420,
        child: SingleChildScrollView(
          child: SelectableText(
            getMentionsLegalesBdpmText(),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            openUrl(kBdpmBaseUrl);
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Ouvrir la base BDPM'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}
