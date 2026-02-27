import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Cache PDF des catalogues (partagé viewer / recherche / préchargement).
/// Chemin : offibox/pdf/{laboratory_normalized}/{url.hashCode.abs()}.pdf
///
/// Une [quotaBytes] limite la taille du cache ; les fichiers les plus anciens
/// (date de modification) sont supprimés quand le quota est dépassé.
/// Pour héberger les PDF sur Google Cloud Storage : uploadez les catalogues
/// dans un bucket, mettez les URLs GCS dans vos données (feuille/CSV) ;
/// l'app les téléchargera comme toute URL (et les mettra en cache local limité).
class PdfCacheService {
  /// Quota max du cache PDF (environ 400 Mo). Au-delà, éviction LRU.
  static const int quotaBytes = 400 * 1024 * 1024;

  static String _normalizeLaboratory(String laboratory) {
    return laboratory
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  static Future<Directory> _cacheRoot() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/offibox/pdf');
  }

  /// Récupère tous les fichiers .pdf (et .pdf.json) du cache avec taille et date.
  static Future<List<({File file, int size, DateTime modified})>> _listCachedFiles(
    Directory root,
  ) async {
    final list = <({File file, int size, DateTime modified})>[];
    if (!await root.exists()) return list;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File && (e.path.endsWith('.pdf') || e.path.endsWith('.pdf.json'))) {
        final stat = await e.stat();
        list.add((file: e, size: stat.size, modified: stat.modified));
      }
    }
    return list;
  }

  /// Libère de l'espace en supprimant les fichiers les plus anciens jusqu'à être sous le quota.
  static Future<void> _evictIfOverQuota(Directory root) async {
    final files = await _listCachedFiles(root);
    int total = 0;
    for (final e in files) {
      total += e.size;
    }
    if (total <= quotaBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final e in files) {
      if (total <= quotaBytes) break;
      try {
        await e.file.delete();
        total -= e.size;
      } catch (_) {
        // ignore
      }
    }
  }

  static Future<File> getCachedPdf({
    required String pdfUrl,
    required String laboratory,
  }) async {
    final root = await _cacheRoot();
    final labDir = Directory(
      '${root.path}/${_normalizeLaboratory(laboratory)}',
    );

    if (!await labDir.exists()) {
      await labDir.create(recursive: true);
    }

    final file = File('${labDir.path}/${pdfUrl.hashCode.abs()}.pdf');

    if (await file.exists()) {
      return file; // déjà en cache
    }

    await _evictIfOverQuota(root);

    final response = await http.get(Uri.parse(pdfUrl));
    if (response.statusCode != 200) {
      throw Exception('Erreur téléchargement PDF');
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}
