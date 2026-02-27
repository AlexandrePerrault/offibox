import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Extrait l'ID vidéo d'une URL YouTube (watch, embed ou youtu.be).
/// Ex. https://www.youtube.com/watch?v=9nndzVHU2Do → 9nndzVHU2Do
String? _youtubeVideoId(String url) {
  final u = url.trim();
  // www., m., ou sans sous-domaine ; paramètres &list= etc. ignorés
  final watchMatch = RegExp(
    r'(?:youtube\.com/watch\?v=|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  ).firstMatch(u);
  if (watchMatch != null) return watchMatch.group(1);
  final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(u);
  if (shortMatch != null) return shortMatch.group(1);
  return null;
}

/// Transforme une URL watch/share en URL embed pour le lecteur.
/// Ex. https://www.youtube.com/watch?v=9nndzVHU2Do → https://www.youtube-nocookie.com/embed/9nndzVHU2Do?autoplay=1
String _youtubeEmbedUrl(String url) {
  final id = _youtubeVideoId(url);
  if (id != null) return 'https://www.youtube-nocookie.com/embed/$id?autoplay=1';
  return url.trim();
}

/// Panneau vidéo YouTube sous la barre. Format 16:9, largeur = largeur barre. Apparition/disparition en fondu.
/// Sur Windows : webview_windows. Sur les autres plateformes : youtube_player_iframe (iFrame API officielle).
class YouTubeVideoPanelBelowBar extends StatefulWidget {
  const YouTubeVideoPanelBelowBar({
    super.key,
    required this.youtubeUrl,
    required this.barWidth,
    required this.onClose,
  });

  final String youtubeUrl;
  final double barWidth;
  final VoidCallback onClose;

  @override
  State<YouTubeVideoPanelBelowBar> createState() => _YouTubeVideoPanelBelowBarState();
}

class _YouTubeVideoPanelBelowBarState extends State<YouTubeVideoPanelBelowBar> {
  final bool _useIframe = !isWindows;

  // WebView Windows
  final WebviewController _webViewController = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;

  // YouTube iFrame (Android, iOS, macOS, Web)
  YoutubePlayerController? _ytController;

  double _opacity = 0;
  bool _closing = false;
  bool _initError = false;
  String? _initErrorMessage;
  bool _openingInBrowser = false;

  double get _videoHeight => widget.barWidth * 9 / 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
    if (_useIframe) {
      _initIframe();
    } else {
      _initWebView();
    }
  }

  /// En cas d'erreur (ex. 153) : ouvre la vidéo dans le navigateur puis ferme le panneau avec un fondu.
  void _openInBrowserThenClose() {
    if (_openingInBrowser || _closing) return;
    _openingInBrowser = true;
    openUrl(widget.youtubeUrl);
    _closeWithFade();
  }

  void _initIframe() {
    final videoId = _youtubeVideoId(widget.youtubeUrl);
    if (videoId == null || videoId.isEmpty) {
      setState(() {
        _initError = true;
        _initErrorMessage = 'URL YouTube invalide';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && _initError) _openInBrowserThenClose();
      });
      return;
    }
    try {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = true;
          _initErrorMessage = e.toString();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted && _initError) _openInBrowserThenClose();
        });
      }
    }
  }

  /// Tente d'accepter automatiquement le bandeau cookies YouTube (bouton "Oui" / "Accept").
  Future<void> _tryAcceptYouTubeConsent() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    try {
      const String script = r'''
        (function() {
          function acceptLabel(t) {
            var s = (t || "").trim().toLowerCase();
            if (/^(oui|yes|accept|accepter|ok)$/.test(s)) return true;
            if (/tout accepter|accept all/i.test(t)) return true;
            if (/refuser|reject|refuse/i.test(t)) return false;
            if (/accept|accepter|oui/i.test(t)) return true;
            return false;
          }
          var buttons = document.querySelectorAll("button, [role='button'], .ytd-button-renderer, tp-yt-paper-button, a[role='button']");
          for (var i = 0; i < buttons.length; i++) {
            var b = buttons[i];
            var label = (b.textContent || b.innerText || "").trim();
            var aria = (b.getAttribute("aria-label") || "").trim();
            if (acceptLabel(label) || acceptLabel(aria)) {
              b.click();
              return "clicked";
            }
          }
          var form = document.querySelector("form");
          if (form) {
            var submit = form.querySelector('button[type="submit"], input[type="submit"]');
            if (submit && acceptLabel(submit.value || submit.textContent)) {
              submit.click();
              return "clicked-form";
            }
          }
          return "no-button";
        })();
      ''';
      await _webViewController.executeScript(script);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _webViewController.executeScript(script);
    } catch (_) {}
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.black);
      await _webViewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _loadingSubscription = _webViewController.loadingState.listen((LoadingState state) {
        if (state == LoadingState.navigationCompleted) _tryAcceptYouTubeConsent();
      });
      final embedUrl = _youtubeEmbedUrl(widget.youtubeUrl);
      await _webViewController.loadUrl(embedUrl);
      if (!mounted) return;
      setState(() {});
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = 'WebView indisponible';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && _initError) _openInBrowserThenClose();
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.message ?? e.code;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && _initError) _openInBrowserThenClose();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.toString();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && _initError) _openInBrowserThenClose();
      });
    }
  }

  Future<void> _closeWithFade() async {
    if (_closing) return;
    setState(() => _closing = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) widget.onClose();
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange.shade300),
          const SizedBox(height: 8),
          Text(
            _initErrorMessage ?? 'Impossible de charger la vidéo',
            style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ouverture dans le navigateur…',
            style: TextStyle(color: Colors.orange.shade200, fontSize: 11),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _openInBrowserThenClose,
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Ouvrir dans le navigateur'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loadingSubscription?.cancel();
    _webViewController.dispose();
    _ytController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _closing ? 0 : _opacity,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, left: 12, right: 12, bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: widget.barWidth,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      SizedBox(
                        width: widget.barWidth,
                        height: _videoHeight,
                        child: _initError
                            ? _buildFallback()
                            : _useIframe
                                ? (_ytController != null
                                    ? YoutubePlayer(
                                        controller: _ytController!,
                                        aspectRatio: 16 / 9,
                                      )
                                    : const Center(child: CircularProgressIndicator(color: Colors.white70)))
                                : (!_webViewController.value.isInitialized
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                                    : Webview(
                                        _webViewController,
                                        permissionRequested: (String url, WebviewPermissionKind kind, bool isUserInitiated) async =>
                                            WebviewPermissionDecision.allow,
                                      )),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: _closeWithFade,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
