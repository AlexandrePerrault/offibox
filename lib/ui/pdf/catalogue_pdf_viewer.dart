import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CataloguePdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String laboratory;
  final String? initialQuery;
  final bool autoSearch;

  const CataloguePdfViewer({
    super.key,
    required this.pdfUrl,
    required this.laboratory,
    this.initialQuery,
    this.autoSearch = false,
  });

  @override
  State<CataloguePdfViewer> createState() => _CataloguePdfViewerState();
}

class _CataloguePdfViewerState extends State<CataloguePdfViewer> {
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();

  PdfTextSearchResult? _searchResult;
  String _activeQuery = '';
  bool _searchReady = false; // ✅ évite "bloqué sur la 1ère"
  int _searchSeq = 0;        // ✅ ignore les vieux résultats (race condition)

  Future<File>? _pdfFileFuture;

  // ─────────────────────────────────────────────
  // 📥 CACHE PDF PAR LABO (inchangé)
  // ─────────────────────────────────────────────
  Future<File> _getPdfFromCache({
    required String url,
    required String laboratory,
  }) async {
    final root = await getTemporaryDirectory();

    final labDir = Directory(
      '${root.path}/offibox/pdf/${laboratory.toLowerCase()}',
    );

    if (!await labDir.exists()) {
      await labDir.create(recursive: true);
    }

    final file = File('${labDir.path}/${url.hashCode}.pdf');

    if (await file.exists()) {
      return file;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Erreur téléchargement PDF');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  // ─────────────────────────────────────────────
  // ✅ CLEAR ROBUSTE
  // ─────────────────────────────────────────────
  void _clearSearch({bool clearText = false}) {
    _searchSeq++; // invalide toute recherche en cours
    _searchReady = false;
    _activeQuery = '';
    _searchResult?.clear();
    _searchResult = null;
    _pdfController.clearSelection();

    if (clearText) _searchController.clear();
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // ✅ Lance une recherche (attend que Syncfusion soit prêt)
  // ─────────────────────────────────────────────
  Future<void> _startSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _clearSearch(clearText: false);
      return;
    }

    final int seq = ++_searchSeq;

    // purge toujours l'ancien état (important)
    _searchReady = false;
    _searchResult?.clear();
    _pdfController.clearSelection();

    _activeQuery = q;

    final r = _pdfController.searchText(q);
    _searchResult = r;

    // Attendre que totalInstanceCount soit dispo (sinon nextInstance "bloque")
    // On écoute quelques notifications puis on déclare "ready".
    final completer = Completer<void>();
    Timer? timeout;

    void checkReady() {
      if (seq != _searchSeq) return; // recherche obsolète
      if ((r.totalInstanceCount) > 0 || r.hasResult == false) {
        // totalInstanceCount > 0 => ok
        // hasResult false peut vouloir dire "0 résultat", on considère prêt aussi
        _searchReady = true;
        if (!completer.isCompleted) completer.complete();
      }
      if (mounted) setState(() {});
    }

    // 1) check immédiat
    checkReady();

    // 2) listener
    r.addListener(checkReady);

    // 3) timeout sécurité (évite de rester bloqué si jamais pas de notif)
    timeout = Timer(const Duration(milliseconds: 900), () {
      if (seq != _searchSeq) return;
      _searchReady = true;
      if (!completer.isCompleted) completer.complete();
      if (mounted) setState(() {});
    });

    await completer.future;

    // clean listener
    timeout?.cancel();
    try {
      r.removeListener(checkReady);
    } catch (_) {}

    // si recherche remplacée entre temps, stop
    if (seq != _searchSeq) return;

    // Syncfusion se place généralement sur la 1ère occurrence automatiquement.
    // On ne fait rien ici : on laisse la 1ère occurrence active.
  }

  // ─────────────────────────────────────────────
  // ✅ NEXT / PREV ROBUSTES
  // ─────────────────────────────────────────────
  Future<void> _next() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;

    // si l'utilisateur a changé le texte, on relance une nouvelle recherche
    if (q != _activeQuery) {
      await _startSearch(q);
      return;
    }

    final r = _searchResult;
    if (r == null) {
      await _startSearch(q);
      return;
    }

    if (!_searchReady) return;
    if (!r.hasResult || r.totalInstanceCount == 0) return;

    // ✅ va vraiment à l'occurrence suivante
    if (r.currentInstanceIndex >= r.totalInstanceCount - 1) {
      // boucle : repartir au début
      await _startSearch(q);
    } else {
      r.nextInstance();
      if (mounted) setState(() {});
    }
  }

  Future<void> _previous() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;

    if (q != _activeQuery) {
      await _startSearch(q);
      return;
    }

    final r = _searchResult;
    if (r == null) {
      await _startSearch(q);
      return;
    }

    if (!_searchReady) return;
    if (!r.hasResult || r.totalInstanceCount == 0) return;

    if (r.currentInstanceIndex <= 0) {
      // boucle : va au dernier
      for (int i = 0; i < r.totalInstanceCount - 1; i++) {
        r.nextInstance();
      }
    } else {
      r.previousInstance();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pdfFileFuture = _getPdfFromCache(
      url: widget.pdfUrl,
      laboratory: widget.laboratory,
    );

    // ✅ dès que le texte change -> on efface l’ancienne recherche (important)
    _searchController.addListener(() {
      final typed = _searchController.text.trim();
      if (_activeQuery.isNotEmpty && typed != _activeQuery) {
        _clearSearch(clearText: false); // n’efface PAS ce que tu tapes
      }
    });

    if (widget.autoSearch &&
        widget.initialQuery != null &&
        widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _searchController.text = widget.initialQuery!.trim();
        await _startSearch(_searchController.text);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final r = _searchResult;
    final hasResults = r != null && r.hasResult && r.totalInstanceCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue PDF'),
        actions: [
          if (hasResults)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Résultat ${r!.currentInstanceIndex + 1}/${r.totalInstanceCount}',
                ),
              ),
            ),
          IconButton(
            tooltip: 'Résultat précédent',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: hasResults ? _previous : null,
          ),
          IconButton(
            tooltip: 'Résultat suivant',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: hasResults ? _next : null,
          ),
          IconButton(
            tooltip: 'Effacer',
            icon: const Icon(Icons.clear),
            onPressed: () => _clearSearch(clearText: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Rechercher dans le PDF',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => _startSearch(v),
            ),
          ),
          Expanded(
            child: FutureBuilder<File>(
              future: _pdfFileFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SfPdfViewer.file(
                  snapshot.data!,
                  controller: _pdfController,
                  enableTextSelection: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
