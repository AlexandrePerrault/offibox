/// Script de vérification quotidienne des sources BDPM officielles.
// ignore_for_file: avoid_print
/// Télécharge CIS_bdpm.txt et CIS_CIP_bdpm.txt, affiche la structure et des exemples de libellés.
///
/// Exécution : depuis la racine du projet Flutter :
///   dart run scripts/check_bdpm_sources.dart
/// ou (si dépendances dans script) :
///   dart run --enable-experiment=non-nullable script scripts/check_bdpm_sources.dart
///
/// À planifier (cron / Task Scheduler) pour une vérification quotidienne.

import 'package:http/http.dart' as http;

const String cisBdpmUrl =
    'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt';
const String cisCipBdpmUrl =
    'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt';

/// Index des colonnes (à vérifier avec le PDF officiel "Contenu et format des fichiers BDPM").
/// CIS_bdpm.txt : pas d'en-tête, séparateur tabulation.
const int cisBdpmColCodeCis = 0;
const int cisBdpmColDenomination = 1;
const int cisBdpmColFormePharmaceutique = 2;

/// CIS_CIP_bdpm.txt : CIS (0), CIP7 (1), libellé (2), statut (3), déclaration (4), date (5), CIP13 (6), agrément (7), taux % (8), prix (9)...
const int cisCipColCis = 0;
const int cisCipColLibelle = 2;
const int cisCipColCip13 = 6;
const int cisCipColTauxRemboursement = 8;

Future<void> main() async {
  print('=== Vérification des sources BDPM ===');
  print('Date: ${DateTime.now().toIso8601String()}');
  print('');

  final cisBody = await _fetch(cisBdpmUrl);
  final cipBody = await _fetch(cisCipBdpmUrl);

  if (cisBody == null || cipBody == null) {
    print('Échec téléchargement. Vérifier les URLs et la connexion.');
    return;
  }

  final cisLines = _lines(cisBody);
  final cipLines = _lines(cipBody);

  print('CIS_bdpm.txt : ${cisLines.length} lignes');
  print('CIS_CIP_bdpm.txt : ${cipLines.length} lignes');
  print('');

  _printStructure(cisLines, 'CIS_bdpm', 3);
  _printStructure(cipLines, 'CIS_CIP_bdpm', 3);

  final cisByCode = _parseCisBdpm(cisLines);
  final cipByCip13 = _parseCisCipBdpm(cipLines);

  print('');
  print('=== Exemples de libellés reconstruits (15 premiers) ===');
  int count = 0;
  for (final entry in cipByCip13.entries) {
    if (count >= 15) break;
    final cip13 = entry.key;
    final cip = entry.value;
    final cisInfo = cisByCode[cip.cis];
    final label = _buildLabel(
      denom: cisInfo?.denom,
      form: cisInfo?.form,
      libellePresentation: cip.libelle,
    );
    final taux = cip.taux?.isNotEmpty == true ? ' | Taux: ${cip.taux}' : '';
    print('$cip13 : $label$taux');
    count++;
  }

  print('');
  print('=== Fin vérification BDPM ===');
}

Future<String?> _fetch(String url) async {
  try {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200) return r.body;
    print('HTTP ${r.statusCode} pour $url');
    return null;
  } catch (e) {
    print('Erreur: $e');
    return null;
  }
}

List<String> _lines(String body) {
  return body.split(RegExp(r'\r?\n')).where((s) => s.trim().isNotEmpty).toList();
}

void _printStructure(List<String> lines, String name, int maxLines) {
  print('--- Structure $name (premières $maxLines lignes, colonnes séparées par |) ---');
  for (var i = 0; i < lines.length && i < maxLines; i++) {
    final cols = lines[i].split('\t');
    final preview = cols.map((c) => c.length > 40 ? '${c.substring(0, 40)}...' : c).join(' | ');
    print('L$i: $preview');
  }
  print('');
}

class _CisInfo {
  final String cis;
  final String denom;
  final String form;
  _CisInfo({required this.cis, required this.denom, required this.form});
}

class _CipInfo {
  final String cis;
  final String cip13;
  final String libelle;
  final String? taux;
  _CipInfo({required this.cis, required this.cip13, required this.libelle, this.taux});
}

Map<String, _CisInfo> _parseCisBdpm(List<String> lines) {
  final map = <String, _CisInfo>{};
  for (final line in lines) {
    final cols = line.split('\t');
    if (cols.length <= cisBdpmColFormePharmaceutique) continue;
    final cis = cols[cisBdpmColCodeCis].replaceAll(RegExp(r'\D'), '').trim();
    if (cis.isEmpty) continue;
    final denom = cols[cisBdpmColDenomination].trim();
    final form = cols[cisBdpmColFormePharmaceutique].trim();
    map[cis] = _CisInfo(cis: cis, denom: denom, form: form);
  }
  return map;
}

Map<String, _CipInfo> _parseCisCipBdpm(List<String> lines) {
  final map = <String, _CipInfo>{};
  for (final line in lines) {
    final cols = line.split('\t');
    if (cols.length <= cisCipColCip13) continue;
    final cis = cols[cisCipColCis].replaceAll(RegExp(r'\D'), '').trim();
    final cip13Raw = cols[cisCipColCip13].replaceAll(RegExp(r'\D'), '').trim();
    if (cip13Raw.length != 13) continue;
    final libelle = cols[cisCipColLibelle].trim();
    final taux = cols.length > cisCipColTauxRemboursement
        ? cols[cisCipColTauxRemboursement].trim()
        : null;
    map[cip13Raw] = _CipInfo(cis: cis, cip13: cip13Raw, libelle: libelle, taux: taux?.isEmpty == true ? null : taux);
  }
  return map;
}

/// Construit un libellé type "Doliprane 1000 mg boîte de 8 comprimés".
/// Combine dénomination (CIS_bdpm) + libellé de présentation (CIS_CIP : forme, quantité).
String _buildLabel({
  String? denom,
  String? form,
  required String libellePresentation,
}) {
  final parts = <String>[];
  if (denom != null && denom.isNotEmpty) parts.add(denom);
  if (form != null && form.isNotEmpty && !(libellePresentation.toLowerCase().contains(form.toLowerCase()))) parts.add(form);
  final lib = libellePresentation.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (lib.isNotEmpty && lib != 'Présentation active' && lib != 'Présentation abrogée') parts.add(lib);
  return parts.isEmpty ? libellePresentation.trim() : parts.join(' - ');
}
