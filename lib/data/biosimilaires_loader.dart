import 'package:http/http.dart' as http;
import 'package:offibox/utils/normalize.dart';

/// CSV biosimilaires 2026 — chargé depuis [offiboxdata](https://github.com/AlexandrePerrault/offiboxdata).
///
/// **Format attendu pour que la colonne Conditions (col E) soit entièrement lue :**
/// - Séparateur : `;` (recommandé) ou `,`.
/// - Toute cellule contenant des retours à la ligne doit être entourée de guillemets doubles.
/// - Un guillemet à l’intérieur d’une cellule s’écrit `""`.
/// Exemple : `"...";"34009...";"- Point 1,\n- Point 2"` pour que tout le texte Conditions s’affiche au clic sur le badge « Infos dispensation ».
const String _biosimilaires2026Url =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/biosimilaires%202026.csv';

/// Détecte le séparateur (; ou ,) : fichier type GitHub = champs entre guillemets + ";"
String _detectSeparator(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('"') && trimmed.contains('";"')) return ';';
  return ',';
}

/// Parse un CSV complet en gérant les champs entre guillemets sur plusieurs lignes (RFC 4180).
/// Retourne une liste de lignes, chaque ligne = liste de champs.
List<List<String>> _parseCsvFull(String body, String separator) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final buffer = StringBuffer();
  var i = 0;
  var inQuotes = false;
  const quote = '"';

  while (i < body.length) {
    final c = body[i];

    if (inQuotes) {
      if (c == quote) {
        if (i + 1 < body.length && body[i + 1] == quote) {
          buffer.write(quote);
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      buffer.write(c);
      i++;
      continue;
    }

    if (c == quote) {
      inQuotes = true;
      i++;
      continue;
    }

    if (c == separator) {
      currentRow.add(buffer.toString().trim());
      buffer.clear();
      i++;
      continue;
    }

    if (c == '\n' || c == '\r') {
      currentRow.add(buffer.toString().trim());
      buffer.clear();
      if (currentRow.any((f) => f.isNotEmpty)) {
        rows.add(List.from(currentRow));
      }
      currentRow.clear();
      if (c == '\r' && i + 1 < body.length && body[i + 1] == '\n') i++;
      i++;
      continue;
    }

    buffer.write(c);
    i++;
  }

  currentRow.add(buffer.toString().trim());
  if (currentRow.any((f) => f.isNotEmpty)) {
    rows.add(List.from(currentRow));
  }
  return rows;
}

/// biosimilaireByCip :
/// CIP13 (col D) → PRINCEPS normalisé (col B)
Future<Map<String, String>> loadBiosimilairesByCip() async {
  final response = await http.get(Uri.parse(_biosimilaires2026Url));
  if (response.statusCode != 200) return {};

  final body = response.body;
  if (body.trim().isEmpty) return {};

  final separator = _detectSeparator(body);
  final rows = _parseCsvFull(body, separator);
  final Map<String, String> map = {};

  for (var r = 1; r < rows.length; r++) {
    final cols = rows[r];
    if (cols.length < 4) continue;

    final princepsRaw = cols[1].replaceAll('"', '').trim();
    final cip13 = cols[3].replaceAll(RegExp(r'\D'), '');

    if (princepsRaw.isEmpty || cip13.length != 13) continue;

    final princepsNormalized = normalizePrincepsName(princepsRaw);
    map[cip13] = princepsNormalized;
  }

  return map;
}

/// CIP13 (col D, index 3) → contenu colonne 5 (index 4) pour fenêtre « Infos dispensation » (badge, affichage avec puces).
/// Les cellules de la colonne Conditions (col E) peuvent contenir des retours à la ligne ; elles sont entièrement lues.
Future<Map<String, String>> loadBiosimilairesInfoByCip() async {
  final response = await http.get(Uri.parse(_biosimilaires2026Url));
  if (response.statusCode != 200) return {};

  final body = response.body;
  if (body.trim().isEmpty) return {};

  final separator = _detectSeparator(body);
  final rows = _parseCsvFull(body, separator);
  final Map<String, String> map = {};

  for (var r = 1; r < rows.length; r++) {
    final cols = rows[r];
    if (cols.length < 5) continue;

    final cip13 = cols[3].replaceAll(RegExp(r'\D'), '');
    final col5 = cols[4]
        .replaceAll('"', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (cip13.length != 13 || col5.isEmpty) continue;

    map[cip13] = normalizeText(col5);
  }

  return map;
}

/// 🔧 normalisation métier PRINCEPS
String normalizePrincepsName(String label) {
  return label
      .toUpperCase()
      .split(',').first
      .split(' - ').first
      .replaceAll(RegExp(r'\b\d+.*'), '')
      .trim();
}
