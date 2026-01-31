import '../models/search_result.dart';
import '../models/pansement_item.dart';
import '../models/veto_item.dart';
import 'amc_mapper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/pansements_parser.dart';
import '../data/veto_parser.dart';
import '../data/laboratoires_parser.dart';
import 'data_sources.dart';

import 'search_result_mapper.dart' as mapper;

Future<List<SearchResult>> loadExtraData() async {
  final results = <SearchResult>[];

  // 🩹 DM / PANSEMENTS
  final dmItems = await parsePansements(PANSEMENTS_URL);
  results.addAll(dmItems.map(mapper.fromPansement));

  // 🐾 VÉTO
  final vetoItems = await parseVeto(VETO_URL);
  results.addAll(vetoItems.map(mapper.fromVeto));

  // 🏭 LABORATOIRES
  results.addAll(await parseLaboratoires(LABORATOIRES_URL));

  // 🏥 MUTUELLES (AMC)
  final response = await http.get(Uri.parse(AMC_URL));
  if (response.statusCode == 200) {
    final lines = const LineSplitter().convert(response.body);

    final amcRows = lines.skip(1).map((line) {
      return line
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
    });

    results.addAll(amcRows.map(fromAmcRow));
  }

  // 🔒 LISTE FIGÉE
  return List<SearchResult>.unmodifiable(results);
}
