import 'package:offibox/config/app_config.dart';

/// Configuration des catalogues PDF avec panier (commande de boîtes).
/// L'icône panier n'apparaît que pour les URLs listées ici.
/// Pour chaque PDF listé : sélection d'un code à 7 chiffres → ajout au panier avec quantité.
class CatalogueCartConfig {
  CatalogueCartConfig._();

  /// URL du PDF "Catalogue Équipement CERP".
  ///
  /// Recommandé: héberger le PDF sur Firebase Storage (download URL) et passer
  /// la valeur via dart-define pour éviter de modifier le code à chaque update.
  ///
  /// Exemple:
  /// flutter build windows --dart-define=CERP_EQUIPMENT_PDF_URL="https://firebasestorage.googleapis.com/..."
  static const String cerpEquipmentPdfUrl =
      String.fromEnvironment('CERP_EQUIPMENT_PDF_URL', defaultValue: '');

  /// CSV optionnel (code7;prix) pour calculer le montant et le franco.
  /// Exemple:
  /// flutter build windows --dart-define=CERP_EQUIPMENT_PRICES_CSV_URL="https://.../equipement_prix.csv"
  static const String cerpEquipmentPricesCsvUrl =
      String.fromEnvironment('CERP_EQUIPMENT_PRICES_CSV_URL', defaultValue: '');

  /// Logo affiché en ligne 1 (CERP).
  static const String cerpLogoAssetPath = 'assets/icons/2025_Logo_CERP_FRANCE_RVB.jpg';

  /// Seuil franco (en euros) pour activer l’envoi de commande.
  static const double francoThresholdEur = 55.0;

  /// Destinataire de commande (email).
  static const String orderRecipientEmail = 'mireille.lemoine@cerpba.fr';

  /// Numéro de fax proposé (information).
  static const String faxNumber = '02 96 68 26 03';

  /// URLs des PDF pour lesquels le panier est affiché.
  /// Catalogue Équipement CERP 2025 — uniquement si CERP activé (setup MSI à part).
  static List<String> get cartEnabledPdfUrls => [
        if (AppConfig.cerpFeaturesEnabled) cerpEquipmentPdfUrl,
      ];

  /// True si le panier doit être affiché pour cette URL de PDF.
  static bool isCartEnabledForPdf(String? pdfUrl) {
    if (!AppConfig.cerpFeaturesEnabled) return false;
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
