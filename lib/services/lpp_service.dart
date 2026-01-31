import '../data/lpp_repository.dart';

class LppService {
  static Future<Map<String, String>> loadIndex() async {
    final entries = await LppRepository.loadFromGithub();
    return {
      for (final e in entries) e.code: e.url,
    };
  }
}
