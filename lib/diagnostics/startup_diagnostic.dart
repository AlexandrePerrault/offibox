import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;
import 'package:offibox/window/window_manager_stub.dart' if (dart.library.io) 'package:window_manager/window_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Diagnostic de démarrage (logo grisé, barre ne se déploie pas).
/// Affiché dans la console uniquement en mode debug (flutter run).
/// À appeler après le premier frame (ex. postFrameCallback + délai).
class StartupDiagnostic {
  StartupDiagnostic._();

  static const String _logoAsset = 'assets/icons/logo_offibox.png';

  /// Lance le diagnostic complet et affiche un bloc dans la console.
  static Future<void> run() async {
    if (!kDebugMode) return;

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════╗');
    buffer.writeln('║  DIAGNOSTIC DÉMARRAGE OFFIBOX (logo / barre ne se déploie pas)   ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════════╝');
    buffer.writeln();

    // 1. Mode & plateforme
    buffer.writeln('── Environnement ──');
    buffer.writeln('  kDebugMode     : $kDebugMode');
    buffer.writeln('  kReleaseMode   : $kReleaseMode');
    try {
      if (Platform.isWindows) {
        buffer.writeln('  Plateforme    : Windows');
      } else if (Platform.isLinux) {
        buffer.writeln('  Plateforme    : Linux');
      } else if (Platform.isMacOS) {
        buffer.writeln('  Plateforme    : macOS');
      } else {
        buffer.writeln('  Plateforme    : autre / Web');
      }
    } catch (_) {
      buffer.writeln('  Plateforme    : (indéterminée)');
    }
    buffer.writeln();

    // 2. Fenêtre (Windows)
    try {
      if (!identical(Platform, null) && (Platform.isWindows || Platform.isLinux)) {
        buffer.writeln('── Fenêtre ──');
        try {
          final size = await windowManager.getSize();
          buffer.writeln('  Taille        : ${size.width} x ${size.height}');
        } catch (e) {
          buffer.writeln('  Taille        : ERREUR $e');
        }
        try {
          final pos = await windowManager.getPosition();
          buffer.writeln('  Position      : (${pos.dx}, ${pos.dy})');
        } catch (e) {
          buffer.writeln('  Position      : ERREUR $e');
        }
        buffer.writeln();
      }
    } catch (_) {
      buffer.writeln('  Fenêtre       : (non disponible)');
      buffer.writeln();
    }

    // 3. Auth Firebase
    buffer.writeln('── Auth Firebase ──');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        buffer.writeln('  currentUser   : null → écran de CONNEXION (AuthGate avec LoginPage)');
        buffer.writeln('  → La barre est en mode pill ; cliquer sur le logo pour déployer.');
      } else {
        buffer.writeln('  currentUser   : ${user.uid} (${user.email ?? "sans email"})');
        buffer.writeln('  → Si vous voyez WindowsPreloadWrapper : splash ~12s puis barre.');
      }
    } catch (e) {
      buffer.writeln('  currentUser   : ERREUR $e');
    }
    buffer.writeln();

    // 4. Asset logo (cause possible du logo gris)
    buffer.writeln('── Asset logo (logo gris si échec) ──');
    try {
      await rootBundle.load(_logoAsset);
      buffer.writeln('  $_logoAsset : OK (chargé)');
    } catch (e) {
      buffer.writeln('  $_logoAsset : ÉCHEC → le logo peut s''afficher gris ou en fallback icône.');
      buffer.writeln('  Erreur : $e');
    }
    buffer.writeln();

    // 5. Rappels
    buffer.writeln('── Pistes si logo gris / barre ne se déploie pas ──');
    buffer.writeln('  1. Si "Asset logo : ÉCHEC" ci‑dessus → vérifier pubspec.yaml assets et rebuild.');
    buffer.writeln('  2. Si currentUser = null → vous êtes sur l\'écran de connexion ; cliquer sur le pill (logo) pour déployer.');
    buffer.writeln('  3. Si la fenêtre est en 0x0 ou hors écran → bug position ; vérifier WindowPosition / restoreAndListen.');
    buffer.writeln('  4. Si clic sur le logo ne fait rien → vérifier clearWindowRegion (Windows) et que la fenêtre a le focus.');
    buffer.writeln();

    debugPrint(buffer.toString());
  }

  static bool _authGateLogged = false;

  /// À appeler depuis AuthGate au premier build (debug uniquement).
  /// [expanded] état déployé de la barre, [windowSizeSynced] taille fenêtre synchronisée.
  static void logAuthGateState({
    required bool expanded,
    required bool windowSizeSynced,
    required String authLabel,
  }) {
    if (!kDebugMode || _authGateLogged) return;
    _authGateLogged = true;
    debugPrint(
      '[Diagnostic AuthGate] expanded=$expanded windowSizeSynced=$windowSizeSynced authLabel=$authLabel',
    );
  }
}
