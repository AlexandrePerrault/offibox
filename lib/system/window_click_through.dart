import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:win32/win32.dart';

void enableClickThrough() {
  final hwnd = appWindow.handle;
  if (hwnd == null) return;

  final style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);

  SetWindowLongPtr(
    hwnd,
    GWL_EXSTYLE,
    (style.toSigned(64).toInt()) | WS_EX_LAYERED | WS_EX_TRANSPARENT,
  );
}

void disableClickThrough() {
  final hwnd = appWindow.handle;
  if (hwnd == null) return;

  final style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);

  SetWindowLongPtr(
    hwnd,
    GWL_EXSTYLE,
    (style.toSigned(64).toInt()) & ~WS_EX_TRANSPARENT,
  );
}

int _currentRegion = 0;

/// Définit la région de la fenêtre à un rectangle (en pixels physiques).
/// Seule cette zone est visible et cliquable ; le reste est transparent et clic à travers.
void setWindowRegion(int leftPx, int topPx, int widthPx, int heightPx) {
  if (!Platform.isWindows) return;
  final hwnd = appWindow.handle;
  if (hwnd == null || widthPx <= 0 || heightPx <= 0) return;

  if (_currentRegion != 0) {
    DeleteObject(_currentRegion);
    _currentRegion = 0;
  }

  final rgn = CreateRectRgn(
    leftPx,
    topPx,
    leftPx + widthPx,
    topPx + heightPx,
  );
  if (rgn == 0) return;
  _currentRegion = rgn;
  SetWindowRgn(hwnd, rgn, TRUE);
}

/// Rétablit toute la fenêtre (plus de région) : toute la surface est à nouveau visible et cliquable.
void clearWindowRegion() {
  if (!Platform.isWindows) return;
  final hwnd = appWindow.handle;
  if (hwnd == null) return;

  if (_currentRegion != 0) {
    DeleteObject(_currentRegion);
    _currentRegion = 0;
  }
  SetWindowRgn(hwnd, 0, TRUE);
}
