import 'dart:convert';
import 'package:http/http.dart' as http;

// ⚠️ URL DU CSV CIP HOSPITALIERS
const String CIP_HOSPITALIERS_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CIP%20hospitaliers.csv';

/// Charge la liste officielle des CIP hospitaliers
/// → source UNIQUE de la règle hospitalOnly
Future<Set<String>> loadCipHospitaliers() async {
  final response = await http.get(Uri.parse(CIP_HOSPITALIERS_URL));

  if (response.statusCode != 200) {
    return {};
  }

  final lines = const LineSplitter().convert(response.body);

  return lines
      .map((l) => l.replaceAll('"', '').trim())
      .where(
        (c) => c.length == 13 && RegExp(r'^\d+$').hasMatch(c),
      )
      .toSet();
}
