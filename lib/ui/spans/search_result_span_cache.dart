import 'package:flutter/widgets.dart';

class SearchResultSpanCache {
  /// Taille max du cache (évite recalcul des spans au scroll).
  static const int _maxEntries = 500;

  /// Cache LRU simple :
  /// - insertion order = ordre d’utilisation
  /// - remove + reinsert = marque comme récent
  static final Map<String, List<InlineSpan>> _cache =
      <String, List<InlineSpan>>{};

  static List<InlineSpan> get(
    String key,
    List<InlineSpan> Function() builder,
  ) {
    final cached = _cache.remove(key);
    if (cached != null) {
      // 🔁 marque comme récemment utilisé
      _cache[key] = cached;
      return cached;
    }

    final value = builder();
    _cache[key] = value;

    // 🧹 eviction LRU
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    return value;
  }

  static void clear() => _cache.clear();

  /// (optionnel) debug
  static int get size => _cache.length;
}
