import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';

/// Date de version au format JJ/MM/AAAA (à mettre à jour à chaque release / build).
const String kVersionDate = '20/02/2026';

/// Familles affichées dans l'ordre (label, source).
const List<({String label, SourceType source})> _aboutFamilies = [
  (label: 'Médicaments (BDM)', source: SourceType.bdm),
  (label: 'Dispositifs médicaux', source: SourceType.dm),
  (label: 'Médicaments vétérinaires', source: SourceType.veto),
  (label: 'codes LPP', source: SourceType.lpp),
  (label: 'Régimes obligatoires (AMO)', source: SourceType.amo),
  (label: 'Mutuelles (AMC)', source: SourceType.amc),
  (label: 'Annuaire', source: SourceType.pharmacovigilance),
  (label: 'Mots-clés', source: SourceType.keyword),
  (label: 'Sites web', source: SourceType.siteWeb),
  (label: 'Catalogues laboratoires', source: SourceType.catalogue),
];

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
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                versionDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Produits indexés par famille',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
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
                                color: theme.colorScheme.onSurface,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
