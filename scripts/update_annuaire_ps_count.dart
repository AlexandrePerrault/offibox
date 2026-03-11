// ignore_for_file: avoid_print
/// Met à jour lib/generated/annuaire_ps_count.dart avec le nombre de professionnels
/// (Annuaire Santé data.gouv.fr). Appelé par build_msi.ps1 avant le build Windows.
/// En cas d'échec réseau ou API, la valeur 0 est utilisée (affichée dans À propos).

import 'dart:convert';
import 'dart:io';

const String datasetSlug =
    'annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante';
const String apiBase = 'https://www.data.gouv.fr/api/1';
const String outPath = 'lib/generated/annuaire_ps_count.dart';

Future<int> fetchCountFromApi() async {
  final client = HttpClient();
  try {
    // Récupérer le dataset par slug
    final listUri = Uri.parse('$apiBase/datasets/').replace(
      queryParameters: {'slug': datasetSlug},
    );
    final listReq = await client.getUrl(listUri);
    listReq.headers.set('User-Agent', 'Offibox-Build/1.0');
    final listRes = await listReq.close();
    if (listRes.statusCode != 200) return 0;
    final listBody = await listRes.transform(utf8.decoder).join();
    final listJson = jsonDecode(listBody) as Map<String, dynamic>;
    final data = listJson['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) return 0;
    final datasetId = (data.first as Map<String, dynamic>)['id'] as String?;
    if (datasetId == null) return 0;

    // Détails du dataset (extras peut contenir un total)
    final datasetUri = Uri.parse('$apiBase/datasets/$datasetId/');
    final dsReq = await client.getUrl(datasetUri);
    dsReq.headers.set('User-Agent', 'Offibox-Build/1.0');
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
    // Sinon estimer via les ressources (nombre de lignes non disponible via API simple)
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
