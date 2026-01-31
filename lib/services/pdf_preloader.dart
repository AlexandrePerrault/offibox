import 'dart:async';
import '../models/search_result.dart';
import 'pdf_cache.dart';

class PdfPreloader {
  static Future<void> preloadCatalogues(
    List<SearchResult> results,
  ) async {
    // 🧠 on ne prend que les PDF catalogues
    final pdfItems = results
        .where((r) =>
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'))
        .toList();

    // ⛔ rien à faire
    if (pdfItems.isEmpty) return;

    // ⚖️ limite : 1 PDF à la fois
    for (final item in pdfItems) {
      try {
        await PdfCacheService.getCachedPdf(
          pdfUrl: item.catalogueUrl!,
          supplier: item.labelRaw.toLowerCase(),
        );

        // 🧘‍♂️ petite pause pour ne pas saturer
        await Future.delayed(
          const Duration(milliseconds: 400),
        );
      } catch (_) {
        // ❌ on ignore les erreurs, pas bloquant
      }
    }
  }
}
