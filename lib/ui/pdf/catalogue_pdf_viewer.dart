import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/services/pdf_cache.dart' show PdfCacheService, PdfTooLargeException;
import 'package:offibox/utils/open_url.dart';
import 'package:pdfrx/pdfrx.dart';

/// Viewer PDF de catalogue avec recherche par mots-clés et recensement de toutes les occurrences.
/// Ex. catalogue Donjoy : recherche "donjoy", affichage "Résultat 1 / 12", précédent/suivant, puces par occurrence.
class CataloguePdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String laboratory;
  final String? initialQuery;
  final bool autoSearch;
  /// Si fourni, affiche un bouton fermer dans l'AppBar (ex. quand le viewer est sous la barre).
  final VoidCallback? onClose;

  const CataloguePdfViewer({
    super.key,
    required this.pdfUrl,
    required this.laboratory,
    this.initialQuery,
    this.autoSearch = false,
    this.onClose,
  });

  @override
  State<CataloguePdfViewer> createState() => _CataloguePdfViewerState();
}

class _CataloguePdfViewerState extends State<CataloguePdfViewer> {
  final PdfViewerController _controller = PdfViewerController();
  /// Créé uniquement dans onViewerReady pour éviter "Null check operator" (controller.document pas encore chargé).
  PdfTextSearcher? _textSearcher;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _activeQuery = '';
  int _searchSeq = 0;
  Timer? _searchDebounce;

  Future<File>? _pdfFileFuture;

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _pdfFileFuture = PdfCacheService.getCachedPdf(
      pdfUrl: widget.pdfUrl,
      laboratory: widget.laboratory,
      allowLarge: true,
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

  /// Déduplique les matches : une seule occurrence par (page, position) pour éviter plusieurs résultats pour un seul mot.
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

  Future<void> _goToIndex(int index) async {
    final searcher = _textSearcher;
    if (searcher == null) return;
    final matches = searcher.matches;
    final uniqueIndices = matches.isNotEmpty ? _uniqueMatchIndices(matches) : <int>[];
    if (index < 0 || index >= uniqueIndices.length) return;
    await searcher.goToMatchOfIndex(uniqueIndices[index]);
    if (mounted) setState(() {});
  }

  static String? _normalizedCodeIfValid(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13) return digits;
    return null;
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

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Fermer',
                onPressed: widget.onClose,
              )
            : null,
        title: const Text('Catalogue PDF'),
        actions: [
          if (hasResults)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Résultat $displayCurrent / $total',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Occurrence précédente',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: hasResults && uniquePos > 0
                ? () async {
                    await searcher.goToMatchOfIndex(uniqueIndices[uniquePos - 1]);
                    if (mounted) setState(() {});
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Occurrence suivante (ou Entrée dans la barre de recherche)',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: hasResults && uniquePos >= 0 && uniquePos < total - 1
                ? () async {
                    await searcher.goToMatchOfIndex(uniqueIndices[uniquePos + 1]);
                    if (mounted) setState(() {});
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Copier le code',
            icon: const Icon(Icons.copy),
            onPressed: () {
              final raw = _searchController.text.trim();
              final toCopy = raw.isEmpty ? null : _normalizedCodeIfValid(raw) ?? raw;
              if (toCopy != null && toCopy.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: toCopy));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copié'),
                    duration: Duration(milliseconds: 900),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Effacer la recherche',
            icon: const Icon(Icons.clear),
            onPressed: () => _clearSearch(clearText: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un mot-clé ou un code dans le catalogue',
                    hintStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.search, size: 22),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _startSearch(v));
                  },
                  onSubmitted: (v) {
                    if (hasResults) {
                      final matches = searcher.matches;
                      final indices = matches.isNotEmpty ? _uniqueMatchIndices(matches) : <int>[];
                      final idx = searcher.currentIndex ?? -1;
                      final pos = idx >= 0 ? indices.indexOf(idx) : -1;
                      if (pos >= 0 && pos < indices.length - 1) {
                        searcher.goToMatchOfIndex(indices[pos + 1]).then((_) { if (mounted) setState(() {}); });
                      } else {
                        _startSearch(v);
                      }
                    } else {
                      _startSearch(v);
                    }
                  },
                ),
                if (hasResults && total > 0) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        total,
                        (k) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text('Occurrence ${k + 1}'),
                            selected: currentIdx == k,
                            onSelected: (_) => _goToIndex(k),
                            selectedColor: const Color(0xFFE65100).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<File>(
              future: _pdfFileFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final err = snapshot.error;
                  final isTooLarge = err is PdfTooLargeException;
                  final isTimeout = err is TimeoutException;
                  return Center(
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
                          if (isTooLarge || isTimeout) ...[
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
                              onPressed: () => openUrl(widget.pdfUrl),
                              icon: const Icon(Icons.open_in_browser, size: 18),
                              label: const Text('Ouvrir dans le navigateur'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                final file = snapshot.data;
                if (file == null || !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
                      if (_textSearcher != null) return; // déjà initialisé
                      _textSearcher = PdfTextSearcher(_controller)..addListener(_onSearchUpdate);
                      if (widget.autoSearch &&
                          widget.initialQuery != null &&
                          widget.initialQuery!.trim().isNotEmpty) {
                        _searchController.text = widget.initialQuery!;
                        _startSearch(widget.initialQuery!);
                      }
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
