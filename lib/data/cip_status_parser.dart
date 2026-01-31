import 'dart:convert';
import 'package:http/http.dart' as http;


const int INDEX_USAGE_HOSPITALIER = 131;



Future<Map<String, List<String>>> parseCipStatuts(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return {};

  final lines = const LineSplitter().convert(response.body);
  if (lines.length < 2) return {};

  final sep = lines.first.contains(';') ? ';' : ',';
  final Map<String, List<String>> result = {};

  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;

    final cols = line.split(sep);
    if (cols.length <= INDEX_USAGE_HOSPITALIER) continue;

    final cip = cols.first.replaceAll(RegExp(r'\D'), '');
    if (cip.length != 13) continue;

    // 🔴 LECTURE DIRECTE DE LA COLONNE 131
    final cell =
        cols[INDEX_USAGE_HOSPITALIER].trim().toUpperCase();

    if (cell == 'OUI' || cell == '1' || cell == 'TRUE') {
      result[cip] = ["réservé à l'usage HOSPITALIER"];
    }
  }

  return result;
}
