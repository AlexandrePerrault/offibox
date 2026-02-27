import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/search/search_engine.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/scan_controller.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';
import 'package:offibox/data/data_loader_core.dart' show buildBdmListFromPrefetched, BdmBuildArgs;
import 'package:offibox/data/data_loader_extra.dart';
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/keywords_parser.dart';
import 'package:offibox/data/lpp_loader.dart';
import 'package:offibox/data/lpp_index.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/biosimilaires_loader.dart' as bio;
import 'package:offibox/data/generiques.dart' as gen;
import 'package:offibox/data/composition_bdm_loader.dart' as comp;
import 'package:offibox/data/hospital_cip_utils.dart' show loadHospitalCipSets, HospitalCipSets, loadCip13HospitaliersFromCsv;
import 'package:offibox/data/exception_otc_loader.dart' show loadExceptionOtcSets, ExceptionOtcSets;
import 'package:offibox/data/statut_cis_loader.dart';
import 'package:offibox/data/cis_dispo_loader.dart' show loadAnsmStatutsByCis, AnsmStatutInfo, loadArretCommercialisationByCis, ArretCommercialisationInfo;
import 'package:offibox/data/taux_remboursement_loader.dart';
import 'package:offibox/data/ansm_rappels_loader.dart';
import 'package:offibox/data/bdm_cip_quantite_loader.dart';
import 'package:offibox/data/bdpm_labels_loader.dart';
import 'package:offibox/data/videos_loader.dart';
import 'package:offibox/data/fiches_voc_loader.dart';
import 'package:offibox/data/fic03spe_loader.dart';
import 'package:offibox/core/search_filter.dart';
import 'package:offibox/utils/open_url.dart' as url_util;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offibox/services/pdf_preloader.dart';
import 'package:offibox/cache/search_warmup.dart';

const String _kAnsmStatutsLastRefreshDateKey = 'ansm_statuts_last_refresh_date';
const String _kAnsmRappelsLastRefreshDateKey = 'ansm_rappels_last_refresh_date';

class OffiboxController extends ChangeNotifier {
  // ========================================================================
  // 🧠 ÉTAT GLOBAL
  // ========================================================================

  String currentQuery = '';
  bool loading = true;
  /// Progression du préchauffage 0–100 (Windows), pour la barre sous le logo.
  int loadingProgress = 0;
  bool extraDataLoaded = false;
  bool _engineReady = false;

  List<SearchResult> allResults = const [];
  List<SearchResult> filteredResults = const [];

  /// CIS → liste des libellés STATUT (col B du CSV statut CIS 2026)
  Map<String, List<String>> statutsByCis = const {};

  /// CIS → info statut ANSM (source : fichiers-medicaments/statutsANSM.csv)
  Map<String, AnsmStatutInfo> ansmStatutsByCis = const {};

  /// CIS → info générique 2026 (princeps : badge "générique de X", RCP/MEDDISPAR en ligne 2).
  Map<String, gen.Generique2026Info> generiques2026ByCis = const {};

  /// Premier mot col B (ex. TAGAMET) → col A en majuscules.
  Map<String, String> generiques2026PrincepsKeyToGenericName = const {};

  /// CIP13 (13 chiffres) → "G" ou "R" (fic03spe ANSM). Badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  Map<String, String> cip13ToFic03Status = const {};

  /// DCI (premier mot col A, ex. ZOLPIDEM) → col A. Pour "générique : X" sur les génériques BDM (évite faux positifs type ALMUS→ENALAPRIL).
  Map<String, String> generiques2026DciToGenericName = const {};

  /// CIS présents dans génériques 2026 (pour masquer RCP/MEDDISPAR en ligne 3).
  Set<String> get generiques2026CisSet => generiques2026ByCis.keys.toSet();

  /// CIP13 présents dans generiques_ansm.csv — filtre « Génériques » et liste des laboratoires.
  Set<String> genericCipSet = const {};

  /// CIP13 → contenu colonne 5 du CSV biosimilaires 2026 (fenêtre « Infos biosimilaire » avec puces).
  Map<String, String> biosimilairesInfoByCip = const {};

  /// CIS → texte colonne B du CSV composition-bdm (badge « composition : [nom] » en ligne 2, sauf génériques).
  Map<String, String> compositionByCis = const {};

  /// CIS → "colD : colE pour colF" depuis CIS_COMPO_bdpm.txt (modale « + d'infos », ligne 1).
  Map<String, String> compositionBdpmByCis = const {};

  /// CIP13 (chiffres) issus de CIP hospitaliers.csv — pour badge « non remboursé » (produit ni hospitalier ni avec taux col I CIS_CIP_bdpm).
  Set<String> hospitalCip13Set = const {};

  /// CIP13 (chiffres seulement) → URL vidéo thérapeutique (feuille videos, col B/C). Pour pill "video" en ligne 2 BDM.
  Map<String, String> videosByCip13 = const {};

  /// Fiches VOC (OMÉDIT) : médicament → URL fiche patient / pro. Pour pills ligne 3 BDM quand le libellé contient un médicament VOC.
  List<VocFicheEntry> fichesVocList = const [];

  late SearchEngine _searchEngine; // réassigné quand phase2 puis extra sont chargés
  Timer? _debounce;
  Timer? _loadingProgressTimer;

  DateTime? lastGithubUpdate;

  final ScanController scanController = ScanController();

  SearchResult? selectedResult;

  /// Payload du dernier scan GS1 (expiration, lot, n° série) — affiché en ligne 1 du résultat injecté.
  Gs1ScanPayload? lastScanPayload;

  /// Noms de produits concernés par un rappel ANSM (col A du CSV rappels) — pour affichage « produit concerné par un rappel de lot N° » en rouge italique.
  Set<String> recalledProductNames = const {};

  /// CIS présents dans CIS_CIP_Dispo_Spec avec « arrêt de commercialisation ». Ces NSFP restent affichés avec un badge dédié.
  Set<String> cisArretCommercialisation = const {};

  /// CIS → date d'arrêt + URL ANSM pour le badge « arrêt de commercialisation » (ligne 2, clic → ouverture URL).
  Map<String, ArretCommercialisationInfo> arretCommercialisationByCis = const {};

  /// CIS → taux de remboursement affichable (ex. "65 %") pour la modale « plus d'infos ».
  Map<String, String> tauxRemboursementByCis = const {};

  /// Statuts pour un CIS donné (liste vide si inconnu).
  List<String> getStatutsForCis(String? cis) {
    if (cis == null || cis.isEmpty) return const [];
    final key = cis.replaceAll(RegExp(r'\D'), '').trim();
    return statutsByCis[key] ?? const [];
  }

  /// Retourne l'entrée VOC si le [label] (libellé affiché) contient le médicament entier (col 1 fiches_voc).
  /// Les fiches patient/pro ne s'affichent que pour les libellés concernés (match sur le libellé complet du médicament).
  VocFicheEntry? getVocFicheForLabel(String? label, [String? query]) {
    if (fichesVocList.isEmpty) return null;
    final labelNorm = (label ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (labelNorm.isEmpty) return null;
    for (final e in fichesVocList) {
      final medNorm = e.medicament.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
      if (medNorm.isEmpty) continue;
      if (labelNorm.contains(medNorm)) return e;
    }
    return null;
  }

  // ========================================================================
  // 📦 INIT
  // ========================================================================

  Future<void> init() async {
    if (_engineReady) return;

    loading = true;
    loadingProgress = 0;
    notifyListeners();

    // Progression par paliers de 10 % (0 → 10 → 20 → … → 50 pendant la phase 1).
    int target = 50;
    _loadingProgressTimer?.cancel();
    _loadingProgressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (loadingProgress >= target) {
        _loadingProgressTimer?.cancel();
        return;
      }
      loadingProgress = (loadingProgress + 10).clamp(0, target);
      notifyListeners();
    });

    // Démarrer phase 2 et données « extra » en parallèle de la phase 1 pour réduire le délai avant affichage complet.
    final phase2Future = _loadPhase2Rest();
    final extraDataFuture = Future.wait([loadExtraData(), loadVideosByCip13(), loadFichesVoc()]);

    // Phase 1 : BDM + outils métier + sites web (affichage rapide). Phase 2 + extra fusionnés ensuite.
    final phase1 = await Future.wait([
      loadHospitalCipSets(),
      loadExceptionOtcSets(),
      bio.loadBiosimilairesByCip(),
      gen.loadGeneriquesByCip(),
      gen.loadPrincepsToGenericName(),
      parseBDM(BDM_URL),
      parseKeywords(OUTILS_METIER_CSV_URL),
      parseKeywords(SITES_WEB_CSV_URL, sourceType: SourceType.siteWeb),
    ]);

    final hospitalSets = phase1[0] as HospitalCipSets;
    final exceptionOtcSets = phase1[1] as ExceptionOtcSets;
    if (kDebugMode) {
      debugPrint('[Offibox] Stupéfiants (badge S/AS): ${hospitalSets.stupCips.length} CIP13');
      debugPrint('[Offibox] Exception: ${exceptionOtcSets.exceptionCips.length} CIP13, OTC/autre: ${exceptionOtcSets.otcCips.length} CIP13 (exception_otc_2026.csv)');
    }
    _loadingProgressTimer?.cancel();
    loadingProgress = 50;
    notifyListeners();
    // Paliers 50 → 60 → … → 100 pendant le compute.
    target = 100;
    _loadingProgressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (loadingProgress >= target) {
        _loadingProgressTimer?.cancel();
        return;
      }
      loadingProgress = (loadingProgress + 10).clamp(0, target);
      notifyListeners();
    });

    final bios = phase1[2] as Map<String, String>;
    final genPrinceps = phase1[3] as Map<String, String>;
    final princepsToGen = phase1[4] as Map<String, String>;
    final bdmRaw = phase1[5] as List<Map<String, dynamic>>;
    final keywords = phase1[6] as List<SearchResult>;
    final sitesWeb = phase1[7] as List<SearchResult>;

    // Date de mise à jour AMC en arrière-plan (n’empêche plus l’affichage « prêt »)
    // Mapping BDM en isolate pour ne pas bloquer l'UI (preload plus rapide).
    final bdmArgs = BdmBuildArgs(
      bdmRaw: bdmRaw,
      stupCips: hospitalSets.stupCips,
      cipHospitaliers: hospitalSets.cipHospitaliers,
      pihCips: hospitalSets.pihCips,
      surveillanceCips: hospitalSets.surveillanceCips,
      exceptionCips: exceptionOtcSets.exceptionCips,
      otcCips: exceptionOtcSets.otcCips,
      biosimilaireByCip: bios,
      generiquePrincepsByCip: genPrinceps,
      princepsToGenericName: princepsToGen,
    );
    final bdmList = await compute(buildBdmListFromPrefetched, bdmArgs);
    final core = [...bdmList, ...keywords, ...sitesWeb];

    allResults = List.unmodifiable(core);
    _searchEngine = SearchEngine(
      allResults,
      genericNameToPrinceps: {},
      dciToCis: {},
      genericCipSet: {},
    );
    _engineReady = true;
    _loadingProgressTimer?.cancel();
    loadingProgress = 100;
    loading = false;
    notifyListeners();

    lastGithubUpdate = null;
    unawaited(fetchLastUpdate(AMC_URL).then((v) {
      lastGithubUpdate = v;
      notifyListeners();
    }),);

    unawaited(_loadPhase2ThenExtra(phase2Future, extraDataFuture, core));
  }

  Future<void> _loadPhase2ThenExtra(
    Future<_Phase2Result> phase2Future,
    Future<List<dynamic>> extraDataFuture,
    List<SearchResult> core,
  ) async {
    final phase2 = await phase2Future;
    if (!_engineReady) return;

    allResults = List.unmodifiable([...core, ...phase2.lpp]);
    compositionByCis = phase2.compositionByCis;
    statutsByCis = phase2.statutsByCis;
    ansmStatutsByCis = phase2.ansmStatutsByCis;
    generiques2026ByCis = phase2.generiques2026ByCis;
    generiques2026PrincepsKeyToGenericName = phase2.generiques2026PrincepsKeyToGenericName;
    generiques2026DciToGenericName = phase2.generiques2026DciToGenericName;
    // Nombre de génériques = CIP13 dont le CIS est en col 4 du CSV génériques 2026 (pas generiques_ansm).
    final generiques2026CisSet = phase2.generiques2026ByCis.keys.toSet();
    final newGenericCipSet = <String>{};
    for (final r in core) {
      if (r.source != SourceType.bdm || r.cip13 == null) continue;
      final cisKey = r.cis?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
      if (cisKey.isNotEmpty && generiques2026CisSet.contains(cisKey)) {
        newGenericCipSet.add(r.cip13!);
      }
    }
    genericCipSet = newGenericCipSet;
    biosimilairesInfoByCip = phase2.biosimilairesInfoByCip;
    recalledProductNames = phase2.recalledProductNames;
    cisArretCommercialisation = phase2.cisArretCommercialisation;
    arretCommercialisationByCis = phase2.arretCommercialisationByCis;
    tauxRemboursementByCis = phase2.tauxRemboursementByCis;
    compositionBdpmByCis = phase2.compositionBdpmByCis;
    hospitalCip13Set = phase2.hospitalCip13Set;
    cip13ToFic03Status = phase2.cip13ToFic03Status;

    _searchEngine = SearchEngine(
      allResults,
      genericNameToPrinceps: phase2.genericNameToPrinceps,
      dciToCis: phase2.dciToCis,
      genericCipSet: newGenericCipSet,
    );
    await _saveAnsmStatutsRefreshDate();
    await _saveAnsmRappelsRefreshDate();
    notifyListeners();

    // Fusionner les données « extra » déjà préchargées en parallèle
    final extraResults = await extraDataFuture;
    final extra = extraResults[0] as List<SearchResult>;
    final videos = extraResults[1] as Map<String, String>;
    final vocList = extraResults[2] as List<VocFicheEntry>;
    allResults = List.unmodifiable([...allResults, ...extra]);
    videosByCip13 = Map.unmodifiable(videos);
    fichesVocList = List.unmodifiable(vocList);
    _searchEngine.updateResults(allResults);
    extraDataLoaded = true;
    notifyListeners();

    if (kDebugMode) {
      final bySource = <SourceType, int>{};
      for (final r in allResults) {
        bySource[r.source] = (bySource[r.source] ?? 0) + 1;
      }
      debugPrint('[Offibox] Données chargées par source: $bySource');
    }

    final cataloguePdfs = allResults
        .where((r) =>
            r.source == SourceType.catalogue &&
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'))
        .toList();
    if (cataloguePdfs.isNotEmpty) {
      unawaited(PdfPreloader.preloadCatalogues(cataloguePdfs));
    }
    unawaited(SearchWarmup.run(engine: _searchEngine));

    unawaited(_refreshAnsmStatutsIfNeeded());
    unawaited(_refreshAnsmRappelsIfNeeded());
  }

  /// Enregistre la date du jour comme date de dernière vérification des statuts ANSM (ruptures, tension, remises).
  Future<void> _saveAnsmStatutsRefreshDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateString();
      await prefs.setString(_kAnsmStatutsLastRefreshDateKey, today);
    } catch (_) {}
  }

  static String _todayDateString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Vérifie les statuts ANSM (BDPM) au moins une fois par jour. Si la dernière vérification n’est pas aujourd’hui, recharge en arrière-plan.
  Future<void> refreshAnsmStatutsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_kAnsmStatutsLastRefreshDateKey);
      final today = _todayDateString();
      if (last == today) return;

      final map = await loadAnsmStatutsByCis();
      if (!_engineReady) return;
      ansmStatutsByCis = map;
      await _saveAnsmStatutsRefreshDate();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAnsmStatutsIfNeeded() async {
    await refreshAnsmStatutsIfNeeded();
  }

  /// Enregistre la date du jour comme date de dernière vérification des rappels de lot ANSM.
  Future<void> _saveAnsmRappelsRefreshDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateString();
      await prefs.setString(_kAnsmRappelsLastRefreshDateKey, today);
    } catch (_) {}
  }

  /// Vérifie les rappels de lot ANSM au moins une fois par jour. Si la dernière vérification n'est pas aujourd'hui, recharge en arrière-plan.
  Future<void> refreshAnsmRappelsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_kAnsmRappelsLastRefreshDateKey);
      final today = _todayDateString();
      if (last == today) return;

      final names = await loadAnsmRappelsProductNames();
      if (!_engineReady) return;
      recalledProductNames = names;
      await _saveAnsmRappelsRefreshDate();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAnsmRappelsIfNeeded() async {
    await refreshAnsmRappelsIfNeeded();
  }

  /// Précharge LPP, composition, statuts, génériques 2026, BdmLibelleCache, rappels (en parallèle de la phase 1).
  Future<_Phase2Result> _loadPhase2Rest() async {
    final results = await Future.wait([
      loadLppResults(),
      comp.loadCompositionBdm(),
      comp.loadCompositionByCis(),
      loadStatutsByCis(),
      loadAnsmStatutsByCis(),
      gen.loadGeneriques2026ByCis(),
      gen.loadGeneriques2026PrincepsKeyToGenericName(),
      gen.loadGeneriques2026DciToGenericName(),
      gen.loadGenericCipSet(),
      bio.loadBiosimilairesInfoByCip(),
      BdmLibelleCache.instance.load(),
      BdpmTxtLabelCache.instance.load(),
      loadAnsmRappelsProductNames(),
      loadArretCommercialisationByCis(),
      loadCompositionBdpmByCis(),
      loadCip13HospitaliersFromCsv(),
      loadCip13ToFic03Status(),
    ]);

    final dciToCis = results[1] as Map<String, List<String>>;
    final genericNameToPrinceps = await gen.loadGenericNameToPrinceps(dciToCis: dciToCis);

    // Taux de remboursement : CIS_CIP_bdpm.txt colonne I (une seule source). Si cellule vide, pas d'entrée → pas d'affichage dans « Plus d'infos ».
    final tauxRemboursementByCis = Map<String, String>.unmodifiable(BdpmTxtLabelCache.instance.cisToTauxRemboursement);

    return _Phase2Result(
      lpp: results[0] as List<SearchResult>,
      dciToCis: dciToCis,
      compositionByCis: results[2] as Map<String, String>,
      statutsByCis: results[3] as Map<String, List<String>>,
      ansmStatutsByCis: results[4] as Map<String, AnsmStatutInfo>,
      generiques2026ByCis: results[5] as Map<String, gen.Generique2026Info>,
      generiques2026PrincepsKeyToGenericName: results[6] as Map<String, String>,
      generiques2026DciToGenericName: results[7] as Map<String, String>,
      genericCipSet: results[8] as Set<String>,
      biosimilairesInfoByCip: results[9] as Map<String, String>,
      recalledProductNames: results[12] as Set<String>,
      genericNameToPrinceps: genericNameToPrinceps,
      cisArretCommercialisation: (results[13] as Map<String, ArretCommercialisationInfo>).keys.toSet(),
      arretCommercialisationByCis: results[13] as Map<String, ArretCommercialisationInfo>,
      tauxRemboursementByCis: tauxRemboursementByCis,
      compositionBdpmByCis: results[14] as Map<String, String>,
      hospitalCip13Set: results[15] as Set<String>,
      cip13ToFic03Status: results[16] as Map<String, String>,
    );
  }

  /// Chargement des données « extra » (catalogues, vidéos, fiches VOC) — appelé via _loadPhase2ThenExtra après préchargement en parallèle.
  Future<void> _loadExtra() async {
    final results = await Future.wait([loadExtraData(), loadVideosByCip13(), loadFichesVoc()]);
    final extra = results[0] as List<SearchResult>;
    final videos = results[1] as Map<String, String>;
    final vocList = results[2] as List<VocFicheEntry>;
    allResults = List.unmodifiable([...allResults, ...extra]);
    videosByCip13 = Map.unmodifiable(videos);
    fichesVocList = List.unmodifiable(vocList);
    _searchEngine.updateResults(allResults);
    extraDataLoaded = true;
    notifyListeners();

    if (kDebugMode) {
      final bySource = <SourceType, int>{};
      for (final r in allResults) {
        bySource[r.source] = (bySource[r.source] ?? 0) + 1;
      }
      debugPrint('[Offibox] Données chargées par source: $bySource');
    }

    final cataloguePdfs = allResults
        .where((r) =>
            r.source == SourceType.catalogue &&
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'),)
        .toList();
    if (cataloguePdfs.isNotEmpty) {
      unawaited(PdfPreloader.preloadCatalogues(cataloguePdfs));
    }
    unawaited(SearchWarmup.run(engine: _searchEngine));
  }

  // ========================================================================
  // 🔎 RECHERCHE
  // ========================================================================
  void filter(String query, {SearchFilter? searchFilter}) {
    if (!_engineReady) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      // Exécuter la recherche après le prochain frame pour éviter le lag à la saisie.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_engineReady) return;
        _runFilter(query, searchFilter);
      });
    });
  }

  /// Lance la recherche immédiatement (sans debounce), ex. à la touche Enter.
  void filterImmediate(String query, {SearchFilter? searchFilter}) {
    if (!_engineReady) return;
    _debounce?.cancel();
    _runFilter(query, searchFilter);
  }

  /// URL Ameli pour un code LPP (7 chiffres) — utilisé aussi pour les codes absents du CSV.
  static String _lppAmeliUrl(String code) =>
      'http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips=$code&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI';

  /// Si la requête est un code LPP 7 chiffres et qu’il n’y a aucun résultat, on affiche quand même une fiche LPP (lien Ameli).
  List<SearchResult> _ensureLppFallback(String query, List<SearchResult> results) {
    final q = query.trim();
    if (results.isNotEmpty || q.length != 7 || !RegExp(r'^\d{7}$').hasMatch(q)) {
      return results;
    }
    final url = _lppAmeliUrl(q);
    lppIndex[q] = url;
    return [mapper.fromLppCode(q, url)];
  }

  void _runFilter(String query, SearchFilter? searchFilter) {
    currentQuery = query;
    lastScanPayload = null;
    var results = _searchEngine.search(query);
    results = _ensureLppFallback(query, results);
    if (searchFilter != null && searchFilter.hasActiveFilters) {
      results = searchFilter.applyTo(results, genericCipSet: genericCipSet, cisArretCommercialisation: cisArretCommercialisation);
    }
    if (identical(results, filteredResults)) return;
    filteredResults = results;
    notifyListeners();
  }

  /// Filtre immédiat (sans debounce) pour scan DataMatrix.
  /// Stocke [payload] (expiration, lot, n° série) pour affichage en ligne 1 du résultat injecté.
  void filterFromScan(String cip13, {SearchFilter? searchFilter, Gs1ScanPayload? payload}) {
    if (!_engineReady) return;

    _debounce?.cancel();
    currentQuery = '';
    lastScanPayload = payload;
    var results = _searchEngine.search(cip13);
    results = _ensureLppFallback(cip13, results);
    if (searchFilter != null && searchFilter.hasActiveFilters) {
      results = searchFilter.applyTo(results, genericCipSet: genericCipSet, cisArretCommercialisation: cisArretCommercialisation);
    }
    filteredResults = const [];
    if (results.isNotEmpty) {
      selectResult(results.first);
    } else {
      notifyListeners();
    }
  }

  /// Réapplique le filtre courant (après changement de filtre côté UI).
  void applyFilter(SearchFilter searchFilter) {
    if (currentQuery.isEmpty || currentQuery.length < 2) return;
    var results = _searchEngine.search(currentQuery);
    results = _ensureLppFallback(currentQuery, results);
    if (searchFilter.hasActiveFilters) {
      results = searchFilter.applyTo(results, genericCipSet: genericCipSet, cisArretCommercialisation: cisArretCommercialisation);
    }
    if (identical(results, filteredResults)) return;
    filteredResults = results;
    notifyListeners();
  }

  /// Affiche tous les résultats d'une source (ex. LPP, DM) dans le panneau de résultats.
  void showFullListForSource(SourceType source) {
    if (!_engineReady) return;
    final results = allResults.where((r) => r.source == source).toList();
    filteredResults = results;
    currentQuery = 'Liste : ${_sourceListLabel(source)}';
    notifyListeners();
  }

  static String _sourceListLabel(SourceType s) {
    switch (s) {
      case SourceType.bdm: return 'Médicaments';
      case SourceType.lpp: return 'LPP';
      case SourceType.dm: return 'Dispositifs médicaux';
      case SourceType.veto: return 'Vétérinaire';
      case SourceType.amc: return 'Mutuelles';
      case SourceType.keyword: return 'Mots-clés';
      case SourceType.siteWeb: return 'Sites web';
      case SourceType.pharmacovigilance: return 'CRPV';
      default: return s.name;
    }
  }

  /// Affiche toute la liste correspondant au filtre courant (ex. tous les stupéfiants, génériques par labo).
  /// Utilisé quand un sous-filtre BDM est sélectionné et que l'utilisateur clique "Afficher la liste".
  void showFullListForFilter(SearchFilter searchFilter) {
    if (!_engineReady || searchFilter.bdmOnlySubFilters.isEmpty) return;
    final results = searchFilter.applyTo(
      List<SearchResult>.from(allResults),
      genericCipSet: genericCipSet,
      cisArretCommercialisation: cisArretCommercialisation,
    );
    filteredResults = results;
    if (searchFilter.bdmOnlySubFilters.length == 1 &&
        searchFilter.bdmOnlySubFilters.first == BdmSubFilter.generiques &&
        searchFilter.genericLaboratory != null &&
        searchFilter.genericLaboratory!.isNotEmpty) {
      currentQuery = 'Liste : Génériques - ${searchFilter.genericLaboratory}';
    } else {
      currentQuery = _fullListQueryLabel(searchFilter.bdmOnlySubFilters);
    }
    notifyListeners();
  }

  static String _fullListQueryLabel(Set<BdmSubFilter> subs) {
    if (subs.isEmpty) return 'Liste : BDM';
    if (subs.length == 1) {
      switch (subs.first) {
        case BdmSubFilter.generiques:
          return 'Liste : Génériques';
        case BdmSubFilter.stupefiants:
          return 'Liste : Stupéfiants et assimilés';
        case BdmSubFilter.mds:
          return 'Liste : MDS';
        case BdmSubFilter.mte:
          return 'Liste : MTE';
        case BdmSubFilter.biosimilaires:
          return 'Liste : Biosimilaires';
        case BdmSubFilter.otc:
          return 'Liste : OTC / autre';
      }
    }
    final labels = subs.map((s) {
      switch (s) {
        case BdmSubFilter.generiques: return 'Génériques';
        case BdmSubFilter.stupefiants: return 'Stupéfiants';
        case BdmSubFilter.mds: return 'MDS';
        case BdmSubFilter.mte: return 'MTE';
        case BdmSubFilter.biosimilaires: return 'Biosimilaires';
        case BdmSubFilter.otc: return 'OTC';
      }
    }).toList();
    return 'Liste : ${labels.join(', ')}';
  }

  // ========================================================================
  // 🌐 OUVERTURE — LOGIQUE FINALE CORRECTE
  // ========================================================================

void onResultTapped(SearchResult item) {
  // 🔴 JAMAIS ouvrir automatiquement
  // 👉 un clic = sélection / injection
  selectResult(item);
}


Future<void> openResult(SearchResult item) async {

  // ⛔ Sécurité absolue : pas d’ouverture si non sélectionné
  if (selectedResult != item) {
    debugPrint('⛔ openResult bloqué : item non sélectionné');
    return;
  }



  if (item.source == SourceType.amc) return;

  // 🐾 VETO
  if (item.source == SourceType.veto) {
    if (item.rcpVetoUrl?.trim().isNotEmpty == true) {
      await openUrl(item.rcpVetoUrl!);
    }
    return;
  }

  // 🩹 DM
  if (item.source == SourceType.dm) {
    if (item.url?.trim().isNotEmpty == true) {
      await openUrl(item.url!);
    }
    return;
  }

 // 🩹 LPP
if (item.source == SourceType.lpp &&
    item.cip13 != null &&
    item.cip13!.length == 7) {

  final url = lppIndex[item.cip13!];
  if (url != null && url.trim().isNotEmpty) {
    await openUrl(url);
  }
  return;
}


  // 💊 BDM → TOUJOURS RCP AU CLIC NOM
  if (item.source == SourceType.bdm) {
    if (item.url?.trim().isNotEmpty == true) {
      await openUrl(item.url!);
    }
  }
}


  Future<void> openUrl(String url) async {
  // Passe par open_url pour déclencher onBeforeOpenLink (refermer la barre, etc.)
  await url_util.openUrl(url);
}


  // ========================================================================
  // 🌐 META
  // ========================================================================

  Future<DateTime?> fetchLastUpdate(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final lastModified = response.headers['last-modified'];
      if (lastModified != null) {
        return HttpDate.parse(lastModified);
      }
    } catch (_) {}
    return null;
  }

  // ========================================================================
  // 🧼 RESET
  // ========================================================================

  void selectResult(SearchResult item) {
    selectedResult = item;
    filteredResults = const [];
    currentQuery = item.label;
    notifyListeners();
  }

  void clearResults() {
    currentQuery = '';
    filteredResults = const [];
    notifyListeners();
  }

  void clearSelection() {
    selectedResult = null;
    notifyListeners();
  }

  void cancelSearch() {
    _debounce?.cancel();
    clearResults();
  }

@override
void dispose() {
  _debounce?.cancel();
  scanController.dispose();
  super.dispose();
}

int resultPriority(SearchResult r) {
  final bool hop  = r.hospitalOnly == true;
  final bool nsfp = r.isNsfpEffective == true;

  // ======================================================
  // 1️⃣ FINS DE LISTE — ORDRE STRICT
  // ======================================================

  // 🟥❌ HOSPITALIER + NSFP → ABSOLUMENT DERNIER
  if (hop && nsfp) {
    return 10000;
  }

  // 🟥 HOSPITALIER SEUL → AVANT-DERNIER
  if (hop) {
    return 9000;
  }

  // ❌ NSFP SEUL → AVANT-AVANT-DERNIER
  if (nsfp) {
    return 8000;
  }

  // ======================================================
  // 2️⃣ PRODUITS ACTIFS — TRI MÉTIER NORMAL
  // ======================================================

  switch (r.source) {
    // 💊 MÉDICAMENTS
    case SourceType.bdm:
      if (r.isOtc == true) return 300; // OTC après RX
      return 100;                      // RX actifs en premier

    // 🐾 VÉTÉRINAIRE
    case SourceType.veto:
      return 400;

    // 🩹 DM / LPP
    case SourceType.dm:
    case SourceType.lpp:
      return 500;

    // 📁 CATALOGUES
    case SourceType.catalogue:
      return 600;

    // 🏷️ Mots-clés / Sites web
    case SourceType.keyword:
    case SourceType.siteWeb:
      return 550;

    // 🏥 MUTUELLES
    case SourceType.amc:
      return 800;

    default:
      return 900;
  }
}

} // OffiboxController

/// Résultat du préchargement phase 2 (LPP, composition, statuts, génériques 2026, etc.).
class _Phase2Result {
  const _Phase2Result({
    required this.lpp,
    required this.dciToCis,
    required this.compositionByCis,
    required this.statutsByCis,
    required this.ansmStatutsByCis,
    required this.generiques2026ByCis,
    required this.generiques2026PrincepsKeyToGenericName,
    required this.generiques2026DciToGenericName,
    required this.genericCipSet,
    required this.biosimilairesInfoByCip,
    required this.recalledProductNames,
    required this.genericNameToPrinceps,
    required this.cisArretCommercialisation,
    required this.arretCommercialisationByCis,
    required this.tauxRemboursementByCis,
    required this.compositionBdpmByCis,
    required this.hospitalCip13Set,
    required this.cip13ToFic03Status,
  });
  final List<SearchResult> lpp;
  final Map<String, List<String>> dciToCis;
  final Map<String, String> compositionByCis;
  final Map<String, List<String>> statutsByCis;
  final Map<String, AnsmStatutInfo> ansmStatutsByCis;
  final Map<String, gen.Generique2026Info> generiques2026ByCis;
  final Map<String, String> generiques2026PrincepsKeyToGenericName;
  final Map<String, String> generiques2026DciToGenericName;
  final Set<String> genericCipSet;
  final Map<String, String> biosimilairesInfoByCip;
  final Set<String> recalledProductNames;
  final Map<String, String> genericNameToPrinceps;
  final Set<String> cisArretCommercialisation;
  final Map<String, ArretCommercialisationInfo> arretCommercialisationByCis;
  final Map<String, String> tauxRemboursementByCis;
  final Map<String, String> compositionBdpmByCis;
  final Set<String> hospitalCip13Set;
  final Map<String, String> cip13ToFic03Status;
}
