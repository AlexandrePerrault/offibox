import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/config/google_oauth_config.dart';

const _calendarScope = 'https://www.googleapis.com/auth/calendar.readonly';
const _prefsKeyCredentials = 'google_calendar_oauth_credentials';

/// OAuth manuel pour Google Calendar sur Windows/Desktop (où google_sign_in n'est pas supporté).
class GoogleCalendarDesktopAuth {
  GoogleCalendarDesktopAuth._();

  static bool get isNeeded {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static final Uri _authEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
  static final Uri _tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');

  /// Récupère un token d'accès valide (depuis le cache ou via nouveau flux OAuth).
  static Future<String?> getAccessToken() async {
    if (!isNeeded) return null;
    if (!await GoogleOAuthConfig.isConfigured) return null;

    final clientId = await GoogleOAuthConfig.clientId;
    final clientSecret = await GoogleOAuthConfig.clientSecret;
    if (clientId == null || clientSecret == null) return null;

    final credentials = await _loadStoredCredentials();
    if (credentials != null) {
      if (credentials.isExpired && credentials.refreshToken != null) {
        try {
          final refreshed = await credentials.refresh(
            identifier: clientId,
            secret: clientSecret,
          );
          await _storeCredentials(refreshed);
          return refreshed.accessToken;
        } catch (_) {
          await _clearStoredCredentials();
        }
      } else if (!credentials.isExpired) {
        return credentials.accessToken;
      }
    }

    return null;
  }

  /// Lance le flux OAuth (ouvre le navigateur, écoute localhost).
  static Future<String?> signIn() async {
    if (!isNeeded) return null;
    if (!await GoogleOAuthConfig.isConfigured) return null;

    final clientId = await GoogleOAuthConfig.clientId;
    final clientSecret = await GoogleOAuthConfig.clientSecret;
    if (clientId == null || clientSecret == null) return null;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse('http://localhost:${server.port}');

    final grant = oauth2.AuthorizationCodeGrant(
      clientId,
      _authEndpoint,
      _tokenEndpoint,
      secret: clientSecret,
    );

    final authUrl = grant.getAuthorizationUrl(redirectUri, scopes: [_calendarScope]);

    launchUrl(authUrl, mode: LaunchMode.externalApplication);

    final request = await server.first;
    final uri = request.uri;
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Offibox - Agenda connecté</title></head>
<body style="font-family:system-ui;padding:2rem;text-align:center;">
  <h2 style="color:#5A9094;">✅ Connexion réussie</h2>
  <p>Vous pouvez fermer cette fenêtre et revenir à Offibox.</p>
</body></html>''');
    await request.response.close();
    await server.close();

    if (uri.queryParameters.containsKey('error')) {
      return null;
    }

    final client = await grant.handleAuthorizationResponse(uri.queryParameters);
    await _storeCredentials(client.credentials);
    return client.credentials.accessToken;
  }

  static Future<void> signOut() async {
    await _clearStoredCredentials();
  }

  static Future<oauth2.Credentials?> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKeyCredentials);
      if (json == null) return null;
      return oauth2.Credentials.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _storeCredentials(oauth2.Credentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyCredentials, credentials.toJson());
  }

  static Future<void> _clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyCredentials);
  }

}
