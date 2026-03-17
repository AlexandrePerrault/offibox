import 'dart:io' show Platform;
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:offibox/config/app_config.dart';

/// Marge initiale du bord de l'écran (1 cm ≈ 38 px à 96 dpi).
const double _kInitialMarginPx = 38.0;

/// Bornes raisonnables pour une position d'écran (évite -21333 ou valeurs corrompues).
const double _kPositionMin = -2000.0;
const double _kPositionMax = 10000.0;

const String _kPrefWindowX = 'offibox_window_x';
const String _kPrefWindowY = 'offibox_window_y';

bool _isPositionValid(double x, double y) {
  return x >= _kPositionMin && x <= _kPositionMax && y >= _kPositionMin && y <= _kPositionMax;
}

/// Gestion de la position de la fenêtre (sauvegarde/restauration, visibilité au démarrage).
class WindowPosition {
  /// Assure que la fenêtre est visible au démarrage (position 1 cm du haut et de la droite).
  static Future<void> ensureVisibleAtStartup() async {
    try {
      final size = await windowManager.getSize();
      final workArea = _getWorkArea();
      double x = workArea.right - size.width - _kInitialMarginPx;
      double y = workArea.top + _kInitialMarginPx;
      if (!_isPositionValid(x, y) || workArea.width < 100 || workArea.height < 100) {
        x = 100.0;
        y = _kInitialMarginPx;
      }
      await windowManager.setPosition(Offset(x, y));
    } catch (_) {
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
      if (x != null && y != null && _isPositionValid(x, y)) {
        final workArea = _getWorkArea();
        if (workArea.width >= 100 && workArea.height >= 100 &&
            x >= workArea.left - 400 && x <= workArea.right + 100 &&
            y >= workArea.top - 100 && y <= workArea.bottom + 100) {
          await windowManager.setPosition(Offset(x, y));
        }
      } else if (x != null && y != null && !_isPositionValid(x, y)) {
        // Position sauvegardée invalide (ex. -21333) : la supprimer pour ne plus la restaurer.
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.remove(_kPrefWindowX);
        await prefs2.remove(_kPrefWindowY);
      }

      await windowManager.setMovable(true);
      // Au lancement (ex. après install), amener la fenêtre au premier plan.
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}

      windowManager.addListener(_WindowPositionListener());
    } catch (_) {}
  }

  /// Sauvegarde la position actuelle (appelé par le listener). Ne sauvegarde pas si position invalide.
  static Future<void> _savePosition() async {
    try {
      final pos = await windowManager.getPosition();
      if (!_isPositionValid(pos.dx, pos.dy)) return;
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
