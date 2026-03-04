import 'package:firebase_storage/firebase_storage.dart';

/// Récupère les URL de téléchargement de tous les fichiers sous un préfixe Storage.
/// Gère les sous-dossiers (prefixes) de façon récursive.
class FirebaseStorageListService {
  /// Chemin par défaut : SANTRALIA-CATALOGUE 2025 (équivalent gs://bucket/SANTRALIA-CATALOGUE 2025)
  static const String defaultPrefix = 'SANTRALIA-CATALOGUE 2025';

  /// Liste tous les fichiers sous [prefix] et retourne (nom du fichier, URL de téléchargement).
  /// [prefix] peut être "SANTRALIA-CATALOGUE 2025" ou "SANTRALIA-CATALOGUE 2025/sous-dossier".
  static Future<List<({String name, String url})>> listDownloadUrls({
    String prefix = defaultPrefix,
  }) async {
    final ref = FirebaseStorage.instance.ref(prefix);
    final results = <({String name, String url})>[];

    await _listRecursive(ref, results);
    return results;
  }

  static Future<void> _listRecursive(
    Reference ref,
    List<({String name, String url})> out,
  ) async {
    ListResult listResult;
    try {
      listResult = await ref.listAll();
    } catch (e) {
      // Pas de permission ou préfixe inexistant
      rethrow;
    }

    for (final item in listResult.items) {
      final url = await item.getDownloadURL();
      out.add((name: item.fullPath, url: url));
    }

    for (final prefixRef in listResult.prefixes) {
      await _listRecursive(prefixRef, out);
    }
  }
}
