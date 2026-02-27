import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

/// Extrait la ville du nom du centre (ex. "Centre d'Amiens" → "Amiens", "Centre de Clermont-Ferrand" → "Clermont-Ferrand").
String extractVilleFromNom(String nom) {
  final s = nom.trim();
  if (s.isEmpty) return '';
  final rest = s
      .replaceFirst(RegExp(r"^Centre\s+d'", caseSensitive: false), '')
      .replaceFirst(RegExp(r"^Centre\s+de\s+", caseSensitive: false), '')
      .trim();
  if (rest.isEmpty) return '';
  return rest.substring(0, 1).toUpperCase() + rest.substring(1).toLowerCase();
}

/// Retourne true si la ville commence par une voyelle (ou h muet) pour l'élision "d'".
bool _villeStartsWithVowel(String ville) {
  if (ville.isEmpty) return false;
  const vowels = "aeiouyàâäéèêëïîôùûüh";
  return vowels.contains(ville.substring(0, 1).toLowerCase());
}

/// Extrait la ville de l'adresse (ex. "80054 AMIENS CEDEX 1" → "Amiens").
String extractVilleFromAdresse(String adresse) {
  final s = adresse.trim();
  if (s.isEmpty) return '';
  final match = RegExp(r"\d{4,5}\s+([A-Za-zÀ-ÿ\-']+)\s+CEDEX", caseSensitive: false).firstMatch(s);
  if (match != null) {
    final ville = match.group(1) ?? '';
    if (ville.isNotEmpty) {
      return ville.substring(0, 1).toUpperCase() + ville.substring(1).toLowerCase();
    }
  }
  return '';
}

/// Corrige le mojibake courant dans le CSV pharmacovigilance (ex. Besan?on → Besançon, B?timent → Bâtiment).
String _fixCrpvCsvMojibake(String s) {
  if (s.isEmpty) return s;
  return s
      // Villes / noms propres
      .replaceAll('Besan?on', 'Besançon')
      .replaceAll('B?timent', 'Bâtiment')
      .replaceAll('H?pital', 'Hôpital')
      .replaceAll('H?tel', 'Hôtel')
      .replaceAll('Am?lie', 'Amélie')
      .replaceAll('Raba-L?on', 'Raba-Léon')
      .replaceAll('L?on', 'Léon')
      .replaceAll('G?n?ral', 'Général')
      .replaceAll('D?partement', 'Département')
      .replaceAll('M?dicale', 'Médicale')
      .replaceAll('M?decine', 'Médecine')
      .replaceAll('C?te', 'Côte')
      .replaceAll('P?le', 'Pôle')
      .replaceAll('Piti?', 'Pitié')
      .replaceAll('Salp?tri?re', 'Salpêtrière')
      .replaceAll('Mar?chal', 'Maréchal')
      .replaceAll('Tonnell?', 'Tonnellé')
      .replaceAll('Facult?', 'Faculté')
      .replaceAll('Europ?en', 'Européen')
      .replaceAll('n? ', 'n° ')
      .replaceAll(' n? ', ' n° ')
      .replaceAll('B.P. n?', 'B.P. n°')
      .replaceAll('BP n?', 'BP n°')
      .replaceAll('Entr?e', 'Entrée')
      .replaceAll('all?es', 'allées')
      .replaceAll('Vie la sant?', 'Vie la santé')
      .replaceAll('?tage', 'étage');
}

String _getCol(List<dynamic> row, int i) {
  if (row.length <= i) return '';
  final v = row[i];
  final raw = (v is String ? v : v.toString()).replaceAll('"', '').trim();
  return _fixCrpvCsvMojibake(raw);
}

/// CSV : nom (0), adresse_complete (1), tel (2), fax (3), mail (4).
/// Séparateur virgule, champs entre guillemets (format GitHub).
SearchResult fromPharmacovigilanceRow(List<dynamic> row) {
  final nom = normalizeText(_getCol(row, 0));
  final adresse = normalizeAddressForStorage(_getCol(row, 1));
  final tel = _getCol(row, 2);
  final fax = _getCol(row, 3);
  final mail = _getCol(row, 4);

  if (nom.isEmpty) throw StateError('Ligne CRPV sans nom');

  final ville = extractVilleFromNom(nom);
  final displayLabelRaw = ville.isNotEmpty
      ? (_villeStartsWithVowel(ville)
          ? "centre de pharmacovigilance d'${ville.toUpperCase()}"
          : 'centre de pharmacovigilance de ${ville.toUpperCase()}')
      : nom;
  final displayLabel = displayLabelRaw.toUpperCase();

  return SearchResult(
    source: SourceType.pharmacovigilance,
    label: displayLabel,
    labelRaw: nom,
    laboratory: '',
    phone: tel.isNotEmpty ? tel : null,
    fax: fax.isNotEmpty ? fax : null,
    email: mail.isNotEmpty ? mail : null,
    groupLabel: adresse.isNotEmpty ? adresse : null,
  );
}

/// Charge le CSV depuis l'URL (virgule, guillemets).
/// Tente UTF-8 puis Latin-1 si le texte contient des caractères de remplacement (mojibake).
Future<List<SearchResult>> parsePharmacovigilance(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) throw Exception('Erreur HTTP pharmacovigilance');

  var text = utf8.decode(response.bodyBytes, allowMalformed: true);
  if (text.contains('\uFFFD') || (text.contains('?') && text.contains('Besan'))) {
    text = latin1.decode(response.bodyBytes);
  }
  text = text.replaceAll('\uFEFF', '').trim();
  final rows = const CsvToListConverter(
    fieldDelimiter: ',',
    textDelimiter: '"',
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(text);

  final results = <SearchResult>[];
  for (var i = 1; i < rows.length; i++) {
    try {
      results.add(fromPharmacovigilanceRow(rows[i]));
    } catch (_) {}
  }
  return results;
}
