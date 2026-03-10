/// Stub pour remplacer `dart:io` Platform sur le web (dart:io n'existe pas en cible web).
/// Utiliser avec : import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;
class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static String get operatingSystemVersion => '';
}
