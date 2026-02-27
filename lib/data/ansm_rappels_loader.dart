import 'package:http/http.dart' as http;

import 'package:offibox/data/data_sources.dart';

/// Normalise un libellé pour le matching avec les noms du fichier rappels (trim, minuscules, espaces multiples → un).
String normalizeProductNameForRappel(String s) {
  if (s.isEmpty) return '';
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\r\n]+'), ' ');
}

/// Charge le CSV des rappels ANSM (col A = nom du produit).
/// Retourne un set de noms normalisés pour comparaison avec les libellés BDM.
/// Si [ANSM_RAPPELS_CSV_URL] est vide ou le chargement échoue, retourne un set vide.
Future<Set<String>> loadAnsmRappelsProductNames() async {
  final url = ANSM_RAPPELS_CSV_URL.trim();
  if (url.isEmpty) return {};

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return {};
    final body = response.body;
    if (body.isEmpty) return {};

    final names = <String>{};
    final lines = body.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // CSV : première colonne (avant ; ou , ou \t selon séparateur)
      final firstCol = trimmed
          .split(RegExp(r'[;\t,]'))
          .first
          .replaceAll('"', '')
          .trim();
      if (firstCol.isEmpty) continue;
      names.add(normalizeProductNameForRappel(firstCol));
    }
    return names;
  } catch (_) {
    return {};
  }
}
