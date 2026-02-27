import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:offibox/data/data_sources.dart';

/// Clé = "CIS_CIP8" (ex. "1582_64055988"), valeur = "R" (Princeps) ou "G" (Générique).
/// Fichier fic03spe : col 1 = code_spe (CIS), col 2 = CIP8, col 3 = G|R.
Future<Map<String, String>> loadCip13ToFic03Status() async {
  final response = await http.get(Uri.parse(FIC03SPE_TXT_URL));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  final map = <String, String>{};

  for (final line in lines) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) continue;

    final cis = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    final cip8Raw = parts[1].replaceAll(RegExp(r'\D'), '');
    final statut = parts[2].trim().toUpperCase();

    if (cis.isEmpty || cip8Raw.length < 8) continue;
    if (statut != 'R' && statut != 'G') continue;

    final cip8 = cip8Raw.length > 8 ? cip8Raw.substring(0, 8) : cip8Raw.padLeft(8, '0');
    if (cip8.length != 8) continue;

    final key = '${cis}_$cip8';
    map[key] = statut;
  }

  return map;
}

/// Extrait les 8 chiffres « code produit » du CIP13 (positions 2–9, 0-based).
String? cip8FromCip13(String cip13) {
  final digits = cip13.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) return null;
  return digits.substring(2, 10);
}

/// Retourne "R" (Princeps) ou "G" (Générique) pour un résultat BDM, ou null si absent de fic03spe.
String? getFic03StatusForItem(
  String? cis,
  String? cip13,
  Map<String, String>? cisCip8ToFic03,
) {
  if (cisCip8ToFic03 == null || cis == null || cip13 == null) return null;
  final cisKey = cis.replaceAll(RegExp(r'\D'), '').trim();
  final cip8 = cip8FromCip13(cip13.replaceAll(RegExp(r'\D'), ''));
  if (cisKey.isEmpty || cip8 == null) return null;
  return cisCip8ToFic03['${cisKey}_$cip8'];
}
