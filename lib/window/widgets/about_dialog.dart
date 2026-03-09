import 'package:flutter/material.dart';
import 'package:offibox/generated/annuaire_ps_count.dart';
import 'package:offibox/generated/build_info.dart';
import 'package:offibox/models/search_result.dart';

export 'package:offibox/generated/build_info.dart' show kVersionDate;
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/open_url.dart';

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

/// Familles affichées dans l'ordre (label, source).
/// Une seule ligne « Annuaire » (pharmacovigilance + RPPS). Centres anti poison et CHU exclus. AMO = Organismes obligatoires (ex‑GIE Sésame Vitale).
const List<({String label, SourceType? source})> _aboutFamilies = [
  (label: 'Médicaments (BDM)', source: SourceType.bdm),
  (label: 'Dispositifs médicaux', source: SourceType.dm),
  (label: 'Médicaments vétérinaires', source: SourceType.veto),
  (label: 'codes LPP', source: SourceType.lpp),
  (label: 'Mutuelles (AMC)', source: SourceType.amc),
  (label: 'Organismes obligatoires (AMO)', source: SourceType.amo),
  (label: 'Mots-clés', source: SourceType.keyword),
  (label: 'Sites web', source: SourceType.siteWeb),
  (label: 'Catalogues laboratoires', source: SourceType.catalogue),
];

/// Nombre de codes actes (référentiel Pharmaprat, fichier data/codes_actes_pharmacie.csv).
const int kCodesActesCount = 77;

bool _isPdfUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final path = url.split(RegExp(r'[?#]')).first.trim().toLowerCase();
  return path.endsWith('.pdf');
}

/// Nombre de résultats dont l’URL (ou catalogueUrl) pointe vers un PDF.
/// True si le résultat a au moins un lien PDF (url, catalogueUrl, meddispar, badges, rcpVeto) ou isPdf.
bool _resultHasPdf(SearchResult r) {
  if (r.isPdf == true) return true;
  if (_isPdfUrl(r.url)) return true;
  if (_isPdfUrl(r.catalogueUrl)) return true;
  if (_isPdfUrl(r.meddisparUrl)) return true;
  if (_isPdfUrl(r.rcpVetoUrl)) return true;
  if (_isPdfUrl(r.badge1Url)) return true;
  if (_isPdfUrl(r.badge2Url)) return true;
  if (_isPdfUrl(r.badge3Url)) return true;
  if (_isPdfUrl(r.badge4Url)) return true;
  return false;
}

int countPdfUrls(List<SearchResult> allResults) {
  return allResults.where(_resultHasPdf).length;
}

int countPdfDocuments(List<SearchResult> allResults) {
  return allResults.where((r) => r.isPdf == true).length;
}

/// Compte les résultats par famille pour l'À propos. Un seul passage sur [allResults] pour limiter le coût.
List<({String label, int count, String? countDisplay})> countByFamilyForAbout(List<SearchResult> allResults) {
  final counts = <SourceType, int>{};
  int pdfCount = 0;
  for (final r in allResults) {
    counts[r.source] = (counts[r.source] ?? 0) + 1;
    if (_resultHasPdf(r)) pdfCount++;
  }
  final fromSources = _aboutFamilies
      .where((e) => e.source != null)
      .map((e) => (
            label: e.label,
            count: counts[e.source] ?? 0,
            countDisplay: null,
          ),)
      .toList();
  return [
    ...fromSources,
    (label: 'Annuaire PS', count: kAnnuairePsTotalHorsAppli, countDisplay: null),
    (label: 'Codes actes', count: kCodesActesCount, countDisplay: null),
    (label: 'PDF', count: pdfCount, countDisplay: null),
  ];
}

/// Dialogue À propos : logo à gauche, version + date, liste des produits indexés par famille.
/// Pour « Annuaire PS », le total est récupéré via l’API data.gouv.fr). Pas d'appel API à l'ouverture.
class OffiboxAboutDialog extends StatelessWidget {
  const OffiboxAboutDialog({
    super.key,
    required this.version,
    required this.versionDate,
    required this.countsByFamily,
  });

  final String version;
  final String versionDate;
  final List<({String label, int count, String? countDisplay})> countsByFamily;

  static const Color _labelColor = Color(0xFF1A1A1A);
  static const double _rowFontSize = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countsByFamily = this.countsByFamily;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                  color: _labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                versionDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: _rowFontSize - 1,
                  color: _labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
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
                    color: _labelColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Produits indexés par famille',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _labelColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                ...countsByFamily.map((e) {
                  final displayCount = e.countDisplay ?? '${e.count}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            e.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: _rowFontSize,
                              fontWeight: FontWeight.w500,
                              color: _labelColor,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          displayCount,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: _rowFontSize,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
