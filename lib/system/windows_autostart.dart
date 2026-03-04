import 'dart:io';
import 'package:win32_registry/win32_registry.dart';

import 'package:offibox/config/app_config.dart';

class WindowsAutostart {
  static void enable() {
    final exePath = Platform.resolvedExecutable;

    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: r'Software\Microsoft\Windows\CurrentVersion\Run',
      desiredAccessRights: AccessRights.allAccess,
    );

    key.createValue(
      RegistryValue(
        AppConfig.appName,
        RegistryValueType.string,
        exePath,
      ),
    );

    key.close();
  }

  static void disable() {
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: r'Software\Microsoft\Windows\CurrentVersion\Run',
      desiredAccessRights: AccessRights.allAccess,
    );

    try {
      key.deleteValue(AppConfig.appName);
    } catch (_) {}

    key.close();
  }
}
