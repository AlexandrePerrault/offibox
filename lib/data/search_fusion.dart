import '../models/search_result.dart';

List<SearchResult> fuseSearchResults({
  required List<SearchResult> bdm,
  required List<SearchResult> dm,
  required List<SearchResult> veto,
}) {
  final all = [...bdm, ...dm, ...veto];

  all.sort((a, b) {
    if (a.isGelule != b.isGelule) {
      return a.isGelule ? -1 : 1; // 💊 gélule d’abord
    }
    return a.sourcePriority.compareTo(b.sourcePriority);
  });

  return all;
}
