import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/auth/login_page.dart';
import 'package:offibox/ui/screens/web_connected_screen.dart';

/// Application web minimale : login + écran connecté avec barre (mis à jour, licence jusqu'au) et limite 5 connexions.
/// N'importe pas OffiboxApp / AuthGate / OffiboxWindow pour eviter les fichiers manquants sur certaines branches.
/// Spinnaker est chargé via index.html (CDN Google Fonts) pour eviter "Unable to load asset: AssetManifest.bin" avec le package google_fonts.
class OffiboxWebApp extends StatelessWidget {
  const OffiboxWebApp({super.key});

  static const Color offiboxTeal = Color(0xFF5A9094);

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offibox',
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Spinnaker',
        textTheme: baseTheme.textTheme.apply(fontFamily: 'Spinnaker'),
        primaryColor: offiboxTeal,
        colorScheme: ColorScheme.fromSeed(seedColor: offiboxTeal, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFE8F0F1),
      ),
      home: const _WebHome(),
    );
  }
}

class _WebHome extends ConsumerWidget {
  const _WebHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    if (authAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F0F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = authAsync.valueOrNull;
    if (user == null) {
      return const LoginPage();
    }
    return const WebConnectedScreen();
  }
}
