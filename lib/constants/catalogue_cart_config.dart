/// Configuration des catalogues PDF avec panier (commande de boîtes).
/// L'icône panier n'apparaît que pour les URLs listées ici.
/// Pour chaque PDF listé : sélection d'un code à 7 chiffres → ajout au panier avec quantité.
class CatalogueCartConfig {
  CatalogueCartConfig._();

  /// URLs des PDF pour lesquels le panier est affiché.
  /// Catalogue Équipement CERP 2025 (ex. FlipHTML5 → PDF hébergé sur Firebase).
  static const List<String> cartEnabledPdfUrls = [
    // Catalogue Équipement CERP 2025 : coller l'URL Firebase ici
    // Exemple : 'https://firebasestorage.googleapis.com/v0/b/offibox-prod.firebasestorage.app/o/.../Catalogue%20Equipement%20Cerp%202025.pdf?alt=media&token=...',
  ];

  /// True si le panier doit être affiché pour cette URL de PDF.
  static bool isCartEnabledForPdf(String? pdfUrl) {
    if (pdfUrl == null || pdfUrl.trim().isEmpty) return false;
    final u = pdfUrl.trim();
    for (final allowed in cartEnabledPdfUrls) {
      final a = allowed.trim();
      if (a.isEmpty) continue;
      if (u == a || u.startsWith(a)) return true;
    }
    return false;
  }
}
