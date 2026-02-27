import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Configuration OAuth pour Google Calendar sur Windows/Desktop.
///
/// Pour le build MSI (recommandé) :
/// Les credentials sont intégrés au build via config/oauth_credentials.json ou
/// GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET. Le client télécharge le MSI,
/// clique sur "Connecter l'agenda Google" et autorise l'accès au calendrier.
///
/// Pour le dev local : config/oauth_credentials.json ou fichier AppData.
class GoogleOAuthConfig {
  GoogleOAuthConfig._();

  static String? _clientId;
  static String? _clientSecret;
  static bool _loaded = false;

  static Future<void> _loadFromFile() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(path.join(dir.path, 'google_oauth_credentials.json'));
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final map = json.decode(content) as Map<String, dynamic>;
      _clientId = map['client_id'] as String?;
      _clientSecret = map['client_secret'] as String?;
    } catch (_) {
      // Ignorer les erreurs de lecture
    }
  }

  static Future<String?> get clientId async {
    await _loadFromFile();
    const fromEnv = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');
    return fromEnv.isNotEmpty ? fromEnv : _clientId;
  }

  static Future<String?> get clientSecret async {
    await _loadFromFile();
    const fromEnv = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET', defaultValue: '');
    return fromEnv.isNotEmpty ? fromEnv : _clientSecret;
  }

  static Future<bool> get isConfigured async {
    final id = await clientId;
    final secret = await clientSecret;
    return id != null && id.isNotEmpty && secret != null && secret.isNotEmpty;
  }

  /// Chemin du fichier credentials (pour affichage à l'utilisateur).
  static Future<String> get credentialsPath async {
    final dir = await getApplicationSupportDirectory();
    return path.join(dir.path, 'google_oauth_credentials.json');
  }
}
