import 'dart:convert';
import 'package:http/http.dart' as http;

/// CSV officiel : colonne F = CIP7 hospitaliers
const String CIP_HOSPITALIERS_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/stup%C3%A9fiants%2Bhopital%202026.csv';

Future<Set<String>> loadCipHospitaliers() async {
  final res = await http.get(Uri.parse(CIP_HOSPITALIERS_URL));
  if (res.statusCode != 200) return {};

  final lines = const LineSplitter().convert(res.body);

  return lines
      .skip(1) // header
      .map((l) => l.split(';'))
      .where((cols) => cols.length > 5) // colonne F = index 5
      .map((cols) => cols[5].replaceAll('"', '').trim())
      .where((cip7) =>
          cip7.length == 7 &&
          cip7.startsWith('5') &&
          RegExp(r'^\d+$').hasMatch(cip7),
      )
      .toSet();
}
