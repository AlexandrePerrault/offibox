import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:offibox/config/app_config.dart';
import 'package:offibox/constants/catalogue_cart_config.dart';
import 'package:offibox/models/pansement_item.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/models/veto_item.dart';

import 'amc_mapper.dart';
import 'cerp_parser.dart';
import 'data_sources.dart';
import 'offiboxdata_fetch.dart';
import 'laboratoires_parser.dart';
import 'pharmacovigilance_parser.dart';
import 'pansements_parser.dart';
import 'veto_parser.dart';
import 'search_result_mapper.dart' as mapper;
String normalizeAmoLabel(String label) {
  return label
      .toLowerCase()
      .replaceFirst(
        RegExp(r"^cpam\s+(de|des|du|la|le|l')\s+"),
        '',
      );
}



Future<List<SearchResult>> _loadAmcAmo() async {
  final results = <SearchResult>[];
  try {
    final response = await OffiboxDataFetch.get(AMC_URL);
    if (response.statusCode != 200) {
      if (kDebugMode) debugPrint('[Offibox] Mutuelles non disponibles (HTTP ${response.statusCode})');
      return results;
    }
    final lines = const LineSplitter().convert(response.body);
    final amcRows = lines.skip(1).map((line) {
      return line
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
    }).toList();
    for (final row in amcRows) {
      try {
        results.add(fromAmoRow(row));
      } catch (_) {}
      try {
        results.add(fromAmcRow(row));
      } catch (_) {}
    }
    if (kDebugMode && results.isEmpty) {
      debugPrint('[Offibox] Mutuelles (AMO/AMC) vides - vérifier format mutuelles_2026.csv');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] Mutuelles erreur: $e');
  }
  return results;
}

Future<List<SearchResult>> loadExtraData() async {
  final results = <SearchResult>[];

  // Chargement en parallèle ; chaque parse est protégé pour ne jamais faire crasher loadExtraData (404, réseau, etc.)
  final extra = await Future.wait([
    parsePansements(PANSEMENTS_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Pansements: $e');
      return <PansementItem>[];
    }),
    parseVeto(VETO_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Veto: $e');
      return <VetoItem>[];
    }),
    parseLaboratoires(LABORATOIRES_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Laboratoires: $e');
      return <SearchResult>[];
    }),
    parseCerp(CERP_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] CERP Madouest: $e');
      return <SearchResult>[];
    }),
    parseCoetpharm2026(COETPHARM_2026_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Coetpharm: $e');
      return <SearchResult>[];
    }),
    _loadAmcAmo().catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] AMC/AMO: $e');
      return <SearchResult>[];
    }),
    parsePharmacovigilance(PHARMACOVIGILANCE_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Pharmacovigilance: $e');
      return <SearchResult>[];
    }),
    parseCentresAntiPoison(CENTRES_ANTI_POISON_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] Centres anti poison: $e');
      return <SearchResult>[];
    }),
    parseChu(CHU_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] CHU: $e');
      return <SearchResult>[];
    }),
    parseCeipAddictovigilance(CEIP_ADDICTOVIGILANCE_URL).catchError((Object e, StackTrace _) {
      if (kDebugMode) debugPrint('[Offibox] CEIP-A: $e');
      return <SearchResult>[];
    }),
  ]);

  try {
    results.addAll((extra[0] as List<PansementItem>).map(mapper.fromPansement));
  } catch (_) {}

  try {
    results.addAll((extra[1] as List<VetoItem>).map(mapper.fromVeto));
  } catch (_) {}

  try {
    final labs = extra[2] as List<SearchResult>;
    results.addAll(labs);
    final labLabels = results.where((r) => r.source == SourceType.catalogue).map((r) => r.labelRaw.toUpperCase()).toSet();
    if (!labLabels.contains('VIATRIS')) {
      results.addAll(defaultLaboratoiresFallback);
    }
  } catch (_) {
    results.addAll(defaultLaboratoiresFallback);
  }

  try {
    results.addAll(extra[3] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[4] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[5] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[6] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[7] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[8] as List<SearchResult>);
  } catch (_) {}

  try {
    results.addAll(extra[9] as List<SearchResult>);
  } catch (_) {}

  // ─────────────────────────
  // 📦 Catalogue équipement CERP (résultat "raccourci" + ouverture PDF) — désactivé si cerpFeaturesEnabled = false
  // ─────────────────────────
  if (AppConfig.cerpFeaturesEnabled) {
    final equipPdfUrl = CatalogueCartConfig.cerpEquipmentPdfUrl.trim();
    if (equipPdfUrl.isNotEmpty) {
      results.add(
        SearchResult(
          source: SourceType.cerp,
          label: 'Catalogue équipement',
          labelRaw: 'CATALOGUE ÉQUIPEMENT CERP FOURNITURES',
          laboratory: 'CERP',
          iconUrl: CatalogueCartConfig.cerpLogoAssetPath,
          url: equipPdfUrl,
          catalogueUrl: equipPdfUrl,
          badge1Name: 'PDF',
          badge1Url: equipPdfUrl,
          nsfp: false,
          hospitalOnly: false,
        ),
      );
    }
  }

  // ─────────────────────────
  // 🧼 Nettoyage final
  // ─────────────────────────
  // 1️⃣ Séparer AMO / AMC / reste
final amos = results.where((r) => r.source == SourceType.amo).toList();
final amcs = results.where((r) => r.source == SourceType.amc).toList();
final others = results.where((r) => r.source != SourceType.amo && r.source != SourceType.amc).toList();

// 2️⃣ DÉDOUBLONNAGE AMO par code organisme
final uniqueAmos = {
  for (final r in amos)
    if (r.cip13 != null) r.cip13!: r,
}.values.toList();

// 3️⃣ DÉDOUBLONNAGE AMC (mutuelles) par code préfectoral — seule la première apparaît
final uniqueAmcs = <SearchResult>[];
final seenAmcCodes = <String>{};
for (final r in amcs) {
  final code = r.cip13?.replaceAll(RegExp(r'\D'), '');
  if (code != null && code.isNotEmpty && !seenAmcCodes.contains(code)) {
    seenAmcCodes.add(code);
    uniqueAmcs.add(r);
  }
}
uniqueAmcs.sort((a, b) => a.label.compareTo(b.label));

// 4️⃣ TRI alphabétique CPAM
uniqueAmos.sort(
  (a, b) => normalizeAmoLabel(a.labelRaw)
      .compareTo(normalizeAmoLabel(b.labelRaw)),
);

// 5️⃣ Recomposer la liste finale
final cleanedResults = [
  ...others,      // ✅ DM, VETO, LPP, BDM, LABOS, etc.
  ...uniqueAmcs,  // ✅ AMC (mutuelles) dédoublonnés
  ...uniqueAmos,  // ✅ AMO nettoyés
];

// 🔒 Liste figée (sécurité UI)
return List<SearchResult>.unmodifiable(cleanedResults);


}
