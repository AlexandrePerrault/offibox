import 'dart:async';
import 'dart:ui' show FilterQuality;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/ui/widgets/document_viewer_toolbar.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';

/// Panneau vidéo thérapeutique (videos.csv) : uniquement la vidéo de l’URL, en 16:9.
/// En-tête « Source : » + logo (centré, +30 %) puis zone vidéo 16:9. Sur Windows : WebView avec injection JS pour n’afficher que la vidéo/iframe.
class TherapeuticVideoPanelBelowBar extends StatefulWidget {
  const TherapeuticVideoPanelBelowBar({
    super.key,
    required this.videoUrl,
    required this.barWidth,
    required this.sourceLogoAssetPath,
    required this.onClose,
  });

  final String videoUrl;
  final double barWidth;
  /// Ex. 'assets/icons/logo societe francaise pneumologie.jpg'
  final String sourceLogoAssetPath;
  final VoidCallback onClose;

  @override
  State<TherapeuticVideoPanelBelowBar> createState() =>
      _TherapeuticVideoPanelBelowBarState();
}

class _TherapeuticVideoPanelBelowBarState
    extends State<TherapeuticVideoPanelBelowBar> {
  final WebviewController _webViewController = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;

  double _opacity = 0;
  bool _closing = false;
  bool _initError = false;
  String? _initErrorMessage;
  /// Démarrer la vidéo au clic sur le triangle (pas de chargement automatique).
  bool _hasUserStarted = false;

  double get _videoHeight => widget.barWidth * 9 / 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
  }

  void _onPlayPressed() {
    if (_hasUserStarted || _closing) return;
    setState(() => _hasUserStarted = true);
    if (isWindows) {
      _initWebView();
    }
  }

  void _openInBrowserThenClose() {
    if (_closing) return;
    openUrlExternal(widget.videoUrl);
    _closeWithFade();
  }

  /// Injecte du JS pour n'afficher que la vidéo/iframe de la page (ex. SPLF).
  Future<void> _isolateVideoInPage() async {
    const script = '''
      (function() {
        var v = document.querySelector('iframe, video');
        if (v) {
          document.body.style.overflow = 'hidden';
          document.body.style.background = '#000';
          var all = document.querySelectorAll('body *');
          for (var i = 0; i < all.length; i++) all[i].style.visibility = 'hidden';
          v.style.visibility = 'visible';
          v.style.position = 'fixed';
          v.style.top = '0';
          v.style.left = '0';
          v.style.width = '100%';
          v.style.height = '100%';
          v.style.zIndex = '9999';
        }
      })();
    ''';
    try {
      await _webViewController.executeScript(script);
    } catch (_) {}
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.white);
      await _webViewController.setPopupWindowPolicy(
          WebviewPopupWindowPolicy.deny,);
      _loadingSubscription =
          _webViewController.loadingState.listen((LoadingState state) {
        if (state == LoadingState.navigationCompleted) {
          _isolateVideoInPage();
          Future<void>.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) _isolateVideoInPage();
          });
        }
      });
      await _webViewController.loadUrl(widget.videoUrl.trim());
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

  void _openFullscreen() {
    if (_closing || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenDocumentPage(
          onClose: () => Navigator.of(context).pop(),
          child: _TherapeuticFullscreenContent(videoUrl: widget.videoUrl),
        ),
      ),
    );
  }

  static const double _logoBaseHeight = 36;
  static const double _logoScale = 1.30; // +30 %

  Widget _buildSourceHeader() {
    const logoHeight = _logoBaseHeight * _logoScale; // 46.8
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Source : ',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
                fontFamily: 'Spinnaker',
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                widget.sourceLogoAssetPath,
                height: logoHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.video_library,
                  size: logoHeight,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Overlay blanc 16:9 avec triangle play au centre (type YouTube). Clic → démarre le chargement.
  Widget _buildPlayOverlay() {
    return GestureDetector(
      onTap: _onPlayPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.barWidth,
        height: _videoHeight,
        color: Colors.white,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onPlayPressed,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 56,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 40, color: Colors.orange.shade300,),
          const SizedBox(height: 8),
          Text(
            _initErrorMessage ?? 'Impossible de charger la vidéo',
            style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
            textAlign: TextAlign.center,
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
    if (_webViewController.value.isInitialized) {
      _webViewController.dispose();
    }
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
          color: Colors.white,
          child: Container(
            width: widget.barWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
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
                  DocumentViewerToolbar(
                    barHeight: 44,
                    backgroundColor: Colors.white,
                    onDownload: () {
                      if (!_closing) openUrlExternal(widget.videoUrl);
                    },
                    downloadLabel: 'Ouvrir dans navigateur',
                    downloadTooltip: 'Ouvrir dans le navigateur',
                    downloadIcon: Icons.open_in_browser,
                    onExpandFullscreen: _openFullscreen,
                    onClose: _closeWithFade,
                  ),
                  _buildSourceHeader(),
                  SizedBox(
                    width: widget.barWidth,
                    height: _videoHeight,
                    child: !_hasUserStarted
                        ? _buildPlayOverlay()
                        : (isWindows
                            ? (_initError
                                ? _buildFallback()
                                : _webViewController.value.isInitialized
                                    ? LayoutBuilder(
                                        builder: (context, c) {
                                          final dpr = MediaQuery.devicePixelRatioOf(context);
                                          final w = (c.maxWidth * dpr).floorToDouble() / dpr;
                                          final h = (c.maxHeight * dpr).floorToDouble() / dpr;
                                          return Webview(
                                            _webViewController,
                                            width: w,
                                            height: h,
                                            scaleFactor: dpr,
                                            filterQuality: FilterQuality.none,
                                            permissionRequested: (String url,
                                                    WebviewPermissionKind kind,
                                                    bool isUserInitiated,) async =>
                                                WebviewPermissionDecision.allow,
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.white,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ))
                            : Container(
                                color: Colors.white,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Vidéo thérapeutique',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: _openInBrowserThenClose,
                                        icon: Icon(
                                          Icons.open_in_browser,
                                          color: Colors.grey.shade700,
                                        ),
                                        label: Text(
                                          'Ouvrir dans le navigateur',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
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

/// Contenu plein écran pour une vidéo thérapeutique (WebView).
class _TherapeuticFullscreenContent extends StatefulWidget {
  const _TherapeuticFullscreenContent({required this.videoUrl});

  final String videoUrl;

  @override
  State<_TherapeuticFullscreenContent> createState() => _TherapeuticFullscreenContentState();
}

class _TherapeuticFullscreenContentState extends State<_TherapeuticFullscreenContent> {
  final WebviewController _controller = WebviewController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (isWindows) _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _controller.loadingState.listen((LoadingState state) {
        if (state == LoadingState.navigationCompleted) _isolateVideo();
      });
      await _controller.loadUrl(widget.videoUrl.trim());
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _isolateVideo() async {
    const script = '''
      (function() {
        var v = document.querySelector('iframe, video');
        if (v) {
          document.body.style.overflow = 'hidden';
          document.body.style.background = '#000';
          var all = document.querySelectorAll('body *');
          for (var i = 0; i < all.length; i++) all[i].style.visibility = 'hidden';
          v.style.visibility = 'visible';
          v.style.position = 'fixed';
          v.style.top = '0';
          v.style.left = '0';
          v.style.width = '100%';
          v.style.height = '100%';
          v.style.zIndex = '9999';
        }
      })();
    ''';
    try {
      await _controller.executeScript(script);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isWindows || !_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = (constraints.maxWidth * dpr).floorToDouble() / dpr;
        final h = (constraints.maxHeight * dpr).floorToDouble() / dpr;
        return Webview(
          _controller,
          width: w,
          height: h,
          scaleFactor: dpr,
          filterQuality: FilterQuality.none,
          permissionRequested: (String url, WebviewPermissionKind kind, bool isUserInitiated) async =>
              WebviewPermissionDecision.allow,
        );
      },
    );
  }
}
