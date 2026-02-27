import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32_registry/win32_registry.dart';

import 'package:window_manager/window_manager.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/offibox_app.dart';
import 'cache/hive_cache.dart';
import 'system/windows_autostart.dart';
import 'package:offibox/system/window_position.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // pdfrx : init explicite requise. Sur Windows, le mode Développeur peut être requis pour le build (symlinks).
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);

  await windowManager.ensureInitialized();

  // Fenêtre visible tout de suite en position sûre (avant Firebase/runApp) pour éviter fenêtre invisible
  if (Platform.isWindows) {
    await WindowPosition.ensureVisibleAtStartup();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enregistrement du schéma offibox:// pour la « Connexion Windows » (auth via site → redirect offibox://auth/callback)
  if (Platform.isWindows) {
    await protocolHandler.register('offibox');
  }

  // Répertoire local (ex. AppData/Local) pour éviter conflits de verrou avec OneDrive/Documents
  final hiveDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(hiveDir.path);
  await HiveCache.instance.init();

  // Auto-start : activé si l'installateur l'a choisi OU si déjà activé avant
  if (Platform.isWindows && const bool.fromEnvironment('dart.vm.product')) {
    _applyAutostartFromInstaller();
  }

  runApp(
    const ProviderScope(
      child: OffiboxApp(),
    ),
  );

  // Puis restaure position sauvegardée (si valide) et applique frameless
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WindowPosition.restoreAndListen();
    });
  }
}

/// Lit le choix de l'installateur (lancement au démarrage) et active/désactive.
void _applyAutostartFromInstaller() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: r'SOFTWARE\Offibox',
      desiredAccessRights: AccessRights.readOnly,
    );
    final val = key.getValue('LaunchAtStartup');
    key.close();
    if (val != null && val.toString().contains('1')) {
      WindowsAutostart.enable();
      await prefs.setBool('autostart_enabled', true);
      final keyW = Registry.openPath(
        RegistryHive.currentUser,
        path: r'SOFTWARE\Offibox',
        desiredAccessRights: AccessRights.allAccess,
      );
      keyW.deleteValue('LaunchAtStartup');
      keyW.close();
      return;
    }
  } catch (_) {}
  // Pas de flag installateur : garder le choix existant (upgrade) ou ne pas activer (nouvelle install sans coche)
  if (prefs.getBool('autostart_enabled') == true) {
    WindowsAutostart.enable();
  }
}
