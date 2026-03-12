// ignore_for_file: avoid_print
/// Met à jour lib/generated/annuaire_ps_count.dart avec le nombre de professionnels
/// (Annuaire Santé data.gouv.fr). Appelé par build_msi.ps1 avant le build Windows.
/// L'app recalcule aussi ce nombre au plus une fois par mois via l'API (voir annuaire_ps_count_service.dart).
/// En cas d'échec réseau ou API, on conserve la valeur existante ou 0.

import 'dart:convert';
import 'dart:io';

const String datasetSlug =
    'annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante';
const String apiBase = 'https://www.data.gouv.fr/api/1';
const String outPath = 'lib/generated/annuaire_ps_count.dart';
const String userAgent = 'Offibox-Build/1.0';

/// Essaie de récupérer la valeur actuelle déjà générée dans
/// lib/generated/annuaire_ps_count.dart pour éviter d'écraser
/// un nombre valide par 0 en cas de problème réseau / API.
Future<int?> _readExistingCountIfAny() async {
  try {
    final file = File(outPath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final regex = RegExp(r'kAnnuairePsTotalHorsAppli\s*=\s*(\d+);');
    final match = regex.firstMatch(content);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  } catch (_) {
    return null;
  }
}

/// Appel API data.gouv.fr (aligné avec annuaire_ps_count_service.dart).
/// GET /datasets/?slug=... puis GET /datasets/{id}/ ; extras.total_professionnels ou extras.total_ps.
Future<int> fetchCountFromApi() async {
  final client = HttpClient();
  try {
    final listUri = Uri.parse('$apiBase/datasets/').replace(
      queryParameters: {'slug': datasetSlug},
    );
    final listReq = await client.getUrl(listUri);
    listReq.headers.set('User-Agent', userAgent);
    final listRes = await listReq.close();
    if (listRes.statusCode != 200) return 0;
    final listBody = await listRes.transform(utf8.decoder).join();
    final listJson = jsonDecode(listBody) as Map<String, dynamic>;
    final data = listJson['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) return 0;
    final datasetId = (data.first as Map<String, dynamic>)['id'] as String?;
    if (datasetId == null) return 0;

    final datasetUri = Uri.parse('$apiBase/datasets/$datasetId/');
    final dsReq = await client.getUrl(datasetUri);
    dsReq.headers.set('User-Agent', userAgent);
    final dsRes = await dsReq.close();
    if (dsRes.statusCode != 200) return 0;
    final dsBody = await dsRes.transform(utf8.decoder).join();
    final dsJson = jsonDecode(dsBody) as Map<String, dynamic>;
    final extras = dsJson['extras'] as Map<String, dynamic>?;
    if (extras != null) {
      final total = extras['total_professionnels'] as int?;
      if (total != null && total > 0) return total;
      final totalPs = extras['total_ps'] as int?;
      if (totalPs != null && totalPs > 0) return totalPs;
    }
    return 0;
  } catch (_) {
    return 0;
  } finally {
    client.close();
  }
}

void main() async {
  int count = 0;
  try {
    count = await fetchCountFromApi();
  } catch (e) {
    print('Annuaire PS: $e');
  }

  // Sécurité : si l'API renvoie 0 (échec, 403, changement de schéma…),
  // on conserve l'ancienne valeur si elle existe, plutôt que d'écraser par 0.
  if (count <= 0) {
    final existing = await _readExistingCountIfAny();
    if (existing != null && existing > 0) {
      print(
          'Annuaire PS: API a renvoyé 0, conservation de la valeur existante $existing');
      count = existing;
    } else {
      print(
          'Annuaire PS: API indisponible ou sans total, aucune valeur existante trouvée → utilisation de 0');
    }
  }

  final dir = File(outPath).parent;
  if (!await dir.exists()) await Directory(dir.path).create(recursive: true);
  final content = '''
/// Nombre total de professionnels de santé (hors appli) pour l'À propos. Mis à jour par scripts/update_annuaire_ps_count.dart.
const int kAnnuairePsTotalHorsAppli = $count;
''';
  await File(outPath).writeAsString(content.trimLeft(), flush: true);
  print('Annuaire PS: kAnnuairePsTotalHorsAppli = $count');
  exit(0);
}
