import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../model/lpp_entry.dart';

class LppRepository {
  static Future<List<LppEntry>> loadFromGithub() async {
    final url = Uri.parse(
      'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/codes_lpp_ameli.csv',
    );

    final response = await http.get(url);
    final csvData = const CsvToListConverter().convert(response.body);

    return csvData.skip(1).map((row) {
      final code =
          RegExp(r'\d{7}').firstMatch(row[0].toString())!.group(0)!;
      return LppEntry(code: code, url: row[1].toString());
    }).toList();
  }
}
