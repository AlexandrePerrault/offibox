import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Parsing et traitement des URLs du schéma `offibox://` (connexion Windows).
///
/// Format attendu pour le callback après auth sur le site :
/// - `offibox://auth/callback?token=XXX` — custom token Firebase (généré côté serveur)
/// - `offibox://auth/callback?id_token=XXX` — ID token (ex. Google) pour signInWithCredential
///
/// Le site offibox.fr redirige vers une de ces URLs après connexion ; l’app desktop
/// reçoit l’URL (une seule instance, fenêtre déjà ouverte) et exécute la connexion Firebase.
class OffiboxProtocolHandler {
  OffiboxProtocolHandler._();

  static const String scheme = 'offibox';
  static const String authCallbackPath = 'auth/callback';

  /// Traite une URL reçue (ex. `offibox://auth/callback?token=...`).
  /// Retourne `true` si l’URL a été reconnue et traitée (auth ou autre).
  static Future<bool> handleUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != scheme) return false;

    final path = uri.path.replaceFirst(RegExp(r'^/'), '').toLowerCase();
    if (path == authCallbackPath) {
      return await _handleAuthCallback(uri);
    }

    return false;
  }

  static Future<bool> _handleAuthCallback(Uri uri) async {
    final token = uri.queryParameters['token'];
    final idToken = uri.queryParameters['id_token'];
    final accessToken = uri.queryParameters['access_token'];

    try {
      if (token != null && token.isNotEmpty) {
        await FirebaseAuth.instance.signInWithCustomToken(token);
        return true;
      }
      if (idToken != null && idToken.isNotEmpty) {
        final cred = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(cred);
        return true;
      }
    } catch (_) {
      rethrow;
    }
    return false;
  }
}
