import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/document_viewer_toolbar.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';

/// Panneau Web sous la barre : affiche une URL (site) dans une WebView, même zone que PDF/Word/XLS.
class WebPanelBelowBar extends StatefulWidget {
  const WebPanelBelowBar({
    super.key,
    required this.url,
    required this.barWidth,
    required this.onClose,
  });

  final String url;
  final double barWidth;
  final VoidCallback onClose;

  @override
  State<WebPanelBelowBar> createState() => _WebPanelBelowBarState();
}

class _WebPanelBelowBarState extends State<WebPanelBelowBar> {
  final WebviewController _webViewController = WebviewController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  double _opacity = 0;
  bool _closing = false;
  bool _initError = false;
  String? _initErrorMessage;
  bool _searchExpanded = false;
  String _activeSearchQuery = '';

  double get _panelHeight => widget.barWidth * 9 / 16;

  String _escapeJsString(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }

  Future<bool> _runFind(String query, {required bool backwards}) async {
    if (!_webViewController.value.isInitialized) return false;
    final escaped = _escapeJsString(query);
    try {
      final result = await _webViewController.executeScript('''
        (function() {
          if (typeof window.find !== 'function') return false;
          return window.find('$escaped', false, $backwards, true, false, true, false);
        })();
      ''');
      return result == 'true' || result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
    if (isWindows) {
      _initWebView();
    } else {
      setState(() {
        _initError = true;
        _initErrorMessage = 'Aperçu web disponible sous Windows';
      });
    }
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.white);
      await _webViewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _webViewController.loadUrl(widget.url.trim());
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

  void _openFullscreen() {
    if (_closing || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenDocumentPage(
          onClose: () => Navigator.of(context).pop(),
          child: _WebFullscreenContent(url: widget.url),
        ),
      ),
    );
  }

  void _printPage() {
    if (_closing) return;
    openUrl(widget.url);
  }

  Widget _buildSearchBarContent() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Rechercher...',
        hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
        prefixIcon: Icon(Icons.search, size: 20, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onSubmitted: (value) {
        if (value.trim().isEmpty) return;
        setState(() => _activeSearchQuery = value.trim());
        _runFind(value.trim(), backwards: false);
      },
    );
  }

  Widget _buildSearchResultWidget() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('Résultat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          tooltip: 'Occurrence précédente',
          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
          onPressed: () {
            if (_activeSearchQuery.isEmpty) return;
            _runFind(_activeSearchQuery, backwards: true);
          },
        ),
        IconButton(
          tooltip: 'Occurrence suivante',
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () {
            if (_activeSearchQuery.isEmpty) return;
            _runFind(_activeSearchQuery, backwards: false);
          },
        ),
        IconButton(
          tooltip: 'Effacer la recherche',
          icon: const Icon(Icons.clear, color: Colors.white, size: 20),
          onPressed: () {
            _searchController.clear();
            setState(() => _activeSearchQuery = '');
          },
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Page web',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            _initErrorMessage ?? 'Aperçu non disponible',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              openUrl(widget.url);
              _closeWithFade();
            },
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Ouvrir dans le navigateur'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _webViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _closing ? 0 : _opacity,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: _panelHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DocumentViewerToolbar(
                  barHeight: 44,
                  onPrint: _printPage,
                  onDownload: () => openUrl(widget.url),
                  onExpandFullscreen: _openFullscreen,
                  onClose: _closeWithFade,
                  onSearchTap: isWindows && !_initError && _webViewController.value.isInitialized
                      ? () => setState(() => _searchExpanded = !_searchExpanded)
                      : null,
                  searchExpanded: _searchExpanded,
                  searchBarContent: _searchExpanded && isWindows && !_initError ? _buildSearchBarContent() : null,
                  searchResultWidget: _searchExpanded && isWindows && !_initError && _activeSearchQuery.isNotEmpty
                      ? _buildSearchResultWidget()
                      : null,
                  sourceWidget: documentViewerSourceLabel(
                    label: shortUrlForDisplay(widget.url),
                    url: widget.url,
                  ),
                ),
                Expanded(
                  child: isWindows
                      ? (_initError
                          ? _buildFallback()
                          : _webViewController.value.isInitialized
                              ? Webview(
                                  _webViewController,
                                  permissionRequested: (
                                    String url,
                                    WebviewPermissionKind kind,
                                    bool isUserInitiated,
                                  ) async =>
                                      WebviewPermissionDecision.allow,
                                )
                              : const Center(
                                  child: CircularProgressIndicator(color: Colors.teal),
                                ))
                      : _buildFallback(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenu plein écran pour une page web.
class _WebFullscreenContent extends StatefulWidget {
  const _WebFullscreenContent({required this.url});

  final String url;

  @override
  State<_WebFullscreenContent> createState() => _WebFullscreenContentState();
}

class _WebFullscreenContentState extends State<_WebFullscreenContent> {
  final WebviewController _controller = WebviewController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.white);
      await _controller.loadUrl(widget.url.trim());
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Webview(
      _controller,
      permissionRequested: (
        String url,
        WebviewPermissionKind kind,
        bool isUserInitiated,
      ) async =>
          WebviewPermissionDecision.allow,
    );
  }
}
