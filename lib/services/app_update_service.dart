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
      final customUrl = AppUpdateConfig.customLatestVersionUrl.trim();
      if (customUrl.isNotEmpty) {
        final info = await _checkViaCustomUrl(customUrl);
        return info;
      }

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
      final baseUrl = AppUpdateConfig.publicDownloadBaseUrl.trim();
      if (baseUrl.isNotEmpty) {
        final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        downloadUrl = '$base${AppUpdateConfig.windowsInstallerName}-$versionStr${AppUpdateConfig.windowsAssetExtension}';
      } else {
        for (final a in assets) {
          final map = a as Map<String, dynamic>;
          final url = map['browser_download_url'] as String? ?? '';
          if (url.toLowerCase().endsWith(AppUpdateConfig.windowsAssetExtension)) {
            downloadUrl = url;
            break;
          }
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

  /// Télécharge l'installer avec barre de progression, puis lance l'installation silencieuse (sans UI du setup).
  /// [onProgress] : (progress 0.0..1.0, received, total) — total peut être -1 si inconnu.
  static Future<bool> downloadAndInstallSilent(
    AppUpdateInfo info, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    if (!Platform.isWindows) return false;
    try {
      final file = await downloadWithProgress(
        info.downloadUrl,
        onProgress: onProgress,
      );
      if (file == null) return false;
      return await applyUpdateSilent(file.path);
    } catch (_) {
      return false;
    }
  }

  /// Télécharge avec suivi de progression. Retourne le fichier ou null.
  static Future<File?> downloadWithProgress(
    String url, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode != 200) return null;

    final total = response.contentLength ?? -1;
    int received = 0;
    final dir = await getTemporaryDirectory();
    final fileName = url.split('/').last;
    if (fileName.isEmpty) return null;
    final file = File('${dir.path}/$fileName');
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total, received, total);
      } else if (onProgress != null) {
        onProgress(received > 0 ? 1.0 : 0.0, received, total);
      }
    }
    await sink.close();
    client.close();
    return file;
  }

  /// Lance l'installer en mode silencieux (pas d'UI du setup, mise à jour en place).
  static Future<bool> applyUpdateSilent(String exePath) async {
    if (!Platform.isWindows) return false;
    try {
      // Lancer l'installer en arrière-plan puis quitter : l'installer remplace les fichiers à la fermeture de l'app.
      await Process.start(
        exePath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Télécharge l'installer et ouvre le fichier (ancien comportement : lance le setup avec UI).
  static Future<bool> downloadAndOpen(AppUpdateInfo info) async {
    try {
      final file = await downloadWithProgress(info.downloadUrl);
      if (file == null) return false;
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

  /// Détection de MAJ via un JSON hébergé sur ton site (pas GitHub).
  /// Réponse attendue : { "version": "1.1.26", "download_url": "https://offibox.fr/download/Offibox-Setup-1.1.26.exe" }
  static Future<AppUpdateInfo?> _checkViaCustomUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      if (json == null) return null;
      final version = json['version'] as String?;
      final downloadUrl = json['download_url'] as String?;
      if (version == null || version.isEmpty || downloadUrl == null || downloadUrl.isEmpty) return null;
      final latestVersion = _normalizeVersion(version);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = _normalizeVersion(packageInfo.version);
      if (!_isNewer(latestVersion, currentVersion)) return null;
      final versionStr = version.replaceFirst(RegExp(r'^v'), '').trim();
      if (Platform.isIOS) {
        return AppUpdateInfo(version: versionStr, downloadUrl: AppUpdateConfig.iosUpdateUrl, isIos: true);
      }
      return AppUpdateInfo(version: versionStr, downloadUrl: downloadUrl.trim());
    } catch (_) {
      return null;
    }
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
