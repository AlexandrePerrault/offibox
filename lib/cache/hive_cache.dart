import 'package:hive/hive.dart';
import '../models/search_result.dart';
import 'cache_keys.dart';

class HiveCache {
  HiveCache._();
  static final HiveCache instance = HiveCache._();

  Box<dynamic>? _box;
  static const Duration _ttl = Duration(hours: 24);

  // ============================================================
  // 🚀 INIT (SAFE)
  // ============================================================
  Future<void> init() async {
    if (_box != null) return;

    if (!Hive.isBoxOpen(kHiveBoxName)) {
      _box = await Hive.openBox(kHiveBoxName);
    } else {
      _box = Hive.box(kHiveBoxName);
    }

    // 🧹 purge auto des entrées expirées
    clearExpired();
  }

  bool get isReady => _box != null;

  // ============================================================
  // 🧹 TTL CLEANUP
  // ============================================================
  void clearExpired() {
    if (_box == null) return;

    final now = DateTime.now();

    for (final k in _box!.keys.toList()) {
      final raw = _box!.get(k);

      if (raw is Map && raw['ts'] is int) {
        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(raw['ts'] as int),
        );

        if (age > _ttl) {
          _box!.delete(k);
        }
      }
    }
  }

  // ============================================================
  // 🔍 SEARCH CACHE (TTL 24h)
  // ============================================================
  List<SearchResult>? readSearch(String query) {
    if (_box == null) return null;

    final key = searchCacheKey(query);
    final raw = _box!.get(key);
    if (raw == null) return null;

    if (raw is! Map) {
      _box!.delete(key);
      return null;
    }

    final ts = raw['ts'] as int?;
    final data = raw['data'];

    if (ts == null || data is! List) {
      _box!.delete(key);
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - ts > _ttl.inMilliseconds) {
      _box!.delete(key);
      return null;
    }

    return data
        .map((e) =>
            SearchResult.fromJson(Map<String, dynamic>.from(e)),)
        .toList();
  }

  void writeSearch(String query, List<SearchResult> results) {
    if (_box == null) return;

    final key = searchCacheKey(query);

    _box!.put(
      key,
      {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': results.map((e) => e.toJson()).toList(),
      },
    );
  }

  // ============================================================
  // 🧹 INVALIDATION
  // ============================================================
  void clearAll() {
    if (_box == null) return;
    _box!.clear();
  }

  void clearSearch() {
    if (_box == null) return;

    final keys = _box!.keys
        .where((k) =>
            k.toString().startsWith('$kCacheVersion:search'),)
        .toList();

    for (final k in keys) {
      _box!.delete(k);
    }
  }
}
