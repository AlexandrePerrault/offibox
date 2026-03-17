// ignore_for_file: avoid_print
/// Met à jour lib/generated/annuaire_ps_count.dart avec le nombre de professionnels
/// via l'API FHIR Annuaire Santé (interop.esante.gouv.fr/ig/fhir/annuaire — plus rapide).
/// Appelé par build_msi.ps1 avant le build Windows.
/// L'app recalcule aussi ce nombre au plus une fois par mois via l'API (voir annuaire_ps_count_service.dart).
/// Clé API : définir la variable d'environnement ESANTE_API_KEY (ou --dart-define=ESANTE_API_KEY=xxx pour l'app).
/// En cas d'échec réseau ou API, on conserve la valeur existante ou 0.
library;

import 'dart:convert';
import 'dart:io';

const String fhirBase = 'https://gateway.api.esante.gouv.fr/fhir/v2';
const String outPath = 'lib/generated/annuaire_ps_count.dart';

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

/// Appel API FHIR Annuaire Santé : GET Practitioner?_count=1 → Bundle.total.
Future<int> fetchCountFromFhir() async {
  final apiKey = Platform.environment['ESANTE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('Annuaire PS: ESANTE_API_KEY non définie, skip appel FHIR');
    return 0;
  }

  final uri = Uri.parse('$fhirBase/Practitioner').replace(
    queryParameters: {'_count': '1', 'active': 'true'},
  );
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set('ESANTE-API-KEY', apiKey);
    req.headers.set('Accept', 'application/fhir+json');
    final res = await req.close();
    if (res.statusCode != 200) return 0;
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>?;
    if (json == null || json['resourceType'] != 'Bundle') return 0;
    final total = json['total'];
    if (total is int && total > 0) return total;
    return 0;
  } catch (e) {
    print('Annuaire PS: $e');
    return 0;
  } finally {
    client.close();
  }
}

void main() async {
  int count = 0;
  try {
    count = await fetchCountFromFhir();
  } catch (e) {
    print('Annuaire PS: $e');
  }

  // Sécurité : si l'API renvoie 0 (échec, clé absente, réseau…),
  // on conserve l'ancienne valeur si elle existe.
  if (count <= 0) {
    final existing = await _readExistingCountIfAny();
    if (existing != null && existing > 0) {
      print(
          'Annuaire PS: API a renvoyé 0, conservation de la valeur existante $existing');
      count = existing;
    } else {
      print(
          'Annuaire PS: API indisponible ou ESANTE_API_KEY absente, aucune valeur existante → utilisation de 0');
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
