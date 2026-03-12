import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL de connexion Mailiz (messagerie sécurisée santé) — ouverture dans le panneau web sous la barre.
const String mssantePortalUrl =
    'https://auth-mailiz.mssante.fr/realms/mssante/protocol/openid-connect/auth'
    '?response_type=code&client_id=roundcube&scope=email+profile+openid'
    '&redirect_uri=https%3A%2F%2Froundcube.mssante.fr%2Findex.php%2Flogin%2Foauth'
    '&state=QXh9Cgql0Wha';

/// Appelé avant toute ouverture de lien (ex. pour refermer la barre).
void Function()? onBeforeOpenLink;

/// Appelé avant d'ouvrir une URL dans le navigateur système (pour réduire Offibox et laisser voir la page).
void Function()? onBeforeOpenExternalBrowser;

/// Si défini, intercepte l'ouverture des liens HTTP(S) pour les afficher dans l'app
/// (ex. panneau sous la barre sur desktop) au lieu d'ouvrir le navigateur.
void Function(String url)? onOpenHttpUrlInApp;

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
    if (kDebugMode) debugPrint('⛔ launchUrl échoué : $url — $e');
  }

  // Secours Windows : ouvrir via le shell → navigateur par défaut (Chrome, Edge, etc.)
  if (Platform.isWindows) {
    try {
      await Process.run('cmd', ['/c', 'start', '', url], runInShell: false);
    } catch (e2) {
      if (kDebugMode) debugPrint('⛔ Fallback Windows échoué : $url — $e2');
    }
  }
}

Future<void> openUrl(String rawUrl, {bool forceExternal = false}) async {
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
    if (kDebugMode) debugPrint('⛔ URL invalide : [$clean]');
    return;
  }

  final uri = Uri.parse(clean);

  // HTTP(S) : par défaut ouvrir dans l'app si un handler est défini (panneau sous la barre).
  // Sinon fallback navigateur système.
  // Sur Windows, canLaunchUrl peut renvoyer false pour http(s) alors que l’ouverture fonctionne.
  if (isHttp) {
    if (!forceExternal && onOpenHttpUrlInApp != null) {
      onOpenHttpUrlInApp!.call(clean);
      return;
    }
    onBeforeOpenExternalBrowser?.call();
    await _openInDefaultBrowser(clean);
    return;
  }

  final ok = await canLaunchUrl(uri);
  if (kDebugMode) debugPrint('🌐 canLaunchUrl($clean) = $ok');

  if (!ok) {
    if (kDebugMode) debugPrint('⛔ Impossible d’ouvrir : $clean');
    return;
  }

  onBeforeOpenExternalBrowser?.call();
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}

/// Ouvre systématiquement dans le navigateur système (utile pour "Télécharger", "Imprimer", etc.).
Future<void> openUrlExternal(String rawUrl) => openUrl(rawUrl, forceExternal: true);

/// Passe par le portail MSsanté au lieu d'un mailto: — les BAL MSSanté ne fonctionnent pas avec Outlook/Gmail.
/// Ouvre le portail (dans l'app sous la barre si possible, sinon navigateur).
Future<void> openMssantePortal() => openUrl(mssantePortalUrl);
