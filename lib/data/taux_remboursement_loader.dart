import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';

/// Charge le CSV taux de remboursement (CIS ; taux).
/// Retourne une map CIS (chiffres) → libellé affichable (ex. "65 %").
/// Si l'URL est vide ou le chargement échoue, retourne {}.
Future<Map<String, String>> loadTauxRemboursementByCis() async {
  const url = TAUX_REMBOURSEMENT_CIS_URL;
  if (url.isEmpty) return {};

  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) return {};

  final lines = res.body.split(RegExp(r'\r?\n'));
  final map = <String, String>{};

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final parts = trimmed.split(';');
    if (parts.length < 2) continue;

    final cis = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    if (cis.isEmpty) continue;

    var taux = parts[1].trim();
    if (taux.isEmpty) continue;
    if (!taux.endsWith('%')) taux = '$taux %';
    map[cis] = taux;
  }

  return map;
}
