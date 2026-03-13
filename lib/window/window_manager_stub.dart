// Stub pour window_manager sur plateformes web (pas de fenêtre native).
// Utilisé via import conditionnel : if (dart.library.html) ce fichier, sinon package window_manager.

import 'package:flutter/material.dart';

class _WindowManagerStub {
  Future<void> ensureInitialized() async {}
  Future<void> setTitle(String title) async {}
  Future<void> setSize(Size size) async {}
  Future<void> setPosition(Offset position) async {}
  Future<void> setBounds(Rect bounds) async {}
  Future<Size> getSize() async => const Size(800, 600);
  Future<Offset> getPosition() async => Offset.zero;
  Future<void> minimize() async {}
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> focus() async {}
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}
  Future<void> setTitleBarStyle(dynamic style) async {}
  Future<void> setMovable(bool movable) async {}
  void addListener(dynamic listener) {}
}

final windowManager = _WindowManagerStub();

/// Stub : sur web, pas de fenêtre à déplacer, on renvoie juste l'enfant.
class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
