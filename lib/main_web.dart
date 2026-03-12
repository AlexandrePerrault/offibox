import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:offibox/app/offibox_web_app.dart';
import 'package:offibox/firebase_options.dart';

/// Point d'entrée web : pas de dart:io, Hive, window_manager.
/// Utilise OffiboxWebApp (login + écran connecté) pour ne pas importer les modules desktop manquants sur certaines branches.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Charger les polices depuis le réseau pour éviter "Unable to load asset: AssetManifest.bin" (web ou build incomplet)
  GoogleFonts.config.allowRuntimeFetching = true;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    const ProviderScope(
      child: OffiboxWebApp(),
    ),
  );
}
