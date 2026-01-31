import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalCache {
  static const String _fileName = 'offibox_cache.csv';
  static const Duration maxAge = Duration(hours: 12);

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<bool> exists() async {
    final f = await _getFile();
    return f.existsSync();
  }

  static Future<bool> isExpired() async {
    final f = await _getFile();
    if (!f.existsSync()) return true;

    final age = DateTime.now().difference(f.lastModifiedSync());
    return age > maxAge;
  }

  static Future<String?> read() async {
    final f = await _getFile();
    if (!f.existsSync()) return null;
    return f.readAsString();
  }

  static Future<void> write(String content) async {
    final f = await _getFile();
    await f.writeAsString(content, flush: true);
  }
}
