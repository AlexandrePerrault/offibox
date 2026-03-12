import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:protocol_handler/protocol_handler.dart';

import 'package:window_manager/window_manager.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:offibox/config/app_config.dart';
import 'app/offibox_app.dart';
import 'cache/hive_cache.dart';
import 'package:offibox/system/window_position.dart';
import 'firebase_options.dart';

// Import conditionnel : Windows (registre + autostart) vs Linux/macOS (stub). Build Windows : flutter build windows --dart-define=FLUTTER_BUILD_WINDOWS=true
import 'system/installer_autostart_stub.dart' if (AppConfig.flutterBuildWindows) 'system/installer_autostart_windows.dart' as installer_autostart;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Charger les polices Google (ex. Spinnaker) depuis le réseau pour éviter "Unable to load asset: AssetManifest.bin"
  GoogleFonts.config.allowRuntimeFetching = true;

  if (Platform.isWindows) {
    // pdfrx : init explicite requise. Sur Windows, le mode Développeur peut être requis pour le build (symlinks).
    await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
    await windowManager.ensureInitialized();
    await windowManager.setTitle(AppConfig.appName);
    await WindowPosition.ensureVisibleAtStartup();
  }
  if (Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle(AppConfig.appName);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Au démarrage Windows : exiger identifiant/mot de passe (pas de session persistée entre les lancements).
  if (Platform.isWindows) {
    await FirebaseAuth.instance.signOut();
  }
  // Sur Windows, le plugin firebase_auth peut afficher des erreurs "channel sent a message from
  // native to Flutter on a non-platform thread" (auth-state, id-token). Problème connu FlutterFire
  // (issue #13340). L'app utilise un polling pour l'auth sur Windows pour limiter l'impact.

  // Règles d'or Firestore : 1) Ne jamais écouter une collection entière (toujours .doc(uid).snapshots())
  // 2) Cache offline pour limiter les relectures serveur 3) Éviter les rebuild inutiles → préférer Riverpod/Provider
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Enregistrement du schéma offibox:// pour la « Connexion Windows » (auth via site → redirect offibox://auth/callback)
  if (Platform.isWindows) {
    await protocolHandler.register('offibox');
  }

  // Répertoire local (ex. AppData/Local) pour éviter conflits de verrou avec OneDrive/Documents
  final hiveDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(hiveDir.path);
  await HiveCache.instance.init();

  // Auto-start Windows : activé si l'installateur MSI l'a choisi OU si déjà activé avant
  if (Platform.isWindows && const bool.fromEnvironment('dart.vm.product')) {
    installer_autostart.applyFromInstaller();
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
