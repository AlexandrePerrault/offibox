import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefix = 'espace_pro_';

/// Stocke et récupère les identifiants Espace pro par URL (pour "Se souvenir de moi").
class EspaceProCredentials {
  static String _key(String url) {
    final normalized = url
        .replaceAll(RegExp(r'\?.*'), '')
        .replaceAll(RegExp(r'/$'), '')
        .trim();
    return '$_prefix${normalized.hashCode.abs()}';
  }

  static Future<void> save(String url, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(url),
      jsonEncode({'email': email, 'password': password}),
    );
  }

  static Future<({String email, String password})?> load(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(url));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final email = map['email'] as String? ?? '';
      final password = map['password'] as String? ?? '';
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(url));
  }
}
