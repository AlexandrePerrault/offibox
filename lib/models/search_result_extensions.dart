import 'search_result.dart';
import 'source_type.dart';

extension SearchResultComputed on SearchResult {
  // ─────────────────────────────
  // 🔤 Normalisations recherche
  // ─────────────────────────────

  String get labelNorm =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String get cipNorm =>
      (cip13 ?? '').replaceAll(RegExp(r'\D'), '');

  // ─────────────────────────────
  // ⛔ États métier
  // ─────────────────────────────

  /// Inactif = NSFP ou médicament d’exception sans date
  bool get isInactive => isNsfpEffective;

  /// NSFP réellement actif (date présente)
  bool get isNsfpEffective =>
      nsfp == true &&
      nsfpDate != null &&
      nsfpDate!.trim().isNotEmpty;

  /// Gélule d'abord dans le tri (étiquette contenant "gélule")
  bool get isGelule =>
      label.toLowerCase().contains('gélule') ||
      label.toLowerCase().contains('gelule');

  /// Produit pharmaceutique (BDM, LPP, keywords) vs pansements/veto/AMC
  bool get isDrug =>
      source == SourceType.bdm ||
      source == SourceType.keyword ||
      source == SourceType.lpp;
}
