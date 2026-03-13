import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/firebase_options.dart';

/// Point d'entrée web : même app que le desktop (barre + recherche + offiboxdata), avec stubs pour window_manager et dart:io.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    const ProviderScope(
      child: OffiboxApp(),
    ),
  );
}
