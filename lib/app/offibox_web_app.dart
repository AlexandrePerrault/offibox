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
    // Mode test : ?test=1 ou ?bypass_login=1 dans l'URL → afficher l'écran connecté sans login
    final bypassLogin = Uri.base.queryParameters['test'] == '1' ||
        Uri.base.queryParameters['bypass_login'] == '1';
    if (!bypassLogin && user == null) {
      return const LoginPage();
    }
    return const _PwaRotateOverlay(child: WebConnectedScreen());
  }
}

/// Affiche un message « Tournez l'écran pour voir la barre » en portrait sur petit écran (PWA).
class _PwaRotateOverlay extends StatelessWidget {
  const _PwaRotateOverlay({required this.child});

  final Widget child;

  static const double _portraitBreakpoint = 560;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final isPortrait = width < height;
    final isNarrow = width < _portraitBreakpoint;
    final showRotateHint = isPortrait && isNarrow;

    if (showRotateHint) {
      return Material(
        color: const Color(0xFFE8F0F1),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.screen_rotation,
                    size: 80,
                    color: OffiboxWebApp.offiboxTeal,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tournez l\'écran en paysage pour voir la barre d\'outils.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'Spinnaker',
                          color: const Color(0xFF334155),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return child;
  }
}
