import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:offibox/auth/offibox_protocol_listener_wrapper.dart';
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

      theme: ThemeData(
        useMaterial3: false,

        // 🔤 Police globale Spinnaker partout
        textTheme: GoogleFonts.spinnakerTextTheme(),
        fontFamily: GoogleFonts.spinnaker().fontFamily,
        primaryTextTheme: GoogleFonts.spinnakerTextTheme(),

        scaffoldBackgroundColor: const Color(0xFFE8F0F1),

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

        // Tooltips : couleur Offibox, texte inversé (blanc), apparition lente (réduit lag au survol)
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 900),
          decoration: BoxDecoration(
            color: offiboxTeal,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Spinnaker',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

/// Sous Windows, affiche le préchargeur puis la fenêtre principale ; sinon affiche directement la fenêtre.
class _InitialRoute extends ConsumerWidget {
  const _InitialRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isWindows) {
      return const WindowsPreloadWrapper(child: OffiboxWindow());
    }
    return const OffiboxWindow();
  }
}
