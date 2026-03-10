import 'package:offibox/config/app_config.dart';
import 'package:offibox/system/windows_autostart.dart';

/// Apply autostart setting from installer (MSI writes choice to registry or we keep current state).
void applyFromInstaller() {
  try {
    // Option: read from registry if installer wrote a value; otherwise leave as-is.
    // Minimal: do nothing so we don't override user choice. Or enable if installer set it.
    // WindowsAutostart.enable(); // uncomment if installer explicitly requests enable
  } catch (_) {}
}
