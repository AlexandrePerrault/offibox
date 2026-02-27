import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
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
  bool _initError = false;
  String? _initErrorMessage;

  /// Hauteur 16:9 par rapport à la largeur barre.
  double get _panelHeight => widget.barWidth * 9 / 16;

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
    openUrl(widget.xlsUrl);
    _closeWithFade();
  }

  void _downloadFile() {
    if (_closing) return;
    openUrl(widget.xlsUrl);
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
    _webViewController.dispose();
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
                  // Barre du haut : Télécharger, Rechercher (1 loupe), Fermer — alignement horizontal
                  Material(
                    color: const Color(0xFF5A9094),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 10),
                          Tooltip(
                            message: 'Télécharger ce fichier',
                            child: TextButton.icon(
                              onPressed: _downloadFile,
                              icon: const Icon(Icons.download, size: 18, color: Colors.white),
                              label: const Text(
                                'Télécharger ce fichier',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isWindows && !_initError && _webViewController.value.isInitialized) ...[
                            const Text(
                              'Rechercher dans ce fichier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) => _searchInFile(),
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '3 lettres min puis Entrée pour occurrence suivante',
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
                          const Spacer(),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _closeWithFade,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  // Zone 16:9 pour le lecteur
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
      ),
      ),
    );
  }
}

class _XlsSearchIntent extends Intent {
  const _XlsSearchIntent();
}
