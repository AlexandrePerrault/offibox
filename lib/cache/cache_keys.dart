/// Version globale du cache
const String kCacheVersion = 'v1';

/// Nom de la box Hive
const String kHiveBoxName = 'offibox_cache';

/// Génère une clé unique par requête
String searchCacheKey(String query) {
  return '$kCacheVersion:search:$query';
}
