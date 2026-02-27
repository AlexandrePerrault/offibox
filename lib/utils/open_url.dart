import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Appelé avant toute ouverture de lien (ex. pour refermer la barre).
void Function()? onBeforeOpenLink;

/// Ouvre l'URL dans le navigateur par défaut du système (ex. Chrome si c'est le navigateur par défaut).
/// Sur Windows : utilise le shell en secours si launchUrl échoue, pour garantir l'ouverture dans Chrome/Edge/etc.
Future<void> _openInDefaultBrowser(String url) async {
  try {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    return;
  } catch (e) {
    debugPrint('⛔ launchUrl échoué : $url — $e');
  }

  // Secours Windows : ouvrir via le shell → navigateur par défaut (Chrome, Edge, etc.)
  if (Platform.isWindows) {
    try {
      await Process.run('cmd', ['/c', 'start', '', url], runInShell: false);
    } catch (e2) {
      debugPrint('⛔ Fallback Windows échoué : $url — $e2');
    }
  }
}

Future<void> openUrl(String rawUrl) async {
  onBeforeOpenLink?.call();

  final clean = rawUrl
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('\r', '')
      .replaceAll('\n', '')
      .trim();

  final isHttp = clean.startsWith('http://') || clean.startsWith('https://');
  final isMail = clean.startsWith('mailto:');
  final isTel  = clean.startsWith('tel:');

  if (!isHttp && !isMail && !isTel) {
    debugPrint('⛔ URL invalide : [$clean]');
    return;
  }

  final uri = Uri.parse(clean);

  // Ouvrir dans le navigateur par défaut (Chrome, Edge, etc.) — jamais dans l'app.
  // Sur Windows, canLaunchUrl peut renvoyer false pour http(s) alors que l’ouverture fonctionne.
  if (isHttp) {
    await _openInDefaultBrowser(clean);
    return;
  }

  final ok = await canLaunchUrl(uri);
  debugPrint('🌐 canLaunchUrl($clean) = $ok');

  if (!ok) {
    debugPrint('⛔ Impossible d’ouvrir : $clean');
    return;
  }

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}
