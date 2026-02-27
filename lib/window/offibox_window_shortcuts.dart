import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/window/copy_options.dart';

/// Intents pour les raccourcis clavier.
class QuitIntent extends Intent {
  const QuitIntent();
}

class CopyResultIntent extends Intent {
  const CopyResultIntent();
}

class OpenIntent extends Intent {
  const OpenIntent();
}

class ResetIntent extends Intent {
  const ResetIntent();
}

class OffiboxWindowShortcuts {
  /// Gère les événements clavier (KeyEvent) — utilisé en fallback.
  static void handle({
    required KeyEvent event,
    required bool expanded,
    required VoidCallback open,
    required VoidCallback close,
    required VoidCallback reset,
    required VoidCallback quit,
    required SearchResult? selectedResult,
    required void Function(SearchResult) onCopyWithOptions,
    VoidCallback? onCopySuccess,
  }) {
    if (event is KeyRepeatEvent) return;
    if (event is! KeyDownEvent) return;
    if (_isModifierOnly(event.logicalKey)) return;

    final bool isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyO) {
      open();
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
      reset();
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC && selectedResult != null) {
      _handleCopy(selectedResult, onCopyWithOptions, onCopySuccess);
      return;
    }
    if (isCtrl && (event.logicalKey == LogicalKeyboardKey.keyQ || event.logicalKey == LogicalKeyboardKey.keyX)) {
      quit();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (expanded) close();
      return;
    }
  }

  static void _handleCopy(
    SearchResult result,
    void Function(SearchResult) onCopyWithOptions,
    VoidCallback? onCopySuccess,
  ) {
    final options = getCopyOptions(result);
    if (options.isEmpty) return;
    if (options.length == 1) {
      copyToClipboard(options.first.value);
      onCopySuccess?.call();
      return;
    }
    onCopyWithOptions(result);
  }

  static bool _isModifierOnly(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }
}
