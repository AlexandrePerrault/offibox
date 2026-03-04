import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data_sources.dart';

/// Une entrée fiches VOC (OMÉDIT) : médicament, URL fiche patient, URL fiche pro.
class VocFicheEntry {
  const VocFicheEntry({
    required this.medicament,
    required this.urlPatient,
    required this.urlPro,
  });
  final String medicament;
  final String urlPatient;
  final String urlPro;
}

/// Charge fiches_voc.csv (séparateur ;, UTF-8). Col A = médicament, B = URL fiche patient, C = URL fiche pro.
/// Tri par longueur de médicament décroissante pour matcher le libellé le plus long en premier.
Future<List<VocFicheEntry>> loadFichesVoc() async {
  final list = <VocFicheEntry>[];
  try {
    final response = await http.get(Uri.parse(FICHES_VOC_CSV_URL));
    if (response.statusCode != 200) {
      if (kDebugMode) debugPrint('[Offibox] ⚠ Fiches VOC: HTTP ${response.statusCode}');
      return list;
    }
    final body = utf8.decode(response.bodyBytes);
    final lines = const LineSplitter().convert(body);
    for (final line in lines.skip(1)) {
      final row = line
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
      if (row.length >= 3) {
        final medicament = row[0];
        final urlPatient = row[1];
        final urlPro = row[2];
        if (medicament.isNotEmpty && (urlPatient.isNotEmpty || urlPro.isNotEmpty)) {
          list.add(VocFicheEntry(
            medicament: medicament,
            urlPatient: urlPatient,
            urlPro: urlPro,
          ),);
        }
      }
    }
    list.sort((a, b) => b.medicament.length.compareTo(a.medicament.length));
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] ⚠ Fiches VOC erreur: $e');
  }
  return list;
}
