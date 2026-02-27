import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/services/pdf_cache.dart';
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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  double _opacity = 0;
  bool _closing = false;
  int _searchSeq = 0;
  Timer? _searchDebounce;
  String _activeQuery = '';

  Future<File>? _pdfFileFuture;

  /// Hauteur 16:9 par rapport à la largeur barre.
  double get _panelHeight => widget.barWidth * 9 / 16;

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
    _pdfFileFuture = PdfCacheService.getCachedPdf(
      pdfUrl: widget.pdfUrl,
      laboratory: widget.laboratory.isEmpty ? 'document' : widget.laboratory,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) setState(() => _opacity = 1);
    });
  }

  void _downloadFile() {
    if (_closing) return;
    openUrl(widget.pdfUrl);
  }

  Future<void> _printFile() async {
    if (_closing || _pdfFileFuture == null) return;
    try {
      final file = await _pdfFileFuture;
      if (file == null || !file.existsSync() || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (_) {}
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
                    // Barre du haut : Télécharger, Recherche (agrandie et centrée), Résultat X/Y, Fermer
                    Material(
                      color: const Color(0xFF5A9094),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 12),
                            // Télécharger
                            Tooltip(
                              message: 'Télécharger ce fichier',
                              child: TextButton.icon(
                                onPressed: _downloadFile,
                                icon: const Icon(Icons.download, size: 20, color: Colors.white),
                                label: const Text(
                                  'Télécharger ce fichier',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Imprimer',
                              child: IconButton(
                                onPressed: _printFile,
                                icon: const Icon(Icons.print, size: 20, color: Colors.white),
                                tooltip: 'Imprimer',
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Groupe recherche : label + champ + bouton (flexible pour éviter overflow)
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.95)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Rechercher dans ce fichier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
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
                                  Tooltip(
                                    message: 'Lancer la recherche (ou Entrée)',
                                    child: IconButton(
                                      onPressed: _searchInFile,
                                      icon: const Icon(Icons.search, size: 22, color: Colors.white),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasResults) ...[
                              const SizedBox(width: 12),
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
                                onPressed: searcher != null && uniquePos > 0
                                    ? () async {
                                        await searcher.goToMatchOfIndex(uniqueIndices[uniquePos - 1]);
                                        if (mounted) setState(() {});
                                      }
                                    : null,
                              ),
                              IconButton(
                                tooltip: 'Occurrence suivante',
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                onPressed: searcher != null && uniquePos >= 0 && uniquePos < total - 1
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
                            const Spacer(),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _closeWithFade,
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.close, size: 22, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    // Zone PDF (16:9)
                    Expanded(
                      child: FutureBuilder<File>(
                        future: _pdfFileFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Erreur chargement PDF',
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () => openUrl(widget.pdfUrl),
                                    icon: const Icon(Icons.open_in_browser, size: 18),
                                    label: const Text('Ouvrir dans le navigateur'),
                                  ),
                                ],
                              ),
                            );
                          }
                          final file = snapshot.data;
                          if (file == null || !snapshot.hasData) {
                            return const Center(
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
                          }
                          return PdfViewer.file(
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
                              textSelectionParams: const PdfTextSelectionParams(),
                              onViewerReady: (_, __) {
                                if (_textSearcher != null) return;
                                _textSearcher = PdfTextSearcher(_controller)..addListener(_onSearchUpdate);
                                setState(() {});
                              },
                            ),
                          );
                        },
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
