import 'package:offibox/models/search_result.dart';

/// Service de recherche dans l'annuaire RPPS (data.gouv.fr ou API).
class AnnuaireSanteRppsService {
  AnnuaireSanteRppsService();

  /// Score de préférence structure (plus petit = affiché en premier).
  static int preferredStructureScore(SearchResult hit) {
    return 0;
  }

  /// Ordre d'affichage par profession (tri).
  static int professionDisplayOrder(String label) {
    return 0;
  }

  Future<List<SearchResult>> search({
    String? rpps,
    String? structure,
    String? nom,
    String? prenom,
    int limit = 20,
  }) async {
    return [];
  }

  void dispose() {}
}
