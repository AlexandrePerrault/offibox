import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PdfCacheService {
  static Future<File> getCachedPdf({
    required String pdfUrl,
    required String supplier,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final supplierDir =
        Directory('${tempDir.path}/offibox/pdf/$supplier');

    if (!supplierDir.existsSync()) {
      supplierDir.createSync(recursive: true);
    }

    final fileName = pdfUrl.split('/').last;
    final file = File('${supplierDir.path}/$fileName');

    if (file.existsSync()) {
      return file; // ✅ déjà en cache
    }

    final response = await http.get(Uri.parse(pdfUrl));

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Erreur téléchargement PDF');
    }
  }
}
