// lib/data/exception_otc_loader.dart
//
// Exception : medicaments d'exception.csv (offiboxdata) — col 0 = CIP13, col 1 = libellé.
// OTC : optionnel exception_otc_2026.csv avec Type = "otc", ou BDM (Libre-accès / (OTC)).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';

/// Ensembles CIP13 pour les badges EXCEPTION et OTC/autre en ligne 1.
class ExceptionOtcSets {
  const ExceptionOtcSets({
    required this.exceptionCips,
    required this.otcCips,
  });
  final Set<String> exceptionCips;
  final Set<String> otcCips;
}

/// Charge les médicaments d'exception depuis medicaments d'exception.csv (toutes les lignes = exception)
/// et optionnellement OTC depuis exception_otc_2026.csv (Type = "otc").
Future<ExceptionOtcSets> loadExceptionOtcSets() async {
  final exceptionCips = <String>{};
  final otcCips = <String>{};

  // 1) Exception : https://github.com/AlexandrePerrault/offiboxdata/blob/main/medicaments%20d'exception.csv
  final exceptionRes = await http.get(Uri.parse(MEDICAMENTS_EXCEPTION_URL));
  if (exceptionRes.statusCode == 200) {
    final lines = const LineSplitter().convert(exceptionRes.body);
    for (final line in lines) {
      final cols = line.split(';');
      if (cols.isEmpty) continue;
      final cip13 = cols[0].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13.length == 13) exceptionCips.add(cip13);
    }
  }

  // 2) OTC : optionnel (exception_otc_2026.csv avec col 1 = "otc")
  final otcRes = await http.get(Uri.parse(EXCEPTION_OTC_URL));
  if (otcRes.statusCode == 200) {
    final lines = const LineSplitter().convert(otcRes.body);
    for (final line in lines) {
      final cols = line.split(';');
      if (cols.length < 2) continue;
      final cip13 = cols[0].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13.length != 13) continue;
      final type = cols[1].replaceAll('"', '').trim().toLowerCase();
      if (type == 'otc') otcCips.add(cip13);
    }
  }

  return ExceptionOtcSets(exceptionCips: exceptionCips, otcCips: otcCips);
}
