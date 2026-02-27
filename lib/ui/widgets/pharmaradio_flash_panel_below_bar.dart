import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';

/// URL du flash info Pharmaradio (info en continu).
const String kPharmaradioFlashInfoUrl = 'https://www.pharmaradio.fr/pharmaradio';

/// Panneau « Flash info » Pharmaradio sous la barre : logo + WebView (Windows) ou bouton ouvrir (autres).
/// Même style que [YouTubeVideoPanelBelowBar] (largeur barre, bordure, bouton fermer).
class PharmaradioFlashInfoPanelBelowBar extends StatefulWidget {
  const PharmaradioFlashInfoPanelBelowBar({
    super.key,
    required this.barWidth,
    required this.onClose,
  });

  final double barWidth;
  final VoidCallback onClose;

  @override
  State<PharmaradioFlashInfoPanelBelowBar> createState() =>
      _PharmaradioFlashInfoPanelBelowBarState();
}

class _PharmaradioFlashInfoPanelBelowBarState
    extends State<PharmaradioFlashInfoPanelBelowBar> {
  final WebviewController _webViewController = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;

  double _opacity = 0;
  bool _closing = false;
  bool _initError = false;
  String? _initErrorMessage;

  static const double _panelHeight = 420;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
    if (isWindows) {
      _initWebView();
    }
  }

  void _openInBrowserThenClose() {
    if (_closing) return;
    openUrl(kPharmaradioFlashInfoUrl);
    _closeWithFade();
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.white);
      await _webViewController.setPopupWindowPolicy(
          WebviewPopupWindowPolicy.deny);
      _loadingSubscription =
          _webViewController.loadingState.listen((LoadingState state) {});
      await _webViewController.loadUrl(kPharmaradioFlashInfoUrl);
      if (!mounted) return;
      setState(() {});
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = 'WebView indisponible';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.toString();
      });
    }
  }

  Future<void> _closeWithFade() async {
    if (_closing) return;
    setState(() => _closing = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) widget.onClose();
  }

  @override
  void dispose() {
    _loadingSubscription?.cancel();
    _webViewController.dispose();
    super.dispose();
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icons/logo_pharmaradio.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.radio,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Flash info Pharmaradio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
                fontFamily: 'Spinnaker',
              ),
            ),
          ),
        ],
      ),
    );
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
          child: SizedBox(
            width: widget.barWidth,
            height: isWindows ? _panelHeight + 72 : 160,
            child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Positioned.fill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogoHeader(),
                        if (isWindows)
                          Expanded(
                            child: _initError
                                  ? _buildFallback()
                                  : _webViewController.value.isInitialized
                                      ? Webview(
                                          _webViewController,
                                          permissionRequested: (String url,
                                                  WebviewPermissionKind kind,
                                                  bool isUserInitiated) async =>
                                              WebviewPermissionDecision.allow,
                                        )
                                      : const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Le flash info s\'ouvre dans le navigateur sur cette plateforme.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _openInBrowserThenClose,
                                  icon: const Icon(Icons.open_in_browser, size: 18),
                                  label: const Text('Ouvrir le flash info'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 40, color: Colors.orange.shade300),
            const SizedBox(height: 8),
            Text(
              _initErrorMessage ?? 'Impossible de charger le flash info',
              style: TextStyle(
                  color: Colors.orange.shade800, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openInBrowserThenClose,
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Ouvrir dans le navigateur'),
            ),
          ],
        ),
      ),
    );
  }
}
