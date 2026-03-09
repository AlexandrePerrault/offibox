import 'dart:async';
import 'dart:ui' show FilterQuality;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/ui/widgets/document_viewer_toolbar.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/platform_utils.dart';
import 'package:webview_windows/webview_windows.dart';

/// URL Microsoft Office Viewer pour afficher un fichier XLS/XLSX (plus fiable que Google Docs pour Excel).
String _xlsViewerUrl(String xlsUrl) {
  final encoded = Uri.encodeComponent(xlsUrl.trim());
  return 'https://view.officeapps.live.com/op/embed.aspx?src=$encoded';
}

/// Panneau XLS/XLSX sous la barre d'info. Format 16:9, largeur = largeur barre. WebView (Windows) ou bouton ouvrir (autres).
class XlsPanelBelowBar extends StatefulWidget {
  const XlsPanelBelowBar({
    super.key,
    required this.xlsUrl,
    required this.barWidth,
    required this.onClose,
  });

  final String xlsUrl;
  final double barWidth;
  final VoidCallback onClose;

  @override
  State<XlsPanelBelowBar> createState() => _XlsPanelBelowBarState();
}

class _XlsPanelBelowBarState extends State<XlsPanelBelowBar> {
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
  /// Requête de recherche en cours (pour afficher le widget Résultat + prev/next).
  String _activeSearchQuery = '';

  /// Hauteur 16:9 par rapport à la largeur barre (sans le bandeau logo).
  double get _panelHeight => widget.barWidth * 9 / 16;
  double get _totalHeight => _panelHeight;

  /// Échappe la chaîne pour l'injection dans du JS (guillemets simples).
  String _escapeJsString(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }

  /// Appelle window.find() dans la WebView (recherche dans les frames). Retourne true si une occurrence a été trouvée.
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
        _initErrorMessage = 'Aperçu XLS disponible sous Windows';
      });
    }
  }

  void _openInBrowserThenClose() {
    if (_closing) return;
    openUrlExternal(widget.xlsUrl);
    _closeWithFade();
  }

  void _downloadFile() {
    if (_closing) return;
    openUrlExternal(widget.xlsUrl);
  }

  void _printFile() {
    if (_closing) return;
    openUrlExternal(widget.xlsUrl);
  }

  /// Lance la recherche : va au premier résultat et affiche la surbrillance (window.find avec searchInFrames).
  Future<void> _searchInFile() async {
    if (_closing || !_webViewController.value.isInitialized) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _activeSearchQuery = '');
      return;
    }
    await _runFind(query, backwards: false);
    if (mounted) setState(() => _activeSearchQuery = query);
  }

  /// Occurrence suivante (comme PDF).
  Future<void> _searchNext() async {
    if (_activeSearchQuery.isEmpty) return;
    await _runFind(_activeSearchQuery, backwards: false);
    if (mounted) setState(() {});
  }

  /// Occurrence précédente (comme PDF).
  Future<void> _searchPrev() async {
    if (_activeSearchQuery.isEmpty) return;
    await _runFind(_activeSearchQuery, backwards: true);
    if (mounted) setState(() {});
  }

  void _clearXlsSearch() {
    _activeSearchQuery = '';
    _searchController.clear();
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _activeSearchQuery = '');
      return;
    }
    if (query.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () => _searchInFile());
    } else {
      setState(() => _activeSearchQuery = '');
    }
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.setBackgroundColor(Colors.white);
      await _webViewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _loadingSubscription = _webViewController.loadingState.listen((LoadingState state) {});
      await _webViewController.loadUrl(_xlsViewerUrl(widget.xlsUrl));
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
          child: _XlsFullscreenContent(xlsUrl: widget.xlsUrl),
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
                hintText: '2 caractères min puis Entrée',
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

  /// Widget « Résultat » + précédent / suivant / effacer (comme pour le PDF).
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
          child: const Text(
            'Résultat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Occurrence précédente',
          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
          onPressed: _searchPrev,
        ),
        IconButton(
          tooltip: 'Occurrence suivante',
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: _searchNext,
        ),
        IconButton(
          tooltip: 'Effacer la recherche',
          icon: const Icon(Icons.clear, color: Colors.white, size: 20),
          onPressed: _clearXlsSearch,
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_chart_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Tableur (XLS / XLSX)',
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
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _XlsSearchIntent(),
      },
      child: Actions(
        actions: {
          _XlsSearchIntent: CallbackAction<_XlsSearchIntent>(
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
                    searchResultWidget: _searchExpanded &&
                            isWindows &&
                            !_initError &&
                            _activeSearchQuery.isNotEmpty
                        ? _buildSearchResultWidget()
                        : null,
                    sourceWidget: documentViewerSourceLabel(
                      label: shortUrlForDisplay(widget.xlsUrl),
                      url: widget.xlsUrl,
                      textColor: Colors.black87,
                    ),
                  ),
                  // Zone 16:9 pour le lecteur (fond gris clair + carte blanche pour meilleure lisibilité)
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

class _XlsSearchIntent extends Intent {
  const _XlsSearchIntent();
}

/// Contenu plein écran pour un fichier XLS (WebView avec viewer Office).
class _XlsFullscreenContent extends StatefulWidget {
  const _XlsFullscreenContent({required this.xlsUrl});

  final String xlsUrl;

  @override
  State<_XlsFullscreenContent> createState() => _XlsFullscreenContentState();
}

class _XlsFullscreenContentState extends State<_XlsFullscreenContent> {
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
      await _controller.loadUrl(_xlsViewerUrl(widget.xlsUrl));
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
