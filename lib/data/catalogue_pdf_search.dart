import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/pdf_text_index.dart';

/// Recherche d'un terme (nom, code CIP13, EAN, GTIN) dans les PDF des catalogues (col. G).
/// Utilise l'index texte (JSON par PDF) au lieu d'ouvrir le PDF à chaque fois.
/// L'affichage des PDF se fait via ouverture dans le navigateur (voir onOpenCataloguePdf).
class CataloguePdfSearch {
  /// Cherche [query] dans l'index texte du PDF. Retourne true si trouvé (insensible à la casse).
  static Future<bool> _searchInIndex(
    String pdfUrl,
    String laboratory,
    String query,
  ) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    try {
      final index = await PdfTextIndexService.getIndex(
        pdfUrl: pdfUrl,
        laboratory: laboratory,
      );
      for (final text in index.values) {
        if (text.toLowerCase().contains(q)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Pour chaque catalogue PDF, cherche [query] dans l'index texte.
  /// Retourne la liste des SearchResult au format "query - trouvé dans le catalogue LabName".
  static Future<List<SearchResult>> searchInCatalogues(
    String query,
    List<SearchResult> catalogueItems,
  ) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final pdfItems = catalogueItems.where((r) =>
        r.source == SourceType.catalogue &&
        r.catalogueUrl != null &&
        r.catalogueUrl!.trim().isNotEmpty &&
        r.catalogueUrl!.toLowerCase().endsWith('.pdf'),).toList();
    if (pdfItems.isEmpty) return [];
    final hits = <SearchResult>[];
    for (final item in pdfItems) {
      try {
        final found = await _searchInIndex(
          item.catalogueUrl!,
          item.label,
          q,
        );
        if (found) {
          final label = '$q - trouvé dans le catalogue ${item.label}';
          hits.add(item.copyWith(
            label: label,
            labelRaw: label,
          ),);
        }
      } catch (_) {
        // Ignore erreur (réseau, PDF invalide, index, etc.)
      }
    }
    return hits;
  }
}
