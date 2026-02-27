import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:offibox/data/data_sources.dart';

/// Info ANSM pour un CIS (rupture, tension, remise à disposition).
class AnsmStatutInfo {
  const AnsmStatutInfo({
    required this.dateMaj,
    required this.dateRemise,
    required this.libelle,
    required this.url,
    required this.isRemise,
  });

  /// Date MAJ (colonne F).
  final String dateMaj;
  /// Date "à partir du" pour Remise à disposition (colonne G).
  final String dateRemise;
  final String libelle;
  final String url;
  final bool isRemise;
}

/// Retourne true si [dateStr] est une date dans les 2 derniers mois (par rapport à aujourd'hui).
/// Accepte YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY.
bool _isDateWithinTwoMonths(String dateStr) {
  final s = dateStr.trim();
  if (s.isEmpty) return false;
  final parts = s.split(RegExp(r'[-/]'));
  if (parts.length < 3) return false;
  int? y, m, day;
  if (parts[0].length == 4) {
    y = int.tryParse(parts[0]);
    m = int.tryParse(parts[1]);
    day = int.tryParse(parts[2]);
  } else {
    y = int.tryParse(parts[2]);
    if (y != null && y < 100) y = y + 2000;
    m = int.tryParse(parts[1]);
    day = int.tryParse(parts[0]);
  }
  if (y == null || m == null || day == null || m < 1 || m > 12 || day < 1 || day > 31) return false;
  final d = DateTime(y, m, day);
  final twoMonthsAgo = DateTime.now().subtract(const Duration(days: 60));
  return !d.isBefore(twoMonthsAgo);
}

/// Charge la map CIS → AnsmStatutInfo depuis le fichier officiel CIS_CIP_Dispo_Spec.txt (BDPM).
/// Ne garde que les lignes dont la date MAJ (col F, index 5) est < 2 mois (ruptures, tension, remises récentes).
/// Séparateur : tabulation ou virgule. Col 0=CIS, 3=libellé, 5=date MAJ, 6=date remise, 7=URL.
Future<Map<String, AnsmStatutInfo>?> loadAnsmStatutsByCisFromBdpmTxt() async {
  try {
    final res = await http.get(Uri.parse(CIS_CIP_DISPO_SPEC_BDPM_TXT_URL))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) return null;

    String body;
    try {
      body = utf8.decode(res.bodyBytes);
    } catch (_) {
      body = latin1.decode(res.bodyBytes);
    }
    if (body.contains('\uFFFD')) {
      body = latin1.decode(res.bodyBytes);
    }

    final lines = body.split(RegExp(r'\r?\n'));
    final sep = body.contains('\t') ? '\t' : ',';
    final map = <String, AnsmStatutInfo>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(sep).map((e) => e.replaceAll('"', '').trim()).toList();
      if (parts.length < 6) continue;

      final dateMaj = parts.length > 5 ? parts[5] : '';
      if (!_isDateWithinTwoMonths(dateMaj)) continue;

      final cisRaw = parts[0].replaceAll(RegExp(r'\D'), '').trim();
      if (cisRaw.isEmpty) continue;
      if (map.containsKey(cisRaw)) continue;

      final libelle = parts.length > 3 ? _normalizeLibelle(parts[3]) : '';
      final dateRemise = parts.length > 6 ? parts[6].trim() : '';
      final url = parts.length > 7 ? parts[7].trim() : '';
      final isRemise = libelle.toLowerCase().contains('remis') &&
          libelle.toLowerCase().contains('disposition');

      map[cisRaw] = AnsmStatutInfo(
        dateMaj: dateMaj,
        dateRemise: dateRemise,
        libelle: libelle,
        url: url.isNotEmpty ? url : 'https://ansm.sante.fr/',
        isRemise: isRemise,
      );
    }

    return map;
  } catch (_) {
    return null;
  }
}

/// Charge la map CIS → AnsmStatutInfo : d'abord depuis le fichier officiel CIS_CIP_Dispo_Spec.txt (ruptures/tension/remises < 2 mois), sinon fallback statutsANSM.csv.
/// Premier enregistrement par CIS conservé.
Future<Map<String, AnsmStatutInfo>> loadAnsmStatutsByCis() async {
  final fromTxt = await loadAnsmStatutsByCisFromBdpmTxt();
  if (fromTxt != null && fromTxt.isNotEmpty) return fromTxt;

  final res = await http.get(Uri.parse(STATUTS_ANSM_URL));
  if (res.statusCode != 200) return {};

  final body = res.body;
  final lines = body.split(RegExp(r'\r?\n'));
  final map = <String, AnsmStatutInfo>{};

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final parts = _parseCsvLine(line);
    if (parts.length < 6) continue;

    final cisRaw = parts[0].replaceAll(RegExp(r'\D'), '').trim();
    if (cisRaw.isEmpty) continue;
    if (map.containsKey(cisRaw)) continue;

    final libelle = parts.length > 3 ? _normalizeLibelle(parts[3]) : '';
    final dateMaj = parts.length > 5 ? parts[5].trim() : '';
    final dateRemise = parts.length > 6 ? parts[6].trim() : '';
    final url = parts.length > 7 ? parts[7].trim() : '';
    final isRemise = libelle.toLowerCase().contains('remis') &&
        libelle.toLowerCase().contains('disposition');

    map[cisRaw] = AnsmStatutInfo(
      dateMaj: dateMaj,
      dateRemise: dateRemise,
      libelle: libelle,
      url: url.isNotEmpty ? url : 'https://ansm.sante.fr/',
      isRemise: isRemise,
    );
  }

  return map;
}

String _normalizeLibelle(String s) {
  return s
      .replaceAll(RegExp(r'Remise\s*\uFFFD?\s*disposition', caseSensitive: false),
          'Remise à disposition',)
      .replaceAll(RegExp(r'Arrt\s+de'), 'Arrêt de')
      .replaceAll('\uFFFD', ' ')
      .trim();
}

List<String> _parseCsvLine(String line) {
  final out = <String>[];
  var i = 0;
  var cell = StringBuffer();
  var inQuotes = false;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
      i++;
    } else if ((ch == ',' && !inQuotes) || ch == '\n') {
      out.add(cell.toString().trim());
      cell = StringBuffer();
      i++;
    } else {
      cell.write(ch);
      i++;
    }
  }
  out.add(cell.toString().trim());
  return out;
}

/// @deprecated Utiliser loadAnsmStatutsByCis() et info.isRemise.
Future<Set<String>> loadCisWithAnsmDispo() async {
  final map = await loadAnsmStatutsByCis();
  return map.entries
      .where((e) => e.value.isRemise)
      .map((e) => e.key)
      .toSet();
}

/// @deprecated Utiliser loadAnsmStatutsByCis() et info.dateMaj.
Future<Map<String, String>> loadAnsmDateByCis() async {
  final map = await loadAnsmStatutsByCis();
  return map.map((k, v) => MapEntry(k, v.dateMaj));
}

/// Info « arrêt de commercialisation » pour un CIS (date + URL depuis CIS_CIP_Dispo_Spec.txt).
class ArretCommercialisationInfo {
  const ArretCommercialisationInfo({
    required this.dateArret,
    required this.url,
  });
  /// Date d'arrêt (ex. 29/12/2025).
  final String dateArret;
  /// URL ANSM à ouvrir au clic sur le badge.
  final String url;
}

/// Charge CIS_CIP_Dispo_Spec.txt et retourne pour chaque CIS avec "arrêt de commercialisation"
/// la date d'arrêt (col 4) et l'URL (col 7). Format exemple : 62533756 \t \t 3 \t Arrêt de commercialisation \t 29/12/2025 \t 06/01/2026 \t \t https://...
Future<Map<String, ArretCommercialisationInfo>> loadArretCommercialisationByCis() async {
  const marker = 'arrêt de commercialisation';
  try {
    final res = await http.get(Uri.parse(CIS_CIP_DISPO_SPEC_BDPM_TXT_URL))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) return _loadArretCommercialisationFallback();

    String body;
    try {
      body = utf8.decode(res.bodyBytes);
    } catch (_) {
      body = latin1.decode(res.bodyBytes);
    }
    final lines = body.split(RegExp(r'\r?\n'));
    final sep = body.contains('\t') ? '\t' : ',';
    final map = <String, ArretCommercialisationInfo>{};
    for (final line in lines) {
      final parts = line.split(sep).map((e) => e.replaceAll('"', '').trim()).toList();
      if (parts.length < 5) continue;
      final libelle = parts[3].toLowerCase();
      if (!libelle.contains('arr') || !libelle.contains('commercialisation')) continue;
      final cis = parts[0].replaceAll(RegExp(r'\D'), '').trim();
      if (cis.length < 7) continue;
      final dateArret = parts.length > 4 ? parts[4] : '';
      var url = parts.length > 7 ? parts[7].trim() : '';
      if (url.isEmpty && parts.length > 6) {
        final p6 = parts[6].trim();
        if (p6.startsWith('http')) url = p6;
      }
      map[cis] = ArretCommercialisationInfo(
        dateArret: dateArret,
        url: url.isNotEmpty ? url : 'https://ansm.sante.fr/disponibilites-des-produits-de-sante/medicaments',
      );
    }
    return map;
  } catch (_) {
    return _loadArretCommercialisationFallback();
  }
}

Future<Map<String, ArretCommercialisationInfo>> _loadArretCommercialisationFallback() async {
  try {
    final res = await http.get(Uri.parse(CIS_CIP_DISPO_SPEC_URL))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return {};

    final body = res.body;
    final lines = body.split(RegExp(r'\r?\n'));
    final map = <String, ArretCommercialisationInfo>{};
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!lower.contains('arr') || !lower.contains('commercialisation')) continue;
      final parts = line.split(';').map((e) => e.replaceAll('"', '').trim()).toList();
      if (parts.length < 6) continue;
      final cis = parts[0].replaceAll(RegExp(r'\D'), '').trim();
      if (cis.length < 7) continue;
      final dateArret = parts.length > 5 ? parts[5] : '';
      final url = parts.length > 7 ? parts[7].trim() : '';
      map[cis] = ArretCommercialisationInfo(
        dateArret: dateArret,
        url: url.isNotEmpty ? url : 'https://ansm.sante.fr/disponibilites-des-produits-de-sante/medicaments',
      );
    }
    return map;
  } catch (_) {
    return {};
  }
}

/// CIS présents dans CIS_CIP_Dispo_Spec avec la mention "arrêt de commercialisation".
/// Préférer [loadArretCommercialisationByCis] pour obtenir date + URL ; ce set sert au filtre NSFP.
Future<Set<String>> loadCisArretCommercialisation() async {
  final map = await loadArretCommercialisationByCis();
  return map.keys.toSet();
}
