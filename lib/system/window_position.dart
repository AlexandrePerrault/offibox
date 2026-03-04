import 'dart:io' show Platform;
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:offibox/config/app_config.dart';

/// Marge initiale du bord de l'écran (1 cm ≈ 38 px à 96 dpi).
const double _kInitialMarginPx = 38.0;

const String _kPrefWindowX = 'offibox_window_x';
const String _kPrefWindowY = 'offibox_window_y';

/// Gestion de la position de la fenêtre (sauvegarde/restauration, visibilité au démarrage).
class WindowPosition {
  /// Assure que la fenêtre est visible au démarrage (position 1 cm du haut et de la droite).
  static Future<void> ensureVisibleAtStartup() async {
    try {
      final size = await windowManager.getSize();
      final workArea = _getWorkArea();
      final x = workArea.right - size.width - _kInitialMarginPx;
      final y = workArea.top + _kInitialMarginPx;
      await windowManager.setPosition(Offset(x, y));
    } catch (_) {
      // Fallback: position par défaut
      try {
        await windowManager.setPosition(const Offset(100, _kInitialMarginPx));
      } catch (_) {}
    }
  }

  static Rect _getWorkArea() {
    try {
      final views = PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        final view = views.first;
        final physical = view.physicalSize;
        final dpr = view.devicePixelRatio;
        if (physical.width > 0 && physical.height > 0 && dpr > 0) {
          return Rect.fromLTWH(
            0,
            0,
            physical.width / dpr,
            physical.height / dpr,
          );
        }
      }
    } catch (_) {}
    // Fallback: écran logique 1920x1080
    return const Rect.fromLTWH(0, 0, 1920, 1080);
  }

  /// Restaure la position sauvegardée et écoute les changements pour la sauvegarder.
  /// Sur Windows, masque la barre de titre système (frameless) pour ne pas voir la barre grise ni les contours.
  static Future<void> restoreAndListen() async {
    try {
      await windowManager.setTitle(AppConfig.appName);
      if (Platform.isWindows) {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_kPrefWindowX);
      final y = prefs.getDouble(_kPrefWindowY);
      if (x != null && y != null) {
        final workArea = _getWorkArea();
        // Vérifier que la position sauvegardée est dans l'écran (au moins partiellement)
        if (x >= workArea.left - 400 && x <= workArea.right + 100 &&
            y >= workArea.top - 100 && y <= workArea.bottom + 100) {
          await windowManager.setPosition(Offset(x, y));
        }
      }

      await windowManager.setMovable(true);

      windowManager.addListener(_WindowPositionListener());
    } catch (_) {}
  }

  /// Sauvegarde la position actuelle (appelé par le listener).
  static Future<void> _savePosition() async {
    try {
      final pos = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPrefWindowX, pos.dx);
      await prefs.setDouble(_kPrefWindowY, pos.dy);
    } catch (_) {}
  }
}

class _WindowPositionListener with WindowListener {
  @override
  void onWindowMoved() {
    WindowPosition._savePosition();
  }
}
