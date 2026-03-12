import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/offiboxdata_fetch.dart';
import 'package:offibox/utils/normalize.dart';

/// Charge le CSV composition-bdm (CIS;COMPOSITION), normalise les compositions
/// et retourne une map DCI normalisée → liste de CIS.
/// Permet de lier une molécule tapée (ex. daridorexant) aux CIS, puis via BDM au princeps.
Future<Map<String, List<String>>> loadCompositionBdm() async {
  final response = await OffiboxDataFetch.get(COMPOSITION_BDM_URL);
  if (response.statusCode != 200) return {};

  String decoded;
  try {
    decoded = utf8.decode(response.bodyBytes);
  } catch (_) {
    decoded = latin1.decode(response.bodyBytes);
  }

  final lines = const LineSplitter().convert(decoded);
  final dciToCis = <String, List<String>>{};

  for (final line in lines.skip(1)) {
    final parts = line.split(';');
    if (parts.length < 2) continue;

    final cisRaw = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    if (cisRaw.isEmpty) continue;

    final compositionRaw = parts.sublist(1).join(';').trim();
    if (compositionRaw.isEmpty) continue;

    final composition = normalizeComposition(compositionRaw);
    // Un même CIS peut avoir plusieurs molécules (ex. "PARACÉTAMOL 500 mg + CODÉINE 30 mg")
    final segments = composition.split(RegExp(r'\s+\+\s+'));
    for (final segment in segments) {
      final dci = _extractDciFromComposition(segment.trim());
      if (dci.isEmpty) continue;
      final key = normalizeLoose(dci).replaceAll(' ', '');
      dciToCis.putIfAbsent(key, () => []).add(cisRaw);
    }
  }

  return dciToCis;
}

/// Charge le CSV composition-bdm (CIS;COMPOSITION) et retourne une map CIS → texte de la colonne B.
/// Utilisé pour le badge « composition » en ligne 2 (sauf pour les génériques, CIS en col 4 de génériques 2026).
Future<Map<String, String>> loadCompositionByCis() async {
  final response = await OffiboxDataFetch.get(COMPOSITION_BDM_URL);
  if (response.statusCode != 200) return {};

  String decoded;
  try {
    decoded = utf8.decode(response.bodyBytes);
  } catch (_) {
    decoded = latin1.decode(response.bodyBytes);
  }

  final lines = const LineSplitter().convert(decoded);
  final cisToComposition = <String, String>{};

  for (final line in lines.skip(1)) {
    final parts = line.split(';');
    if (parts.length < 2) continue;

    final cisRaw = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    if (cisRaw.isEmpty) continue;

    final compositionRaw = parts.sublist(1).join(';').trim();
    if (compositionRaw.isEmpty) continue;

    final composition = normalizeComposition(compositionRaw);
    cisToComposition[cisRaw] = composition;
  }

  return cisToComposition;
}

/// Extrait le DCI (molécule) de la chaîne COMPOSITION : tous les mots avant le dosage (chiffre, mg, g, UI, etc.).
String _extractDciFromComposition(String composition) {
  final tokens = composition.split(RegExp(r'\s+'));
  final dciTokens = <String>[];
  for (final t in tokens) {
    if (_looksLikeDosage(t)) break;
    dciTokens.add(t);
  }
  return dciTokens.join(' ').trim();
}

bool _looksLikeDosage(String token) {
  if (token.isEmpty) return false;
  if (RegExp(r'^\d').hasMatch(token)) return true;
  if (RegExp(r'[\d,]').hasMatch(token)) return true;
  const units = ['mg', 'g', 'ml', 'ui', 'u.', 'microgrammes', 'µg', 'dh', 'ch', 'tm', '%'];
  final lower = token.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
  return units.any((u) => lower == u || lower.startsWith(u));
}
