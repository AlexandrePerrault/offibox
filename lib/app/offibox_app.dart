import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:offibox/auth/auth_gate.dart';
import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/auth/offibox_protocol_listener_wrapper.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/screens/ios_offibox_shell.dart';
import 'package:offibox/ui/screens/login_screen.dart';
import 'package:offibox/window/offibox_window.dart';
import 'package:offibox/window/windows_preload_wrapper.dart';

class OffiboxApp extends StatelessWidget {
  const OffiboxApp({super.key});

  // 🎨 Couleur Offibox centrale
  static const Color offiboxTeal = Color(0xFF5A9094);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: false,

        // 🔤 Police globale Spinnaker partout
        textTheme: GoogleFonts.spinnakerTextTheme(),
        fontFamily: GoogleFonts.spinnaker().fontFamily,
        primaryTextTheme: GoogleFonts.spinnakerTextTheme(),

        scaffoldBackgroundColor: Colors.transparent,

        /// Bords arrondis pour toutes les fenêtres modales (AlertDialog, Dialog, etc.).
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          ),
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: offiboxTeal.withValues(alpha: 0.92),
          elevation: 6,
          menuPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Spinnaker',
            height: 1.1,
          ),
        ),

        // Tooltips : 20 % plus compacts, fond gris anthracite, texte blanc, pas gras, minuscules (via OffiboxTooltip)
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 900),
          decoration: BoxDecoration(
            color: const Color(0xFF37474F), // gris anthracite
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.normal,
            fontFamily: 'Spinnaker',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        ),
      ),

      initialRoute: '/',
      routes: {
        '/': (_) => const OffiboxProtocolListenerWrapper(
              child: _InitialRoute(),
            ),
        '/home': (_) => const OffiboxWindow(),
      },
    );
  }
}

/// Sous Windows/Linux : première connexion = fenêtre de connexion (Google ou mail/mot de passe) ; sinon fenêtre principale.
/// Sous iOS/Android : login ou shell selon auth.
class _InitialRoute extends ConsumerWidget {
  const _InitialRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isWindows || Platform.isLinux) {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) {
        return const AuthGate();
      }
      return const WindowsPreloadWrapper(child: OffiboxWindow());
    }
    if (Platform.isIOS || Platform.isAndroid) {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) {
        return const LoginScreen();
      }
      return const IosOffiboxShell();
    }
    return const OffiboxWindow();
  }
}
