import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/medicaments_api_client.dart';
import 'package:offibox/utils/normalize.dart';

/// Résout le **CIP13** BDPM pour une formule Weleda à partir du code **W…** et de la forme
/// (granules, gouttes…). Complété par [assets/data/weleda_w_cip13.csv] quand présent ; sinon
/// repli sur [medicaments-api](https://medicaments-api.giygas.dev).
///
/// Le code EH du CSV Weleda n’est pas un CIP : il reste dans [SearchResult.weledaEhRegistration].
class WeledaCipResolver {
  WeledaCipResolver._();

  static final MedicamentsApiClient _client = MedicamentsApiClient();

  /// Supprime les segments finaux « (…) » répétés (affichage composition).
  static String compositionForDisplay(String raw) {
    var s = raw.trim();
    while (s.isNotEmpty) {
      final next =
          s.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
      if (next == s) break;
      s = next;
    }
    return s;
  }

  /// Extrait `W123` depuis un libellé type `W169 — Granules 4 g`.
  static String? extractWeledaWCode(String label) {
    final m = RegExp(r'^(W\d+)\b', caseSensitive: false)
        .firstMatch(label.trim());
    return m?.group(1)?.toUpperCase();
  }

  /// Complète [cip13], [cip7], [cis] et [url] BDPM si l’API trouve une présentation qui matche.
  static Future<SearchResult> enrichFromMedicamentsApi(SearchResult item) async {
    if (item.source != SourceType.weleda) return item;
    final existing =
        item.cip13?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
    if (existing.length == 13 && existing.startsWith('34009')) {
      return item;
    }

    final wCode = extractWeledaWCode(item.label);
    if (wCode == null) return item;

    final queries = <String>[
      'weleda $wCode',
      '$wCode weleda',
    ];

    for (final q in queries) {
      try {
        final hits = await _client.searchByName(q);
        for (final json in hits) {
          final picked = _pickPresentation(json, item, wCode);
          if (picked != null) {
            final cip13 = picked.$1;
            final cis = picked.$2;
            final url = cis != null && cis.isNotEmpty
                ? 'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cis/extrait#tab-rcp'
                : item.url;
            return item.copyWith(
              cip13: cip13,
              cip7: cip13.substring(0, 7),
              cis: cis,
              url: url,
            );
          }
        }
      } catch (_) {}
    }

    return item;
  }

  static (String cip13, String? cis)? _pickPresentation(
    Map<String, dynamic> json,
    SearchResult item,
    String wCode,
  ) {
    final cis = json['cis']?.toString().trim();
    final elementPharm =
        (json['elementPharmaceutique'] ?? '').toString().toUpperCase();
    final presentations = json['presentation'] as List? ?? [];
    if (presentations.isEmpty) return null;

    final wu = wCode.toUpperCase();
    final labelLow = item.label.toLowerCase();
    final wantsGranules = labelLow.contains('granule');
    final wantsGouttes = labelLow.contains('goutte') ||
        labelLow.contains('solution buvable');
    final wantsPoudre = labelLow.contains('poudre');

    (String cip13, String? cis)? best;
    var bestScore = -1;

    for (final p in presentations) {
      if (p is! Map<String, dynamic>) continue;
      final lib =
          (p['libelle'] ?? '').toString().toLowerCase();
      final cipRaw =
          (p['cip13'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (cipRaw.length != 13 || !cipRaw.startsWith('34009')) continue;

      var score = 0;
      if (elementPharm.contains(wu) || lib.contains(wu.toLowerCase())) {
        score += 5;
      }
      if (wantsGranules &&
          (lib.contains('granule') || lib.contains('granules'))) {
        score += 4;
      }
      if (wantsGouttes &&
          (lib.contains('goutte') ||
              lib.contains('solution') ||
              lib.contains('flacon'))) {
        score += 4;
      }
      if (wantsPoudre && lib.contains('poudre')) score += 4;

      if (score > bestScore) {
        bestScore = score;
        best = (cipRaw, cis?.isNotEmpty == true ? cis : null);
      }
    }

    if (best == null) return null;
    if (presentations.length > 1 && bestScore < 8) return null;
    return bestScore >= 5 ? best : null;
  }

  /// Texte normalisé pour filtrer les formules par composants (CSV `composition`).
  static String compositionHaystack(SearchResult item) {
    final comp = (item.groupLabel ?? '').trim();
    final raw = item.labelRaw.trim();
    return normalizeLooseKeepSpaces('$comp $raw');
  }

  /// Tous les jetons (≥2 caractères) doivent être présents dans [haystack].
  static bool compositionMatchesTokens(String haystack, String queryRaw) {
    final qNorm = normalizeLooseKeepSpaces(queryRaw.trim());
    if (qNorm.isEmpty) return true;
    final tokens = qNorm
        .split(RegExp(r'\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 2)
        .toList();
    if (tokens.isEmpty) return true;
    final hay = haystack.toLowerCase();
    for (final t in tokens) {
      if (!hay.contains(t.toLowerCase())) return false;
    }
    return true;
  }
}
