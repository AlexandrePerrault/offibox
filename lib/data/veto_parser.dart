import 'dart:convert'; // LineSplitter
import 'package:http/http.dart' as http;
import '../models/veto_item.dart';
import 'offiboxdata_fetch.dart';

/// ─────────────────────────────────────────────
/// 🧼 Nettoyage strict des libellés vétérinaires
/// ─────────────────────────────────────────────
String cleanVetoLabel(String raw) {
  return raw
      // caractères corrompus
      .replaceAll('\uFFFD', '')

      // pictogramme éventuel
      .replaceAll('🐾', '')

      // guillemets & apostrophes
      .replaceAll('"', '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll("'", '')

      // suppression du préfixe VETO (le badge VETO est affiché en ligne 1)
      .replaceAllMapped(
        RegExp(r'^\s*\(?\s*VETO\s*\)?\s*', caseSensitive: false),
        (_) => '',
      )

      // espaces multiples
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// ─────────────────────────────────────────────
/// 🐾 PARSER VÉTÉRINAIRE
/// ─────────────────────────────────────────────
Future<List<VetoItem>> parseVeto(String url) async {
  final response = await OffiboxDataFetch.get(url);
  if (response.statusCode != 200) return const [];

  final lines = const LineSplitter().convert(response.body);
  final result = <VetoItem>[];

  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length < 2) continue;

    final label = cleanVetoLabel(row[0]);
    if (label.isEmpty) continue;

    // ✅ GTIN / CIP13 : chiffres uniquement
    final gtin = row[1].replaceAll(RegExp(r'\D'), '');
    if (gtin.isEmpty) continue;

    // ✅ URL RCP (optionnelle, mais rendue non-nullable)
    final rcpUrl = row.length > 2
        ? row[2].replaceAll('"', '').trim()
        : '';

    result.add(
      VetoItem(
        label: label,
        cip13: gtin,
        url: rcpUrl, // ✅ toujours String
      ),
    );
  }

  return result;
}
