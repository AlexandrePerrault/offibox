import 'dart:io';
import 'dart:convert';

class HttpClientHelper {
  static Future<String> get(Uri uri) async {
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Erreur HTTP ${response.statusCode}');
    }

    return utf8.decode(await response.expand((e) => e).toList());
  }
}
