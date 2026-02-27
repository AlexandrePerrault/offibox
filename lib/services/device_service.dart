import 'package:cloud_functions/cloud_functions.dart';

class DeviceService {

  static Future<void> secureRegisterDevice({
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {

    final callable =
        FirebaseFunctions.instance.httpsCallable('registerDevice');

    try {
      await callable.call<void>({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'appVersion': appVersion,
      });
    } catch (e) {
      throw Exception("Limite 5 PC atteinte");
    }
  }
}
