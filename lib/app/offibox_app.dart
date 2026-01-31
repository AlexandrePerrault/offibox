import 'package:flutter/material.dart';
import '../window/offibox_window.dart';

class OffiboxApp extends StatelessWidget {
  const OffiboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OffiboxWindow(),
    );
  }
}
