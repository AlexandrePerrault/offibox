import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/offiboxdata_fetch.dart';
import 'package:offibox/utils/normalize.dart';

/// Normalise le libellé STATUT (CSV statut CIS 2026 : ? = é/è/à mal encodé).
/// Couvre : réservé, limitée, délivrance, prescription, spécialistes, etc.
/// On applique d’abord les remplacements spécifiques (pour garder è dans particulière, etc.),
/// puis normalizeText pour le reste (mojibake, espaces).
String _normalizeStatut(String raw) {
  // 1) Corriger les mots avec ? AVANT normalizeText pour garder les bons accents (è pas é)
  // Typo BDPM (CIS_CPD_bdpm.txt) : stuéiants → stupéfiants
  var s = raw
      .replaceAll('stuéiants', 'stupéfiants')
      .replaceAll('stuéiant', 'stupéfiant')
      // réservé / réservée
      .replaceAll('r?serv?e', 'réservée')
      .replaceAll('r?serv?', 'réservé')
      // limitée / limités
      .replaceAll('limit?e', 'limitée')
      .replaceAll('limit?s', 'limités')
      // délivrance, fractionnée
      .replaceAll('d?livrance', 'délivrance')
      .replaceAll('fractionn?e', 'fractionnée')
      .replaceAll('fractionn?s', 'fractionnés')
      // prescription / médecins / spécialistes
      .replaceAll('autoris?s', 'autorisés')
      .replaceAll('sp?cialistes', 'spécialistes')
      .replaceAll('sp?cialiste', 'spécialiste')
      .replaceAll('prescription initiale r?serv?e', 'prescription initiale réservée')
      .replaceAll('prescription r?serv?e', 'prescription réservée')
      .replaceAll('prescription hospitali?re', 'prescription hospitalière')
      .replaceAll('prescription initiale hospitali?re', 'prescription initiale hospitalière')
      .replaceAll('prescription initiale semestrielle r?serv?e', 'prescription initiale semestrielle réservée')
      .replaceAll('prescription limit?e', 'prescription limitée')
      .replaceAll('prescription n?cessitant', 'prescription nécessitant')
      .replaceAll('prescription par un m?decin', 'prescription par un médecin')
      .replaceAll('prescription r?serv?e aux m?decins', 'prescription réservée aux médecins')
      .replaceAll('prescription r?serv?e aux sp?cialistes', 'prescription réservée aux spécialistes')
      .replaceAll('m?decin', 'médecin')
      .replaceAll('m?decins', 'médecins')
      .replaceAll('m?dicament', 'médicament')
      .replaceAll('exer?ant', 'exerçant')
      .replaceAll('?tablissement', 'établissement')
      .replaceAll('? usage', 'à usage')
      .replaceAll('usage int?rieur', 'usage intérieur')
      .replaceAll('trait?s', 'traités')
      .replaceAll('particuli?res', 'particulières')
      .replaceAll('particuli?re', 'particulière')
      .replaceAll('s?curis?e', 'sécurisée')
      .replaceAll('hospitali?re', 'hospitalière')
      .replaceAll('comp?tents', 'compétents')
      .replaceAll('g?n?rale', 'générale')
      .replaceAll('g?rontologie', 'gériatrie')
      .replaceAll('pr?alablement', 'préalablement')
      .replaceAll('l?accord', "l'accord")
      .replaceAll('pr?vention', 'prévention')
      .replaceAll('n?cessitant', 'nécessitant')
      .replaceAll('n?cessaire', 'nécessaire')
      .replaceAll('d?tention', 'détention')
      .replaceAll('dispositions particuli?res', 'dispositions particulières');

  // 2) Placeholders export Excel/CSV
  s = s
      .replaceAll(r'$1é$2er$1ée', 'réservée')
      .replaceAll(r'$1é$2ervé', 'réservé')
      .replaceAll(r'$1é$2uri$1ée', 'sécurisée')
      .replaceAll(RegExp(r'\$1[éèe]\$2uri\$1[éèe]e'), 'sécurisée')
      .replaceAll(RegExp(r'\$1[éèe]\$2er\$1[éèe]e'), 'réservée')
      .replaceAll(RegExp(r'\$1[éèe]\$2erv[éèe]'), 'réservé');

  // 3) Normalisation globale (mojibake, espaces, apostrophes)
  s = normalizeText(s);

  // 4) Rattrapage après normalisation
  s = s
      .replaceAll(RegExp(r'\$1[éèe]\$2er\$1[éèe]e'), 'réservée')
      .replaceAll(RegExp(r'\$1[éèe]\$2erv[éèe]'), 'réservé')
      .replaceAll('éecins', 'médecins')
      .replaceAll('hospitalée', 'hospitalière')
      .replaceAll('coméents', 'compétents')
      .replaceAll('éuriée', 'sécurisée')
      .replaceAll('éuriee', 'sécurisée')
      .replaceAll('DELIVRANCE', 'DÉLIVRANCE')
      .replaceAll(RegExp(r'\s\?\s'), ' à ');
  s = s.replaceAll(RegExp(r'\$\d+'), '').trim();
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Charge le CSV statut CIS (CIS;STATUT), normalise les libellés,
/// retourne une map CIS → liste de STATUT (un même CIS peut avoir plusieurs lignes).
Future<Map<String, List<String>>> loadStatutsByCis() async {
  final res = await OffiboxDataFetch.get(STATUT_CIS_2026_URL);
  if (res.statusCode != 200) return {};

  final body = res.body;
  final lines = body.split(RegExp(r'\r?\n'));
  final map = <String, List<String>>{};

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final parts = line.split(';');
    if (parts.length < 2) continue;

    final cisRaw = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    if (cisRaw.isEmpty) continue;

    final statut = _normalizeStatut(parts[1].trim());
    if (statut.isEmpty) continue;

    map.putIfAbsent(cisRaw, () => []).add(statut);
  }

  return map;
}
