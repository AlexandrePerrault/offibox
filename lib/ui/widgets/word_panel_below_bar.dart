import 'dart:async';
import 'dart:ui' show FilterQuality;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/document_viewer_toolbar.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';

/// URL Microsoft Office Viewer pour afficher un fichier Word (DOC/DOCX) ou Open Document (.odt).
String _wordViewerUrl(String wordUrl) {
  final encoded = Uri.encodeComponent(wordUrl.trim());
  return 'https://view.officeapps.live.com/op/embed.aspx?src=$encoded';
}

/// Panneau Word (DOC/DOCX/ODT) sous la barre. Format 16:9, largeur = largeur barre. Mêmes fonctions que XLS : télécharger, rechercher (Ctrl+F), fermer.
class WordPanelBelowBar extends StatefulWidget {
  const WordPanelBelowBar({
    super.key,
    required this.wordUrl,
    required this.barWidth,
    required this.onClose,
  });

  final String wordUrl;
  final double barWidth;
  final VoidCallback onClose;

  @override
  State<WordPanelBelowBar> createState() => _WordPanelBelowBarState();
}

class _WordPanelBelowBarState extends State<WordPanelBelowBar> {
  final WebviewController _webViewController = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  double _opacity = 0;
  bool _closing = false;
  bool _searchExpanded = false;
  bool _initError = false;
  String? _initErrorMessage;

  /// Hauteur 16:9 par rapport à la largeur barre (sans le bandeau logo).
  double get _panelHeight => widget.barWidth * 9 / 16;
  double get _totalHeight => _panelHeight;

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
        _initErrorMessage = 'Aperçu Word disponible sous Windows';
      });
    }
  }

  void _openInBrowserThenClose() {
    if (_closing) return;
    openUrlExternal(widget.wordUrl);
    _closeWithFade();
  }

  void _downloadFile() {
    if (_closing) return;
    openUrlExternal(widget.wordUrl);
  }

  void _printFile() {
    if (_closing) return;
    openUrlExternal(widget.wordUrl);
  }

  /// Lance window.find() : 1re fois = 1re occurrence, rappels = occurrence suivante. À partir de 3 caractères.
  Future<void> _searchInFile() async {
    if (_closing || !_webViewController.value.isInitialized) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      final escaped = query.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      await _webViewController.executeScript('''
        (function() {
          if (typeof window.find === 'function') {
            window.find('$escaped', false, false, true, false, false, true);
          }
        })();
      ''');
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () => _searchInFile());
    }
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.white);
      await _webViewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _loadingSubscription = _webViewController.loadingState.listen((LoadingState state) {});
      await _webViewController.loadUrl(_wordViewerUrl(widget.wordUrl));
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
          child: _WordFullscreenContent(wordUrl: widget.wordUrl),
        ),
      ),
    );
  }

  Widget _buildSearchBarContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _searchInFile(),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: '3 lettres min puis Entrée',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF5A9094)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Document Word / Open Office (DOC, DOCX, ODT)',
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
            onPressed: _openInBrowserThenClose,
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
    _loadingSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    if (_webViewController.value.isInitialized) {
      _webViewController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _WordSearchIntent(),
      },
      child: Actions(
        actions: {
          _WordSearchIntent: CallbackAction<_WordSearchIntent>(
            onInvoke: (_) {
              _searchInFile();
              return null;
            },
          ),
        },
        child: AnimatedOpacity(
          opacity: _closing ? 0 : _opacity,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: _totalHeight,
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
                      backgroundColor: Colors.white,
                      onPrint: _printFile,
                      onDownload: _downloadFile,
                      onExpandFullscreen: _openFullscreen,
                      onClose: _closeWithFade,
                      onSearchTap: isWindows && !_initError && _webViewController.value.isInitialized
                          ? () => setState(() => _searchExpanded = !_searchExpanded)
                          : null,
                      searchExpanded: _searchExpanded,
                      searchBarContent: _searchExpanded && isWindows && !_initError ? _buildSearchBarContent() : null,
                      sourceWidget: documentViewerSourceLabel(
                        label: shortUrlForDisplay(widget.wordUrl),
                        url: widget.wordUrl,
                        textColor: Colors.black87,
                      ),
                    ),
                    // Zone 16:9 pour le lecteur Word (fond gris clair + carte blanche pour meilleure lisibilité)
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.white,
                            child: isWindows
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
                                                permissionRequested: (
                                                  String url,
                                                  WebviewPermissionKind kind,
                                                  bool isUserInitiated,
                                                ) async =>
                                                    WebviewPermissionDecision.allow,
                                              );
                                            },
                                          )
                                        : const Center(
                                            child: CircularProgressIndicator(color: Colors.teal),
                                          ))
                                : _buildFallback(),
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
}

class _WordSearchIntent extends Intent {
  const _WordSearchIntent();
}

/// Contenu plein écran pour un document Word (WebView avec viewer Office).
class _WordFullscreenContent extends StatefulWidget {
  const _WordFullscreenContent({required this.wordUrl});

  final String wordUrl;

  @override
  State<_WordFullscreenContent> createState() => _WordFullscreenContentState();
}

class _WordFullscreenContentState extends State<_WordFullscreenContent> {
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
      await _controller.loadUrl(_wordViewerUrl(widget.wordUrl));
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() {});
    }
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
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
          permissionRequested: (
            String url,
            WebviewPermissionKind kind,
            bool isUserInitiated,
          ) async =>
              WebviewPermissionDecision.allow,
        );
      },
    );
  }
}
