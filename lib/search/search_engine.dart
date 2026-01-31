import '../models/search_result.dart';

/// 🧠 Moteur de recherche Offibox
/// - indexation
/// - matching tolérant
/// - tri métier
/// - cache sécurisé
class SearchEngine {
  SearchEngine(this.allResults) {
    _buildIndexes();
  }

  List<SearchResult> allResults;

  // ===============================
  // 📦 INDEXES
  // ===============================
  final Map<String, List<SearchResult>> _indexByFirst3 = {};
  final Map<String, List<SearchResult>> _indexByCip3 = {};

  // ===============================
  // 🧠 CACHE
  // ===============================
  final Map<String, List<SearchResult>> _cache = {};
  int _cacheVersion = 0;

  String _lastQuery = '';

  // ===============================
  // 🔁 INDEXATION
  // ===============================
  void _buildIndexes() {
    _indexByFirst3.clear();
    _indexByCip3.clear();

    for (final r in allResults) {
      // 🔤 label
      if (r.labelNorm.isNotEmpty) {
        final key = r.labelNorm.length >= 3
            ? r.labelNorm.substring(0, 3)
            : r.labelNorm;

        _indexByFirst3.putIfAbsent(key, () => []).add(r);
      }

      // 🔢 CIP
      if (r.cipNorm.length >= 3) {
        final key = r.cipNorm.substring(0, 3);
        _indexByCip3.putIfAbsent(key, () => []).add(r);
      }
    }
  }

  /// À appeler si allResults change
  void updateResults(List<SearchResult> newResults) {
    allResults = newResults;
    _buildIndexes();
    invalidateCache();
  }

  void invalidateCache() {
    _cache.clear();
    _cacheVersion++;
  }

  // ===============================
  // 🔍 API PUBLIQUE
  // ===============================
  List<SearchResult> search(String rawQuery, {bool allowCache = true}) {
    final query = rawQuery.trim().toLowerCase();
    if (query.length < 2) return [];

    _lastQuery = query;

    final tokens = query
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((t) => t.length >= 2)
        .toList();

    if (tokens.isEmpty) return [];

    final cacheKey = '$query|$_cacheVersion';

    if (allowCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final first = tokens.first;
    final isNumeric = RegExp(r'^\d+$').hasMatch(first);
    final key = first.length >= 3 ? first.substring(0, 3) : first;

    List<SearchResult> candidates;

    // 🔢 CIP / GTIN long → pas de filtre
    if (isNumeric && query.length >= 6) {
      candidates = allResults;
    }
    // 🔢 CIP partiel
    else if (isNumeric && _indexByCip3.isNotEmpty) {
      candidates = _indexByCip3[key] ?? allResults;
    }
    // 🔤 texte
    else if (_indexByFirst3.isNotEmpty) {
      candidates = _indexByFirst3[key] ?? allResults;
    }
    // 🛟 fallback
    else {
      candidates = allResults;
    }

    // ===============================
    // 🎯 MATCH
    // ===============================
    var results = candidates
        .where((r) => _matchItem(r: r, tokens: tokens))
        .toList();

    // fallback large si trop restrictif
    if (results.isEmpty && candidates.length != allResults.length) {
      results = allResults
          .where((r) => _matchItem(r: r, tokens: tokens))
          .toList();
    }

    results.sort(_compareResults);

    if (allowCache) {
      _cache[cacheKey] = results;
      if (_cache.length > 200) {
        _cache.remove(_cache.keys.first);
      }
    }

    return results;
  }

  // ===============================
  // 🧩 MATCHING
  // ===============================
  bool _matchItem({
    required SearchResult r,
    required List<String> tokens,
  }) {
    final label = r.labelNorm;
    final cip = r.cipNorm;

    // 💊 BDM strict
    if (r.source == SourceType.bdm) {
      final first = tokens.first;

      if (first.length >= 3 &&
          !label.startsWith(first) &&
          !cip.startsWith(first)) {
        return false;
      }

      final limit = tokens.length > 2 ? 2 : tokens.length;
      for (int i = 0; i < limit; i++) {
        final t = tokens[i];
        if (!label.contains(t) && !cip.contains(t)) return false;
      }
      return true;
    }

    // 🩹 DM / 🐾 VETO souple
    if (r.source == SourceType.dm || r.source == SourceType.veto) {
      final textTokens =
          tokens.where((t) => !RegExp(r'^\d+$').hasMatch(t)).toList();
      final numTokens =
          tokens.where((t) => RegExp(r'^\d+$').hasMatch(t)).toList();

      if (numTokens.isNotEmpty && cip.isNotEmpty) {
        if (numTokens.join() == cip) return true;
      }

      for (final t in textTokens) {
        if (label.contains(t)) return true;
      }
      return false;
    }

    // 🧴 autres strict
    for (final t in tokens) {
      if (!label.contains(t) && !cip.contains(t)) return false;
    }
    return true;
  }

  // ===============================
  // 🔢 TRI
  // ===============================
  int _compareResults(SearchResult a, SearchResult b) {
    final pa = _priority(a);
    final pb = _priority(b);
    if (pa != pb) return pa.compareTo(pb);

    final sa = _startsWithScore(a);
    final sb = _startsWithScore(b);
    if (sa != sb) return sb.compareTo(sa);

    return a.label.compareTo(b.label);
  }

  int _priority(SearchResult r) {
    if (r.isNsfpEffective) return 900;
    if (r.hospitalOnly == true) return 1000;

    switch (r.source) {
      case SourceType.bdm:
        return 0;
      case SourceType.dm:
        return 100;
      case SourceType.veto:
        return 200;
      case SourceType.amc:
        return 300;
      default:
        return 800;
    }
  }

  // ===============================
  // 📊 SCORE
  // ===============================
  int _startsWithScore(SearchResult r) {
    final tokens = _lastQuery
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((t) => t.length >= 2)
        .toList();

    final label = _normalize(r.labelRaw ?? r.label);
    final cip = _normalize(r.cip13 ?? '');
    final lab = _normalize(r.laboratory ?? '');

    int score = 0;

    if (tokens.isNotEmpty &&
        (label.startsWith(tokens[0]) || cip.startsWith(tokens[0]))) {
      score += 5;
    }

    if (tokens.length >= 2 &&
        (label.contains(tokens[1]) || cip.contains(tokens[1]))) {
      score += 3;
    }

    if (tokens.length >= 3 &&
        (lab.startsWith(tokens[2]) || label.contains(tokens[2]))) {
      score += 2;
    }

    return score;
  }

  // ===============================
  // 🔧 UTILS
  // ===============================
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
