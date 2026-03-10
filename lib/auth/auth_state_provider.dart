import 'dart:async';
import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream d'auth : une seule souscription pour tout l'app (évite les rebuild inutiles).
/// Sur Windows, authStateChanges() envoie des messages sur un thread non-platform (erreur
/// "firebase_auth_plugin/auth-state" et "id-token" → voir https://github.com/firebase/flutterfire/issues/13340).
/// On utilise un polling (currentUser toutes les 2 s) au lieu du stream natif pour éviter de souscrire au canal.
/// L'erreur peut quand même s'afficher au démarrage (le plugin enregistre des listeners en natif) : bug connu FlutterFire Windows, sans impact fonctionnel.
Stream<User?> _authStream() {
  if (Platform.isWindows) {
    final controller = StreamController<User?>.broadcast();
    Timer? timer;
    void emit() {
      try {
        controller.add(FirebaseAuth.instance.currentUser);
      } catch (_) {}
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!controller.isClosed) emit();
    });
    timer = Timer.periodic(const Duration(seconds: 2), (_) => emit());
    controller.onCancel = () => timer?.cancel();
    return controller.stream;
  }
  return FirebaseAuth.instance.authStateChanges();
}

/// État d'auth (User? ou chargement). Une seule écoute = moins de relectures, rebuild limité aux widgets qui watch.
final authStateProvider = StreamProvider.autoDispose<User?>((ref) => _authStream());
