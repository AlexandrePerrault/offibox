/// Index CIP7 → CIP13 construit à partir du BDM master
Map<String, Set<String>> buildCip7ToCip13Map(
  List<Map<String, dynamic>> bdmRows,
) {
  final map = <String, Set<String>>{};

  for (final row in bdmRows) {
    final cip7 =
        row['CIP7']?.toString().replaceAll(RegExp(r'\D'), '');
    final cip13 =
        row['CIP13']?.toString().replaceAll(RegExp(r'\D'), '');

    if (cip7 == null ||
        cip13 == null ||
        cip7.length != 7 ||
        cip13.length != 13) {
      continue;
    }

    map.putIfAbsent(cip7, () => <String>{}).add(cip13);
  }

  return map;
}
