import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

/// Données d'authentification Google (unifiées pour Firebase et Calendar).
class GoogleAuthCredentialData {
  const GoogleAuthCredentialData({
    required this.accessToken,
    this.idToken,
  });

  final String accessToken;
  final String? idToken;

  OAuthCredential get firebaseCredential => GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
}

/// Instance unique de Google Sign-In.
/// Sur Windows/Linux : non supporté par google_sign_in → bouton masqué.
/// Sur Android/iOS/Web/macOS : utilise google_sign_in.
class OffiboxGoogleSignIn {
  OffiboxGoogleSignIn._();

  static const _scopes = [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  static GoogleSignIn? _instance;

  static GoogleSignIn get _gs => _instance ??= GoogleSignIn(scopes: _scopes);

  /// Connexion Google.
  static Future<GoogleAuthCredentialData?> signIn() async {
    if (!isAvailable) return null;
    try {
      final user = await _gs.signIn();
      if (user == null) return null;
      final auth = await user.authentication;
      if (auth.accessToken == null || auth.accessToken!.isEmpty) return null;
      return GoogleAuthCredentialData(
        accessToken: auth.accessToken!,
        idToken: auth.idToken,
      );
    } catch (_) {
      return null;
    }
  }

  /// Connexion silencieuse (sans interaction utilisateur).
  static Future<GoogleAuthCredentialData?> signInSilently() async {
    if (!isAvailable) return null;
    try {
      final user = await _gs.signInSilently();
      if (user == null) return null;
      final auth = await user.authentication;
      if (auth.accessToken == null || auth.accessToken!.isEmpty) return null;
      return GoogleAuthCredentialData(
        accessToken: auth.accessToken!,
        idToken: auth.idToken,
      );
    } catch (_) {
      return null;
    }
  }

  /// Indique si la connexion Google est disponible.
  /// google_sign_in ne supporte pas Windows ni Linux.
  static bool get isAvailable {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.linux;
  }
}
