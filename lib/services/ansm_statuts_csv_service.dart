import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:offibox/data/offiboxdata_fetch.dart';

/// Page officielle ANSM disponibilités médicaments (source prioritaire pour la dernière info).
/// Le tableau de la page est équivalent aux données du bouton "Exporter" (XLS) ; si une URL
/// d'export directe (ex. XLS/XLSX) est connue, elle pourra être utilisée en priorité ici.
const String ansmDispoMedicamentsUrl =
    'https://ansm.sante.fr/disponibilites-des-produits-de-sante/medicaments';

/// Construit le slug pour la fiche d'une spécialité (ex. xenpozyme-20-mg-poudre-pour-solution-a-diluer-pour-perfusion-olipudase-alfa).
String _slugForAnsmMedicament(String specialite) {
  if (specialite.trim().isEmpty) return '';
  var s = specialite
      .toLowerCase()
      .replaceAll(' – ', ' ')
      .replaceAll(RegExp(r'\[|\]'), '')
      .replaceAll(',', ' ');
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    'œ': 'oe', 'æ': 'ae',
  };
  for (final e in accents.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ').replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'-+'), '-').trim();
  return s.replaceAll(RegExp(r'^-+|-+$'), '');
}

const String _statutsAnsmCsvUrl =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/statuts%20ansm.csv';

/// Type de statut ANSM (colonne niveau du CSV) pour la couleur d'affichage.
/// 1 = Rupture, 2 = Tension, 3 = Arrêt, 4 = Remise à disposition.
int statusLevelFromLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('rupture')) return 1;
  if (lower.contains('tension')) return 2;
  if (lower.contains('arrêt') || lower.contains('arret')) return 3;
  if (lower.contains('remise')) return 4;
  return 2; // défaut tension
}

/// Couleur selon le type de statut : rouge rupture, orange tension, vert remise, gris arrêt.
Color colorForStatutLevel(int level) {
  switch (level) {
    case 1:
      return const Color(0xFFC62828); // rouge rupture
    case 2:
      return const Color(0xFFE65100); // orange tension
    case 3:
      return const Color(0xFF616161); // gris arrêt
    case 4:
      return const Color(0xFF2E7D32); // vert remise à disposition
    default:
      return const Color(0xFFE65100);
  }
}

/// Dernière info statut ANSM (première ligne de données du CSV statuts ansm) pour la barre d'info.
class AnsmStatutItem {
  const AnsmStatutItem({
    required this.label,
    required this.url,
    required this.statusLevel,
  });

  final String label;
  final String url;
  /// 1=rupture, 2=tension, 3=arrêt, 4=remise
  final int statusLevel;
}

/// Récupère la toute dernière info : d'abord depuis la page ANSM (disponibilités médicaments),
/// sinon depuis le CSV offiboxdata. À consulter 3 fois par jour (7h, 13h, 18h).
class AnsmStatutsCsvService {
  AnsmStatutsCsvService._();

  static Future<AnsmStatutItem?> fetchLast() async {
    // Source prioritaire : page officielle ANSM (équivalent du tableau exporté).
    final fromPage = await _fetchLastFromAnsmPage();
    if (fromPage != null) return fromPage;
    // Fallback : CSV offiboxdata (statuts ansm).
    try {
      final response = await OffiboxDataFetch.get(_statutsAnsmCsvUrl);
      if (response.statusCode != 200) return null;
      return _parseFirstDataRow(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Récupère la première ligne du tableau de la page ANSM disponibilités médicaments.
  static Future<AnsmStatutItem?> _fetchLastFromAnsmPage() async {
    try {
      final response = await http.get(
        Uri.parse(ansmDispoMedicamentsUrl),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101'},
      );
      if (response.statusCode != 200) return null;
      return _parseFirstRowFromHtml(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Parse la première ligne de données du tableau HTML (Statut | Mise à jour | Spécialité | Remise à disposition).
  static AnsmStatutItem? _parseFirstRowFromHtml(String html) {
    // Repérer une ligne de tableau : contient une date jj/mm/aaaa et un type de statut.
    final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
    // Chercher les <td>...</td> dans le premier <tr> de données (après l’en-tête).
    final trRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
    final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true);
    final stripTags = RegExp(r'<[^>]+>');
    String stripHtml(String s) {
      if (s.isEmpty) return s;
      var t = s.replaceAll(stripTags, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.replaceAll('&#039;', "'").replaceAll('&eacute;', 'é').replaceAll('&agrave;', 'à');
    }

    for (final trMatch in trRegex.allMatches(html)) {
      final trContent = trMatch.group(1) ?? '';
      final cells = tdRegex.allMatches(trContent).map((m) => stripHtml(m.group(1) ?? '')).toList();
      if (cells.length < 3) continue;
      final statut = cells[0];
      final dateCell = cells.length > 1 ? cells[1] : '';
      final specialite = cells.length > 2 ? cells[2] : '';
      if (statut.isEmpty || !datePattern.hasMatch(dateCell)) continue;
      final lower = statut.toLowerCase();
      if (!lower.contains('rupture') && !lower.contains('tension') && !lower.contains('arrêt') && !lower.contains('arret') && !lower.contains('remise')) continue;
      final dateMatch = datePattern.firstMatch(dateCell);
      final date = dateMatch?.group(0) ?? dateCell;
      final level = statusLevelFromLabel(statut);
      // Tensions d'approvisionnement : afficher le texte en entier (pas de troncature)
      final label = 'info : ANSM: $statut ($date)${specialite.trim().isNotEmpty ? ' – ${specialite.trim()}' : ''}';
      final slug = _slugForAnsmMedicament(specialite);
      final url = slug.isNotEmpty
          ? '$ansmDispoMedicamentsUrl/$slug'
          : ansmDispoMedicamentsUrl;
      return AnsmStatutItem(
        label: label,
        url: url,
        statusLevel: level,
      );
    }
    return null;
  }

  /// Première ligne de données du CSV = toute dernière info (CSV ordonné du plus récent au plus ancien).
  /// Colonnes : CIS, ?, niveau, libellé statut, date, date, ?, url.
  static AnsmStatutItem? _parseFirstDataRow(String csv) {
    final lines = csv.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    for (final line in lines) {
      final parts = _parseCsvLine(line);
      if (parts.length < 8) continue;
      final url = parts.sublist(7).join(',').trim();
      if (url.isEmpty) continue;
      final levelStr = parts[2].trim();
      final statusLabel = parts[3].trim();
      if (statusLabel.isEmpty) continue;
      final date = parts.length > 5 ? parts[5].trim() : (parts.length > 4 ? parts[4].trim() : '');
      final level = int.tryParse(levelStr) ?? statusLevelFromLabel(statusLabel);
      final label = date.isNotEmpty
          ? 'info : ANSM: $statusLabel ($date)'
          : 'info : ANSM: $statusLabel';
      return AnsmStatutItem(
        label: label,
        url: url,
        statusLevel: level,
      );
    }
    return null;
  }

  /// Découpe une ligne CSV en respectant les champs (pas de split simple si guillemets).
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if ((c == ',' && !inQuotes) || c == '\r') {
        result.add(current.toString());
        current = StringBuffer();
      } else if (c != '\r') {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }
}
