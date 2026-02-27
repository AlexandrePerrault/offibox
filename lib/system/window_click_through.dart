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
