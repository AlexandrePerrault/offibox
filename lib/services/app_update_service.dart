import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_update_config.dart';

/// Vérifie et propose les mises à jour de l'application.
/// Exécute une vérification au plus une fois par jour.
class AppUpdateService {
  AppUpdateService._();

  /// Vérifie si une mise à jour est disponible.
  /// [force] : si true, ignore la limite 1 fois/jour (pour auto-install quand "ne plus me demander").
  /// Retourne [AppUpdateInfo] si une nouvelle version existe, null sinon.
  /// Windows : cherche un asset .msi. iOS : retourne l'URL des releases (ou TestFlight si configuré).
  static Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (kDebugMode) return null;
    if (!Platform.isWindows && !Platform.isIOS) return null;

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final lastCheck = prefs.getString(AppUpdateConfig.lastCheckKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();
      if (lastCheck == today) return null;
      await prefs.setString(AppUpdateConfig.lastCheckKey, today);
    }

    try {
      final response = await http.get(
        Uri.parse(AppUpdateConfig.latestReleaseUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String?;
      final assets = json['assets'] as List<dynamic>? ?? [];

      if (tagName == null || tagName.isEmpty) return null;

      final latestVersion = _normalizeVersion(tagName);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = _normalizeVersion(packageInfo.version);

      if (!_isNewer(latestVersion, currentVersion)) return null;

      final versionStr = tagName.replaceFirst(RegExp(r'^v'), '').trim();

      if (Platform.isIOS) {
        return AppUpdateInfo(
          version: versionStr,
          downloadUrl: AppUpdateConfig.iosUpdateUrl,
          isIos: true,
        );
      }

      String? downloadUrl;
      for (final a in assets) {
        final map = a as Map<String, dynamic>;
        final name = map['browser_download_url'] as String? ?? '';
        if (name.toLowerCase().endsWith(AppUpdateConfig.windowsAssetExtension)) {
          downloadUrl = name;
          break;
        }
      }
      if (downloadUrl != null) {
        return AppUpdateInfo(
          version: versionStr,
          downloadUrl: downloadUrl,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Télécharge l'installer et ouvre le fichier.
  static Future<bool> downloadAndOpen(AppUpdateInfo info) async {
    try {
      final response = await http.get(Uri.parse(info.downloadUrl));
      if (response.statusCode != 200) return false;

      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final fileName = info.downloadUrl.split('/').last;
      if (fileName.isEmpty) return false;

      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      final uri = Uri.file(file.path);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static List<int> _normalizeVersion(String v) {
    final cleaned = v.replaceFirst(RegExp(r'^v'), '').trim();
    return cleaned.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static bool _isNewer(List<int> latest, List<int> current) {
    for (var i = 0; i < latest.length; i++) {
      final l = i < latest.length ? latest[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return latest.length > current.length;
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.isIos = false,
  });
  final String version;
  final String downloadUrl;
  final bool isIos;
}
