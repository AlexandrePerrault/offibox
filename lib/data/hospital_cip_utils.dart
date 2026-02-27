// lib/data/hospital_cip_utils.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';

/// Source unique : stupéfiants+hopital 202026.csv
/// Stupéfiants (badge S/AS) = col 0 ; hospitaliers = col 6 (1-based) = index 5 = CIP7 ; PIH = col 7 (index 6) ; surveillance = col 9 (index 8).

/// Résultat du chargement unique du CSV stupéfiants+hopital (1 requête HTTP).
/// Col 0 = CIP13 (stupéfiant), col 6 (1-based) = index 5 = CIP7 hospitaliers, col 7 = CIP13 (PIH), col 9 = CIP13 (surveillance).
class HospitalCipSets {
  const HospitalCipSets({
    required this.stupCips,
    required this.cipHospitaliers,
    required this.pihCips,
    required this.surveillanceCips,
  });
  /// CIP13 en col 0 = stupéfiants et assimilés.
  final Set<String> stupCips;
  final Set<String> cipHospitaliers;
  final Set<String> pihCips;
  final Set<String> surveillanceCips;
}

/// Charge en une requête : stupéfiants (col 0), CIP7 hospitaliers (col 6 / index 5), PIH (col 7), surveillance (col 9).
Future<HospitalCipSets> loadHospitalCipSets() async {
  final res = await http.get(Uri.parse(STUPEFIANTS_HOP_URL));
  if (res.statusCode != 200) {
    return const HospitalCipSets(
      stupCips: {},
      cipHospitaliers: {},
      pihCips: {},
      surveillanceCips: {},
    );
  }

  final lines = const LineSplitter().convert(res.body);
  final rows = lines.skip(1).map((l) => l.split(';')).toList();

  final stupCips = <String>{};
  final cip7Hospitaliers = <String>{};
  final pihCips = <String>{};
  final surveillanceCips = <String>{};

  for (final cols in rows) {
    if (cols.isNotEmpty) {
      final cip13Col0 = cols[0].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13Col0.length == 13) {
        stupCips.add(cip13Col0);
      }
    }
    // Col 6 (1-based) = index 5 = CIP Hospitaliers (CIP7)
    if (cols.length > 5) {
      final cip7 = cols[5].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip7.length == 7 && cip7.startsWith('5') && RegExp(r'^\d+$').hasMatch(cip7)) {
        cip7Hospitaliers.add(cip7);
      }
    }
    if (cols.length > 6) {
      final cip13 = cols[6].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13.length == 13) {
        pihCips.add(cip13);
      }
    }
    if (cols.length > 8) {
      final cip13 = cols[8].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13.length == 13) {
        surveillanceCips.add(cip13);
      }
    }
  }

  return HospitalCipSets(
    stupCips: stupCips,
    cipHospitaliers: cip7Hospitaliers,
    pihCips: pihCips,
    surveillanceCips: surveillanceCips,
  );
}

/// ─────────────────────────────
/// Charge les CIP7 hospitaliers (legacy, préférer loadHospitalCipSets)
/// ─────────────────────────────
Future<Set<String>> loadCipHospitaliers() async {
  final sets = await loadHospitalCipSets();
  return sets.cipHospitaliers;
}

/// ─────────────────────────────
/// BDM master : CIP7 → CIP13
/// ─────────────────────────────
Map<String, Set<String>> buildCip7ToCip13Map(
  List<Map<String, dynamic>> bdmRows,
) {
  final map = <String, Set<String>>{};

  for (final row in bdmRows) {
    final cip7 = row['cip7']?.toString();
    final cip13 = row['cip13']?.toString();

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

/// ─────────────────────────────
/// CIP13 hospitaliers finaux
/// ─────────────────────────────
Set<String> buildHospitalCip13Set(
  Set<String> cip7Hospitaliers,
  Map<String, Set<String>> cip7ToCip13,
) {
  final result = <String>{};

  for (final cip7 in cip7Hospitaliers) {
    final cip13s = cip7ToCip13[cip7];
    if (cip13s != null) {
      result.addAll(cip13s);
    }
  }

  return result;
}

/// Charge les CIP13 PIH (legacy, préférer loadHospitalCipSets).
Future<Set<String>> loadCipPih() async {
  final sets = await loadHospitalCipSets();
  return sets.pihCips;
}

/// Charge les CIP13 sous surveillance particulière (legacy, préférer loadHospitalCipSets).
Future<Set<String>> loadCipSurveillanceParticuliere() async {
  final sets = await loadHospitalCipSets();
  return sets.surveillanceCips;
}

/// Charge la liste des CIP13 hospitaliers depuis CIP hospitaliers.csv (une colonne : en-tête puis un CIP13 par ligne).
/// Utilisé pour le badge « non remboursé » : tout produit qui n'est pas dans cette liste et sans taux (col I CIS_CIP_bdpm) affiche le badge.
Future<Set<String>> loadCip13HospitaliersFromCsv() async {
  final res = await http.get(Uri.parse(CIP_HOSPITALIERS_URL));
  if (res.statusCode != 200) return {};
  final lines = const LineSplitter().convert(res.body);
  final set = <String>{};
  for (final line in lines.skip(1)) {
    final cip13 = line.replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
    if (cip13.length == 13) set.add(cip13);
  }
  return set;
}




