// lib/data/exception_otc_loader.dart
//
// Exception : medicaments d'exception.csv (offiboxdata) — col 0 = CIP13, col 1 = libellé.
// OTC/Libre accès : liste médication officinale ANSM (CIP13 col D du XLS), CSV exporté = liste_medication_officinale_cip13.csv.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/offiboxdata_fetch.dart';

/// Ensembles CIP13 pour les badges EXCEPTION et OTC/Libre accès en ligne 1.
class ExceptionOtcSets {
  const ExceptionOtcSets({
    required this.exceptionCips,
    required this.otcCips,
  });
  final Set<String> exceptionCips;
  final Set<String> otcCips;
}

/// Charge les médicaments d'exception depuis medicaments d'exception.csv (toutes les lignes = exception)
/// et les CIP13 OTC/Libre accès depuis la liste médication officinale (CSV export col D du XLS ANSM).
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

  // 2) OTC/Libre accès : liste médication officinale ANSM (CIP13 = col D du XLS, exporté en CSV)
  final otcRes = await OffiboxDataFetch.get(LISTE_MEDICATION_OFFICINALE_CIP13_URL);
  if (otcRes.statusCode == 200 && otcRes.body.trim().isNotEmpty) {
    final lines = const LineSplitter().convert(otcRes.body);
    for (final line in lines) {
      final cols = line.split(RegExp(r'[;\t,]'));
      if (cols.isEmpty) continue;
      final cip13 = cols[0].replaceAll('"', '').trim().replaceAll(RegExp(r'\D'), '');
      if (cip13.length == 13) otcCips.add(cip13);
    }
  }

  return ExceptionOtcSets(exceptionCips: exceptionCips, otcCips: otcCips);
}
