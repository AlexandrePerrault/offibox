import 'package:flutter/foundation.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/keywords_parser.dart';
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/models/source_type.dart';

/// Arguments pour [buildBdmListFromPrefetched] (top-level pour compute).
class BdmBuildArgs {
  const BdmBuildArgs({
    required this.bdmRaw,
    required this.stupCips,
    required this.cipHospitaliers,
    required this.pihCips,
    required this.surveillanceCips,
    required this.exceptionCips,
    required this.otcCips,
    required this.biosimilaireByCip,
    required this.generiquePrincepsByCip,
    required this.princepsToGenericName,
  });
  final List<Map<String, dynamic>> bdmRaw;
  final Set<String> stupCips;
  final Set<String> cipHospitaliers;
  final Set<String> pihCips;
  final Set<String> surveillanceCips;
  final Set<String> exceptionCips;
  final Set<String> otcCips;
  final Map<String, String> biosimilaireByCip;
  final Map<String, String> generiquePrincepsByCip;
  final Map<String, String> princepsToGenericName;
}

/// Top-level pour compute : mapping BDM → SearchResult hors du main isolate (évite le lag au preload).
List<SearchResult> buildBdmListFromPrefetched(BdmBuildArgs args) {
  return args.bdmRaw.map<SearchResult>((row) {
    return mapper.fromBdm(
      row,
      args.stupCips,
      args.cipHospitaliers,
      args.pihCips,
      args.surveillanceCips,
      args.exceptionCips,
      args.otcCips,
      biosimilaireByCip: args.biosimilaireByCip,
      generiquePrincepsByCip: args.generiquePrincepsByCip,
      princepsToGenericName: args.princepsToGenericName,
    );
  }).toList();
}



Future<List<SearchResult>> loadCoreData({
  required Set<String> stupCips,
  required Set<String> cipHospitaliers,
  required Set<String> pihCips,
  required Set<String> surveillanceCips,
  required Set<String> exceptionCips,
  required Set<String> otcCips,
  required Map<String, String> biosimilaireByCip,
  required Map<String, String> generiquePrincepsByCip,
  required Map<String, String> princepsToGenericName,
}) async {

  // ⚡ Outils métier remplace keyword ; sites web = source à part (affichage ligne 1/2 dédié)
  final results = await Future.wait([
    parseBDM(BDM_URL),
    parseKeywords(OUTILS_METIER_CSV_URL), // keyword
    parseKeywords(SITES_WEB_CSV_URL, sourceType: SourceType.siteWeb),
  ]);

  final bdmRaw = results[0] as List<Map<String, dynamic>>;
  final keywords = results[1] as List<SearchResult>;
  final sitesWeb = results[2] as List<SearchResult>;

  if (kDebugMode && bdmRaw.isEmpty) {
    debugPrint('[Offibox] ⚠ BDM vide - vérifier BDM_URL ou format CSV');
  }

  // 🧠 Mapping BDM → SearchResult
final bdm = bdmRaw.map<SearchResult>((row) {
  return mapper.fromBdm(
    row,
    stupCips,
    cipHospitaliers,
    pihCips,
    surveillanceCips,
    exceptionCips,
    otcCips,
    biosimilaireByCip: biosimilaireByCip,
    generiquePrincepsByCip: generiquePrincepsByCip,
    princepsToGenericName: princepsToGenericName,
  );
}).toList();


  return [...bdm, ..._dedupeKeywordAndSiteWeb(keywords, sitesWeb)];
}

/// Évite les doublons (ex. « Annuaire Santé » en outil métier + site web) : une seule entrée par (libellé normalisé, URL).
List<SearchResult> _dedupeKeywordAndSiteWeb(
  List<SearchResult> keywords,
  List<SearchResult> sitesWeb,
) {
  final seen = <String>{};
  final out = <SearchResult>[];
  for (final r in [...keywords, ...sitesWeb]) {
    final key = '${r.labelNorm}|${r.url?.trim() ?? ''}';
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(r);
  }
  return out;
}

/// Construit la liste core (BDM mappé + keywords + sitesWeb) à partir de données déjà chargées.
/// Permet d'afficher la recherche dès que BDM + deps sont prêts, sans attendre LPP/composition/etc.
List<SearchResult> buildCoreFromPrefetched({
  required List<Map<String, dynamic>> bdmRaw,
  required List<SearchResult> keywords,
  required List<SearchResult> sitesWeb,
  required Set<String> stupCips,
  required Set<String> cipHospitaliers,
  required Set<String> pihCips,
  required Set<String> surveillanceCips,
  required Set<String> exceptionCips,
  required Set<String> otcCips,
  required Map<String, String> biosimilaireByCip,
  required Map<String, String> generiquePrincepsByCip,
  required Map<String, String> princepsToGenericName,
}) {
  final bdm = bdmRaw.map<SearchResult>((row) {
    return mapper.fromBdm(
      row,
      stupCips,
      cipHospitaliers,
      pihCips,
      surveillanceCips,
      exceptionCips,
      otcCips,
      biosimilaireByCip: biosimilaireByCip,
      generiquePrincepsByCip: generiquePrincepsByCip,
      princepsToGenericName: princepsToGenericName,
    );
  }).toList();
  return [...bdm, ..._dedupeKeywordAndSiteWeb(keywords, sitesWeb)];
}
