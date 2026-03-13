/// Stub pour remplacer `dart:io` (Platform, exit, Process) sur le web.
/// Utiliser avec : import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform, exit, Process;
class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static String get operatingSystemVersion => '';
}

void exit(int code) {}

class Process {
  static Future<dynamic> start(String executable, List<String> arguments) async =>
      Future.value(null);
}
