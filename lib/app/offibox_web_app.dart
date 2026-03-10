import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/auth/login_page.dart';

/// Application web minimale : uniquement login + ecran Connecte.
/// N'importe pas OffiboxApp / AuthGate / OffiboxWindow pour eviter les fichiers manquants sur certaines branches.
class OffiboxWebApp extends StatelessWidget {
  const OffiboxWebApp({super.key});

  static const Color offiboxTeal = Color(0xFF5A9094);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offibox',
      theme: ThemeData(
        useMaterial3: false,
        textTheme: GoogleFonts.spinnakerTextTheme(),
        fontFamily: GoogleFonts.spinnaker().fontFamily,
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
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F1),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Vous etes connecte a Offibox (version web).',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
