import '../search/search_engine.dart';
import 'hive_cache.dart';

class SearchWarmup {
  SearchWarmup._();

  static const List<String> _seedQueries = [
    'dol',
    'para',
    'amox',
    'ibu',
    'adv',
    'vit',
    'ser',
    'lev',
    'ome',
    'cip',
  ];

  static Future<void> run({
    required SearchEngine engine,
  }) async {
    for (final q in _seedQueries) {
      final cached = HiveCache.instance.readSearch(q);
      if (cached != null) continue;

      final results = engine.search(q);
      if (results.isNotEmpty) {
        HiveCache.instance.writeSearch(q, results);
      }
    }
  }
}
