import 'dart:io';
import 'package:win32_registry/win32_registry.dart';

class WindowsAutostart {
  static const String _appName = 'Offibox';

  static void enable() {
    final exePath = Platform.resolvedExecutable;

    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: r'Software\Microsoft\Windows\CurrentVersion\Run',
      desiredAccessRights: AccessRights.allAccess,
    );

   key.createValue(
  RegistryValue(
    'Offibox',
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
      key.deleteValue(_appName);
    } catch (_) {}

    key.close();
  }
}
