import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isWindows) {
    final info = await deviceInfo.windowsInfo;
    return info.deviceId;
  }

  if (Platform.isLinux) {
    final info = await deviceInfo.linuxInfo;
    return info.machineId ?? 'linux-unknown';
  }

  throw UnsupportedError('Platform not supported');
}
