import 'dart:async';
import '../models/search_result.dart';
import 'pdf_cache.dart';

class PdfPreloader {
  /// Nombre max de PDF à précharger (évite de télécharger des dizaines de catalogues).
  static const int maxPreload = 2;

  /// Délai avant de démarrer le préchargement (laisse l'UI répondre après la recherche).
  static const Duration delayBeforeStart = Duration(milliseconds: 1500);

  /// Précharge en arrière-plan au plus [maxPreload] PDF des catalogues (même cache que le viewer).
  /// Déduplique par URL. Démarre après [delayBeforeStart] pour ne pas ralentir l'affichage des résultats.
  static Future<void> preloadCatalogues(
    List<SearchResult> results,
  ) async {
    final pdfItems = results
        .where((r) =>
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'),)
        .toList();
    if (pdfItems.isEmpty) return;

    await Future<void>.delayed(delayBeforeStart);

    final seen = <String>{};
    int preloaded = 0;
    for (final item in pdfItems) {
      if (preloaded >= maxPreload) break;
      final url = item.catalogueUrl!;
      if (seen.contains(url)) continue;
      seen.add(url);

      try {
        await PdfCacheService.getCachedPdf(
          pdfUrl: url,
          laboratory: item.label,
          allowLarge: true,
        );
        preloaded++;
        if (preloaded < maxPreload) {
          await Future<void>.delayed(
            const Duration(milliseconds: 200),
          );
        }
      } catch (_) {
        // ignore erreurs, pas bloquant
      }
    }
  }
}
