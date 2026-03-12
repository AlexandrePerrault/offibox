// lib/data/offiboxdata_fetch.dart
//
// Requêtes HTTP vers le repo GitHub offiboxdata (privé).
// Si [OFFIBOXDATA_GITHUB_TOKEN] est défini (--dart-define ou env), les requêtes
// vers raw.githubusercontent.com/.../offiboxdata/... incluent l’en-tête Authorization.
//
// Utilisation (même token pour Windows et Web) :
//   flutter run --dart-define=OFFIBOXDATA_GITHUB_TOKEN=xxx
//   flutter build windows --dart-define=OFFIBOXDATA_GITHUB_TOKEN=xxx
//   flutter build web --dart-define=OFFIBOXDATA_GITHUB_TOKEN=xxx
// Les CSV/HTML et toute ressource raw offiboxdata chargée via ce module sont concernés.
// Créer un PAT : GitHub → Settings → Developer settings → Personal access tokens (scope : repo).

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Token GitHub (PAT) pour accéder au repo privé offiboxdata.
/// Défini au build : --dart-define=OFFIBOXDATA_GITHUB_TOKEN=ghp_xxx
/// Ne jamais committer le token dans le code.
final String _githubToken = const String.fromEnvironment(
  'OFFIBOXDATA_GITHUB_TOKEN',
  defaultValue: '',
);

/// Indique si l’URL pointe vers raw.githubusercontent.com pour le repo offiboxdata.
bool isOffiboxDataRawUrl(String url) {
  return url.contains('raw.githubusercontent.com') &&
      url.contains('offiboxdata');
}

/// Chemin du fichier (pour log 404), cohérent avec _rawUrlToApiUrl.
String _rawUrlPathForLog(String rawUrl) {
  final segs = Uri.parse(rawUrl).pathSegments;
  if (segs.length < 4) return rawUrl;
  if (segs.length >= 6 && segs[2] == 'refs' && segs[3] == 'heads') {
    return segs.sublist(5).join('/');
  }
  return segs.sublist(3).join('/');
}

/// Convertit une URL raw (raw.githubusercontent.com/owner/repo/ref/path)
/// en URL API Contents (api.github.com/repos/owner/repo/contents/path?ref=ref).
/// Gère ref = "main" ou ref = "refs/heads/main".
String? _rawUrlToApiUrl(String rawUrl) {
  final uri = Uri.parse(rawUrl);
  if (uri.host != 'raw.githubusercontent.com') return null;
  final segs = uri.pathSegments;
  if (segs.length < 4) return null;
  final owner = segs[0];
  final repo = segs[1];
  final String branch;
  final String path;
  if (segs.length >= 6 && segs[2] == 'refs' && segs[3] == 'heads') {
    branch = 'refs/heads/${segs[4]}';
    path = segs.sublist(5).map((s) => Uri.encodeComponent(s)).join('/');
  } else {
    branch = segs[2];
    path = segs.sublist(3).map((s) => Uri.encodeComponent(s)).join('/');
  }
  return 'https://api.github.com/repos/$owner/$repo/contents/$path?ref=${Uri.encodeComponent(branch)}';
}

bool _loggedApiUsage = false;
bool _loggedNoToken = false;

Future<http.Response> _get(String url) async {
  if (isOffiboxDataRawUrl(url)) {
    if (_githubToken.isEmpty) {
      if (kDebugMode && !_loggedNoToken) {
        _loggedNoToken = true;
        debugPrint(
          '[Offibox] OffiboxData: token non défini → requêtes raw (repo privé = 404). '
          'Lancer avec: flutter run --dart-define=OFFIBOXDATA_GITHUB_TOKEN=votre_token',
        );
      }
    } else {
      if (kDebugMode && !_loggedApiUsage) {
        _loggedApiUsage = true;
        debugPrint('[Offibox] OffiboxData: accès via API GitHub (token défini)');
      }
      final apiUrl = _rawUrlToApiUrl(url);
      if (apiUrl != null) {
        final auth = _githubToken.startsWith('github_pat_')
            ? 'Bearer $_githubToken'
            : 'token $_githubToken';
        final res = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': auth,
            'Accept': 'application/vnd.github.raw',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        );
        if (res.statusCode == 200) return res;
        if (kDebugMode && res.statusCode == 404) {
          final pathForLog = _rawUrlPathForLog(url);
          debugPrint('[Offibox] OffiboxData: API 404 pour $pathForLog (fichier absent ou token sans accès Contents ?)');
        }
        if (kDebugMode && res.statusCode == 401) {
          debugPrint('[Offibox] OffiboxData: API 401 Unauthorized. Vérifier : token valide, non expiré, avec accès au repo offiboxdata (scope repo ou Contents: Read). Réponse: ${res.body.length > 200 ? res.body.substring(0, 200) + "…" : res.body}');
        }
        if (res.statusCode != 404) return res;
      }
    }
  }
  final uri = Uri.parse(url);
  final headers = <String, String>{};
  if (_githubToken.isNotEmpty && isOffiboxDataRawUrl(url)) {
    final auth = _githubToken.startsWith('github_pat_')
        ? 'Bearer $_githubToken'
        : 'token $_githubToken';
    headers['Authorization'] = auth;
  }
  return http.get(uri, headers: headers.isEmpty ? null : headers);
}

/// Classe utilisée par les loaders pour les requêtes vers offiboxdata (avec token si défini).
class OffiboxDataFetch {
  OffiboxDataFetch._();

  /// Effectue un GET. Si [url] est une URL raw offiboxdata et qu’un token est défini,
  /// ajoute l’en-tête Authorization pour le repo privé.
  static Future<http.Response> get(String url) => _get(url);
}
