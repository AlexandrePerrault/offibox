import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:offibox/config/app_config.dart';
import 'package:offibox/constants/catalogue_cart_config.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/services/offibox_ocr_service.dart';
import 'package:offibox/ui/widgets/catalogue_cart_panel.dart';
import 'package:offibox/ui/widgets/document_viewer_toolbar.dart';
import 'package:offibox/services/catalogue_price_catalog_service.dart';
import 'package:offibox/services/pdf_cache.dart' show PdfCacheService, PdfTooLargeException;
import 'package:offibox/utils/open_url.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

/// Panneau PDF sous la barre. Format 16:9, largeur = largeur barre. Chargement via cache + pdfrx (recherche et surbrillance).
class PdfPanelBelowBar extends StatefulWidget {
  const PdfPanelBelowBar({
    super.key,
    required this.pdfUrl,
    required this.barWidth,
    required this.onClose,
    this.laboratory = '',
  });

  final String pdfUrl;
  final double barWidth;
  final VoidCallback onClose;
  /// Libellé pour le cache PDF (ex. nom du catalogue).
  final String laboratory;

  @override
  State<PdfPanelBelowBar> createState() => _PdfPanelBelowBarState();
}

class _PdfPanelBelowBarState extends State<PdfPanelBelowBar> {
  final PdfViewerController _controller = PdfViewerController();
  PdfTextSearcher? _textSearcher;
  final GlobalKey _pdfRepaintKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  double _opacity = 0;
  bool _closing = false;
  bool _searchExpanded = false;
  int _searchSeq = 0;
  Timer? _searchDebounce;
  String _activeQuery = '';

  Future<File>? _pdfFileFuture;

  /// Panier catalogue (uniquement si URL dans CatalogueCartConfig).
  CatalogueCartNotifier? _cartNotifier;
  bool get _cartEnabled => CatalogueCartConfig.isCartEnabledForPdf(widget.pdfUrl);
  bool _pricesLoaded = false;
  bool _ocrRunning = false;

  /// Hauteur 16:9 par rapport à la largeur barre (sans le bandeau logo).
  double get _panelHeight => widget.barWidth * 9 / 16;
  double get _totalHeight => _panelHeight;

  static const Duration _fadeDuration = Duration(milliseconds: 350);

  /// Déduplique les matches : une seule occurrence par (page, position de début) pour éviter "2 résultats" pour un seul mot.
  static List<int> _uniqueMatchIndices(List<PdfPageTextRange> matches) {
    final seen = <String>{};
    final result = <int>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final key = '${m.pageNumber}_${m.start}';
      if (seen.add(key)) result.add(i);
    }
    return result;
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (_cartEnabled) _cartNotifier = CatalogueCartNotifier();
    _pdfFileFuture = PdfCacheService.getCachedPdf(
      pdfUrl: widget.pdfUrl,
      laboratory: widget.laboratory.isEmpty ? 'document' : widget.laboratory,
      allowLarge: _cartEnabled,
    );
    if (_cartEnabled &&
        AppConfig.cerpFeaturesEnabled &&
        CatalogueCartConfig.cerpEquipmentPricesCsvUrl.trim().isNotEmpty) {
      _loadPrices();
    } else {
      _pricesLoaded = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
  }

  Future<void> _loadPrices() async {
    final url = CatalogueCartConfig.cerpEquipmentPricesCsvUrl.trim();
    if (url.isEmpty) return;
    final map = await CataloguePriceCatalogService.loadFromCsvUrl(url);
    if (!mounted || _closing) return;
    _cartNotifier?.setUnitPrices(map);
    setState(() => _pricesLoaded = map.isNotEmpty);
  }

  void _downloadFile() {
    if (_closing) return;
    openUrlExternal(widget.pdfUrl);
  }

  Future<void> _printFile() async {
    if (_closing) return;
    final fileFuture = _pdfFileFuture;
    if (fileFuture == null) return;
    try {
      final file = await fileFuture;
      if (!mounted || _closing) return;
      final bytes = await file.readAsBytes();
      if (!mounted || _closing) return;
      await Printing.layoutPdf(
        name: 'Document',
        onLayout: (_) async => bytes,
      );
    } catch (_) {
      if (!mounted || _closing) return;
      openUrlExternal(widget.pdfUrl);
    }
  }

  void _clearSearch({bool clearText = false}) {
    _searchSeq++;
    _activeQuery = '';
    _textSearcher?.resetTextSearch();
    if (clearText) _searchController.clear();
    if (mounted) setState(() {});
  }

  Future<void> _startSearch(String query) async {
    final searcher = _textSearcher;
    if (searcher == null) return;
    final q = query.trim();
    if (q.isEmpty) {
      _clearSearch(clearText: false);
      return;
    }
    final seq = ++_searchSeq;
    _activeQuery = q;
    searcher.startTextSearch(
      q,
      caseInsensitive: true,
      goToFirstMatch: true,
      searchImmediately: true,
    );
    while (searcher.isSearching && seq == _searchSeq && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (seq != _searchSeq || !mounted) return;
    if (searcher.hasMatches &&
        searcher.matches.isNotEmpty &&
        searcher.currentIndex == null) {
      await searcher.goToMatchOfIndex(0);
    }
    if (mounted) setState(() {});
  }

  Future<void> _searchInFile() async {
    if (_closing) return;
    _startSearch(_searchController.text);
  }

  Future<void> _closeWithFade() async {
    if (_closing) return;
    setState(() => _closing = true);
    await Future<void>.delayed(_fadeDuration);
    if (mounted) widget.onClose();
  }

  void _openCartDialog() {
    if (_closing || _cartNotifier == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: _cartNotifier!,
        builder: (_, __) => CatalogueCartDialog(
          cart: _cartNotifier!,
          onClose: () => Navigator.of(context).pop(),
          francoThresholdEur: CatalogueCartConfig.francoThresholdEur,
          orderRecipientEmail: CatalogueCartConfig.orderRecipientEmail,
          faxNumber: CatalogueCartConfig.faxNumber,
        ),
      ),
    );
  }

  void _onTextSelectionChange(PdfTextSelection? textSelection) {
    if (!_cartEnabled || _cartNotifier == null || _closing || !mounted) return;
    if (textSelection == null || !textSelection.hasSelectedText) return;
    textSelection.getSelectedText().then((text) {
      if (!mounted || _closing) return;
      final code7 = (text ?? '').trim().replaceAll(RegExp(r'\D'), '');
      if (code7.length != 7) return;
      _showAddToCartDialog(code7);
    });
  }

  void _showAddToCartDialog(String code7) {
    if (!mounted || _cartNotifier == null) return;
    int qty = 1;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter au panier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code : $code7', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Nombre de boîtes : '),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: qty > 1 ? () => setState(() => qty--) : null,
                  ),
                  Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => qty++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                _cartNotifier!.add(code7, quantity: qty);
                Navigator.of(ctx).pop();
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runOcrOnVisiblePdf() async {
    if (_closing || !_cartEnabled || _cartNotifier == null || _ocrRunning || !mounted) return;

    final boundary =
        _pdfRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR indisponible (zone PDF non prête).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _ocrRunning = true);
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) {
        throw StateError('capture vide');
      }

      final codes = await OffiboxOcrService.extractCode7FromPngBytes(pngBytes);
      if (!mounted) return;

      if (codes.isEmpty) {
        final msg = Platform.isWindows
            ? 'Aucun code détecté. Sur Windows, installez Tesseract pour l’OCR (tesseract.exe dans le PATH).'
            : 'Aucun code détecté sur la zone visible.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Codes détectés (OCR)'),
          content: SizedBox(
            width: 360,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: codes.length,
              itemBuilder: (context, i) {
                final code = codes[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(Icons.add_shopping_cart),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddToCartDialog(code);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR impossible: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  Widget _buildOcrButton() {
    final enabled = _cartEnabled && _cartNotifier != null && !_closing;
    return Tooltip(
      message: Platform.isWindows
          ? 'OCR codes (Windows: nécessite Tesseract)'
          : 'OCR codes (détecte les codes 7 chiffres)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _runOcrOnVisiblePdf : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _ocrRunning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.text_snippet_outlined, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _openFullscreen() {
    if (_closing || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenDocumentPage(
          onClose: () => Navigator.of(context).pop(),
          child: FutureBuilder<File>(
            future: _pdfFileFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              final file = snapshot.data!;
              if (!file.existsSync()) {
                return const Center(child: Text('Fichier indisponible', style: TextStyle(color: Colors.white)));
              }
              return PdfViewer.file(
                file.path,
                controller: PdfViewerController(),
                params: const PdfViewerParams(textSelectionParams: PdfTextSelectionParams()),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.95)),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 320),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () => _startSearch(v),
                  );
                },
                onSubmitted: (_) => _searchInFile(),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Saisir un mot puis Entrée…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _searchInFile,
          icon: const Icon(Icons.search, size: 22, color: Colors.white),
          tooltip: 'Lancer la recherche (ou Entrée)',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }

  Widget _buildSearchResultWidget(
    PdfTextSearcher searcher,
    List<int> uniqueIndices,
    int uniquePos,
    int total,
    int displayCurrent,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Résultat $displayCurrent / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Occurrence précédente',
          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
          onPressed: uniquePos > 0
              ? () async {
                  await searcher.goToMatchOfIndex(uniqueIndices[uniquePos - 1]);
                  if (mounted) setState(() {});
                }
              : null,
        ),
        IconButton(
          tooltip: 'Occurrence suivante',
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: uniquePos >= 0 && uniquePos < total - 1
              ? () async {
                  await searcher.goToMatchOfIndex(uniqueIndices[uniquePos + 1]);
                  if (mounted) setState(() {});
                }
              : null,
        ),
        IconButton(
          tooltip: 'Effacer la recherche',
          icon: const Icon(Icons.clear, color: Colors.white, size: 20),
          onPressed: () => _clearSearch(clearText: true),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _textSearcher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searcher = _textSearcher;
    final matches = searcher?.matches ?? const [];
    final uniqueIndices = matches.isNotEmpty ? _uniqueMatchIndices(matches) : <int>[];
    final hasResults = searcher != null &&
        _activeQuery.isNotEmpty &&
        searcher.hasMatches &&
        uniqueIndices.isNotEmpty;
    final currentIdx = searcher?.currentIndex ?? -1;
    final uniquePos = currentIdx >= 0 ? uniqueIndices.indexOf(currentIdx) : -1;
    final total = uniqueIndices.length;
    final displayCurrent = uniquePos >= 0 ? uniquePos + 1 : 0;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _PdfSearchIntent(),
      },
      child: Actions(
        actions: {
          _PdfSearchIntent: CallbackAction<_PdfSearchIntent>(
            onInvoke: (_) {
              _searchInFile();
              return null;
            },
          ),
        },
        child: AnimatedOpacity(
          opacity: _closing ? 0 : _opacity,
          duration: _fadeDuration,
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
                      barHeight: 52,
                      backgroundColor: Colors.white,
                      onPrint: _printFile,
                      onDownload: _downloadFile,
                      onExpandFullscreen: _openFullscreen,
                      onClose: _closeWithFade,
                      onSearchTap: () => setState(() => _searchExpanded = !_searchExpanded),
                      searchExpanded: _searchExpanded,
                      searchBarContent: _searchExpanded ? _buildSearchBarContent() : null,
                      searchResultWidget: _searchExpanded && hasResults ? _buildSearchResultWidget(searcher, uniqueIndices, uniquePos, total, displayCurrent) : null,
                      sourceWidget: documentViewerSourceLabel(
                        label: widget.laboratory.isNotEmpty ? widget.laboratory : shortUrlForDisplay(widget.pdfUrl),
                        url: widget.pdfUrl,
                        textColor: Colors.black87,
                      ),
                      trailingActionWidget: _cartEnabled && _cartNotifier != null
                          ? ListenableBuilder(
                              listenable: _cartNotifier!,
                              builder: (_, __) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildOcrButton(),
                                  CatalogueCartIcon(
                                    itemCount: _cartNotifier!.totalItems,
                                    totalAmountEur: _pricesLoaded && !_cartNotifier!.hasUnknownPrices
                                        ? _cartNotifier!.totalAmountEur
                                        : null,
                                    onTap: _openCartDialog,
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                    // Zone PDF (16:9) avec fond gris clair + carte blanche pour mieux détacher le document.
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.all(8),
                        child: RepaintBoundary(
                          key: _pdfRepaintKey,
                          child: FutureBuilder<File>(
                            future: _pdfFileFuture,
                            builder: (context, snapshot) {
                              Widget child;
                              if (snapshot.hasError) {
                                final err = snapshot.error;
                                final isTooLarge = err is PdfTooLargeException;
                                final isTimeout = err is TimeoutException;
                                child = Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isTooLarge ? Icons.picture_as_pdf : Icons.error_outline,
                                          size: 48,
                                          color: isTooLarge ? Colors.orange.shade700 : Colors.red.shade300,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          isTooLarge
                                              ? 'Document volumineux (${(err).sizeMo.toStringAsFixed(1)} Mo)'
                                              : isTimeout
                                                  ? 'Le chargement est trop long'
                                                  : 'Erreur chargement PDF',
                                          style: TextStyle(
                                            color: isTooLarge ? Colors.orange.shade900 : Colors.red.shade700,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          isTooLarge
                                              ? 'Pour un affichage plus rapide, ouvrez-le dans le navigateur.'
                                              : 'Ouvrir dans le navigateur pour essayer ?',
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                          onPressed: () => openUrlExternal(widget.pdfUrl),
                                          icon: const Icon(Icons.open_in_browser, size: 18),
                                          label: const Text('Ouvrir dans le navigateur'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                final file = snapshot.data;
                                if (file == null || !snapshot.hasData) {
                                  child = const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(color: Colors.teal),
                                        SizedBox(height: 12),
                                        Text(
                                          'Chargement du PDF…',
                                          style: TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  child = PdfViewer.file(
                                    file.path,
                                    controller: _controller,
                                    params: PdfViewerParams(
                                      pagePaintCallbacks: _textSearcher != null
                                          ? [
                                              (Canvas canvas, Rect pageRect, PdfPage page) {
                                                try {
                                                  final s = _textSearcher;
                                                  if (s == null || !s.hasMatches || s.matches.isEmpty) return;
                                                  s.pageTextMatchPaintCallback(canvas, pageRect, page);
                                                } catch (_) {}
                                              },
                                            ]
                                          : null,
                                      textSelectionParams: PdfTextSelectionParams(
                                        onTextSelectionChange: _cartEnabled ? _onTextSelectionChange : null,
                                      ),
                                      onViewerReady: (_, __) {
                                        if (_textSearcher != null) return;
                                        _textSearcher = PdfTextSearcher(_controller)..addListener(_onSearchUpdate);
                                        setState(() {});
                                      },
                                    ),
                                  );
                                }
                              }

                              // Carte blanche avec léger rayon pour bien distinguer le document du fond.
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: Colors.white,
                                  child: child,
                                ),
                              );
                            },
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

class _PdfSearchIntent extends Intent {
  const _PdfSearchIntent();
}
