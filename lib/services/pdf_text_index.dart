import 'dart:convert';
import 'dart:io';

import 'package:offibox/services/pdf_cache.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// Index texte des PDF catalogues : une fois le PDF en cache, on extrait le texte
/// par page et on le stocke en JSON. La recherche de libellés se fait sur cet index
/// (sans rouvrir le PDF), et l'affichage peut être délégué au navigateur.
class PdfTextIndexService {
  /// Retourne le chemin du fichier d'index pour un PDF déjà en cache.
  static String _indexPathFor(File pdfFile) => '${pdfFile.path}.json';

  /// Charge ou construit l'index texte du PDF (url + lab pour cache).
  /// Retourne une map pageNumber -> texte de la page (1-based).
  static Future<Map<int, String>> getIndex({
    required String pdfUrl,
    required String laboratory,
  }) async {
    final file = await PdfCacheService.getCachedPdf(
      pdfUrl: pdfUrl,
      laboratory: laboratory,
      allowLarge: true,
    );
    final indexFile = File(_indexPathFor(file));
    if (indexFile.existsSync()) {
      return _readIndex(indexFile);
    }
    return _buildAndSaveIndex(file, indexFile);
  }

  static Map<int, String> _readIndex(File indexFile) {
    final content = indexFile.readAsStringSync();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final pages = decoded['pages'] as List<dynamic>? ?? [];
    final out = <int, String>{};
    for (final p in pages) {
      final m = p as Map<String, dynamic>;
      final pageNum = (m['p'] as num?)?.toInt();
      final text = m['t'] as String? ?? '';
      if (pageNum != null) out[pageNum] = text;
    }
    return out;
  }

  static Future<Map<int, String>> _buildAndSaveIndex(File pdfFile, File indexFile) async {
    final bytes = await pdfFile.readAsBytes();
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(bytes);
      final list = <Map<String, dynamic>>[];
      for (final page in document.pages) {
        await page.ensureLoaded();
        final raw = await page.loadText();
        final text = raw?.fullText ?? '';
        list.add({'p': page.pageNumber, 't': text});
      }
      await document.dispose();
      final map = {for (final e in list) (e['p'] as int): e['t'] as String};
      await indexFile.writeAsString(
        jsonEncode({'pages': list}),
        flush: true,
      );
      return map;
    } catch (_) {
      await document?.dispose();
      rethrow;
    }
  }

  /// Indique si un index existe déjà pour ce PDF (sans le construire).
  static Future<bool> hasIndex({
    required String pdfUrl,
    required String laboratory,
  }) async {
    try {
      final file = await PdfCacheService.getCachedPdf(
        pdfUrl: pdfUrl,
        laboratory: laboratory,
        allowLarge: true,
      );
      return File(_indexPathFor(file)).existsSync();
    } catch (_) {
      return false;
    }
  }
}
