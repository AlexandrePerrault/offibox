import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../window/offibox_window.dart';


class OffiboxApp extends StatelessWidget {
  const OffiboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: false,

        // 🔤 Police globale
        textTheme: GoogleFonts.spinnakerTextTheme(),
        fontFamily: GoogleFonts.spinnaker().fontFamily,

        scaffoldBackgroundColor: Colors.transparent,
      ),

      home: const OffiboxWindow(),
    );
  }
}
