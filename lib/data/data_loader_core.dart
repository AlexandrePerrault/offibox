import 'package:offibox/models/search_result.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/keywords_parser.dart';
import 'data_sources.dart';

import '../main.dart'; // BDM_URL, KEYWORDS_URL, etc.

Future<List<SearchResult>> loadCoreData({
  required Set<String> cipHospitaliers, // ✅ SOURCE UNIQUE HOP
  required Map<String, String> biosimilaireByCip,
  required Map<String, String> generiquePrincepsByCip,
  required Map<String, String> princepsToGenericName,
}) async {
  // ⚡ Chargement parallèle
  final results = await Future.wait([
    parseBDM(BDM_URL),
    parseKeywords(KEYWORDS_URL),
  ]);

  final bdmRaw = results[0] as List<Map<String, dynamic>>;
  final keywords = results[1] as List<SearchResult>;

  final bdm = bdmRaw.map<SearchResult>((row) {
    return mapper.fromBdm(
      row,
      cipHospitaliers, // ✅ injecté ici
      biosimilaireByCip: biosimilaireByCip,
      generiquePrincepsByCip: generiquePrincepsByCip,
      princepsToGenericName: princepsToGenericName,
    );
  }).toList();

  return [
    ...bdm,
    ...keywords,
  ];
}
