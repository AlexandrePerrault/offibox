import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/search/search_engine.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/scan_controller.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';
import 'package:offibox/services/annuaire_sante_rpps_service.dart';
import 'package:offibox/services/annuaire_sante_mssante_service.dart';
import 'package:offibox/data/data_loader_core.dart' show buildBdmListFromPrefetched, BdmBuildArgs;
import 'package:offibox/data/data_loader_extra.dart';
import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/keywords_parser.dart';
import 'package:offibox/data/codes_actes_parser.dart';
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
import 'package:offibox/data/ansm_rappels_loader.dart';
import 'package:offibox/data/bdm_cip_quantite_loader.dart';
import 'package:offibox/data/bdpm_labels_loader.dart';
import 'package:offibox/data/videos_loader.dart';
import 'package:offibox/data/fiches_voc_loader.dart';
import 'package:offibox/data/fic03spe_loader.dart';
import 'package:offibox/core/search_filter.dart';
import 'package:offibox/utils/normalize.dart';
import 'package:offibox/utils/open_url.dart' as url_util;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offibox/services/pdf_preloader.dart';
import 'package:offibox/config/app_config.dart';
import 'package:offibox/services/cerp_client_service.dart';
import 'package:offibox/cache/search_warmup.dart';

const String _kAnsmStatutsLastRefreshDateKey = 'ansm_statuts_last_refresh_date';
const String _kAnsmRappelsLastRefreshDateKey = 'ansm_rappels_last_refresh_date';

/// Nombre max de résultats affichés sous la barre quand on clique sur "+" dans le menu filtre.
const int _kFilterListMaxResults = 30;

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
  Timer? _searchingDelayTimer;
  /// Debounce recherche annuaire (RPPS / nom / structure) : ne lance qu'après arrêt de la frappe pour éviter lag et appels multiples.
  Timer? _rppsLookupDebounce;
  int _searchSeq = 0;
  /// Séquence dédiée au lookup RPPS (pour ignorer les résultats arrivés après une nouvelle requête).
  int _rppsLookupSeq = 0;

  /// True pendant une recherche (utile pour afficher une animation "patientez").
  /// On l’active après un petit délai pour éviter le clignotement sur les recherches instantanées.
  bool searching = false;

  DateTime? lastGithubUpdate;

  final ScanController scanController = ScanController();
  final AnnuaireSanteRppsService _rppsService = AnnuaireSanteRppsService();
  final AnnuaireSanteMssanteService _mssanteService = AnnuaireSanteMssanteService();

  SearchResult? selectedResult;

  /// Pour l'annuaire RPPS : nombre de structures du professionnel au moment de la sélection (badge « Structures » affiché seulement si > 1).
  int? rppsStructureCountForSelected;

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
    // Normalisation "souple" : minuscules, accents retirés, ponctuation ignorée.
    // Permet de matcher des entrées CSV avec accents (ex: "Abémaciclib") sur des labels BDM sans accents.
    final labelNorm = normalizeLooseKeepSpaces(label ?? '');
    if (labelNorm.isEmpty) return null;

    bool containsWord(String haystack, String word) {
      if (word.isEmpty) return false;
      // Match "mot entier" approximatif (on travaille sur une string normalisée avec espaces).
      return haystack == word ||
          haystack.startsWith('$word ') ||
          haystack.endsWith(' $word') ||
          haystack.contains(' $word ');
    }

    for (final e in fichesVocList) {
      final medNorm = normalizeLooseKeepSpaces(e.medicament);
      if (medNorm.isEmpty) continue;
      // 1) Match strict sur l'entrée complète (DCI + marque, ou "marque1, marque2", etc.)
      if (labelNorm.contains(medNorm)) return e;

      // 2) Fallback marque: beaucoup de libellés BDM ne contiennent que la marque (ex: "ALECENSA")
      // alors que le CSV contient "Alectinib ALECENSA". On extrait donc les tokens en MAJ (marques).
      final tokens = e.medicament
          .replaceAll(RegExp(r'[;,\t/()]+'), ' ')
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.length >= 5) // Ignorer les petits mots comme "de", "et"
          .toList(growable: false);

      const exclusions = {'sodium', 'potassium', 'calcium', 'chlorure', 'buvable', 'gelules', 'comprime', 'comprimes', 'solution', 'poudre'};

      for (final t in tokens) {
        final key = normalizeLooseKeepSpaces(t);
        if (key.isEmpty || exclusions.contains(key)) continue;
        if (containsWord(labelNorm, key)) return e;
      }
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

    // Phase 1 : BDM + outils métier + sites web + codes actes (affichage rapide). Phase 2 + extra fusionnés ensuite.
    final phase1 = await Future.wait([
      loadHospitalCipSets(),
      loadExceptionOtcSets(),
      bio.loadBiosimilairesByCip(),
      gen.loadGeneriquesByCip(),
      gen.loadPrincepsToGenericName(),
      parseBDM(BDM_URL),
      parseKeywords(OUTILS_METIER_CSV_URL),
      parseKeywords(SITES_WEB_CSV_URL, sourceType: SourceType.siteWeb),
      parseCodesActesPharmacie(CODES_ACTES_PHARMACIE_URL),
    ]);

    final hospitalSets = phase1[0] as HospitalCipSets;
    final exceptionOtcSets = phase1[1] as ExceptionOtcSets;
    if (kDebugMode) {
      debugPrint('[Offibox] Stupéfiants (badge S/AS): ${hospitalSets.stupCips.length} CIP13');
      debugPrint('[Offibox] Exception: ${exceptionOtcSets.exceptionCips.length} CIP13, OTC/Libre accès: ${exceptionOtcSets.otcCips.length} CIP13 (liste médication officinale)');
    }
    _loadingProgressTimer?.cancel();
    // Ne pas sauter à 50 % : on garde la progression actuelle (10, 20, 30…) et on continue jusqu'à 100.
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
    final codesActes = phase1[8] as List<SearchResult>;

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
    final core = [...bdmList, ...keywords, ...sitesWeb, ...codesActes];

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
    unawaited(_fetchLastGithubUpdate().then((v) {
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
    final extraRaw = extraResults[0] as List<SearchResult>;
    // Toujours copier : loadExtraData() retourne List.unmodifiable (removeWhere échouerait sinon)
    final extra = List<SearchResult>.from(extraRaw);
    // CERP : en version PC standard (cerpFeaturesEnabled = false), on garde les résultats des CSV
    // (Madouest, Co&Pharm) pour que la recherche par CIP/nom soit branchée. Seul le build CERP
    // (cerpFeaturesEnabled = true) filtre selon le statut client CERP BA.
    if (AppConfig.cerpFeaturesEnabled) {
      final cerpOk = await CerpClientService.isCurrentUserCerpBaValidated();
      if (!cerpOk) {
        extra.removeWhere((r) => r.source == SourceType.cerp);
      }
    }
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
      final total = allResults.length;
      if (total <= 5 || (bySource.length == 1 && (bySource[SourceType.catalogue] ?? 0) == total)) {
        debugPrint('[Offibox] → Affichage limité : les messages "non disponible (HTTP 404)" indiquent que les CSV du repo GitHub (offiboxdata) n’ont pas été chargés. Vérifier la connexion, que le repo contient bien les fichiers (LABORATOIRES.csv, BDM_MASTER2026.csv, outils_metier.csv, etc.), ou restaurer les données depuis votre sauvegarde.');
      }
    }

    final cataloguePdfs = allResults
        .where((r) =>
            r.source == SourceType.catalogue &&
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'),
        )
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
  // ignore: unused_element
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
      final total = allResults.length;
      if (total <= 5 || (bySource.length == 1 && (bySource[SourceType.catalogue] ?? 0) == total)) {
        debugPrint('[Offibox] → Affichage limité : les messages "non disponible (HTTP 404)" indiquent que les CSV du repo GitHub (offiboxdata) n’ont pas été chargés. Vérifier la connexion, que le repo contient bien les fichiers (LABORATOIRES.csv, BDM_MASTER2026.csv, outils_metier.csv, etc.), ou restaurer les données depuis votre sauvegarde.');
      }
    }

    final cataloguePdfs = allResults
        .where((r) =>
            r.source == SourceType.catalogue &&
            r.catalogueUrl != null &&
            r.catalogueUrl!.toLowerCase().endsWith('.pdf'),
        )
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

    final seq = ++_searchSeq;
    _scheduleSearchingIndicator(seq);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 85), () {
      // Exécuter la recherche après le prochain frame pour éviter le lag à la saisie.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_engineReady) return;
        if (seq != _searchSeq) return;
        try {
          _runFilter(query, searchFilter, seq);
        } finally {
          _stopSearchingIndicator(seq);
        }
      });
    });
  }

  /// Lance la recherche immédiatement (sans debounce), ex. à la touche Enter.
  void filterImmediate(String query, {SearchFilter? searchFilter}) {
    if (!_engineReady) return;
    _debounce?.cancel();

    final seq = ++_searchSeq;
    _scheduleSearchingIndicator(seq);

    // Laisser un frame pour afficher l’animation avant le travail CPU.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_engineReady) return;
      if (seq != _searchSeq) return;
      try {
        _runFilter(query, searchFilter, seq);
      } finally {
        _stopSearchingIndicator(seq);
      }
    });
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

  /// Normalise une requête tapée avec le clavier AZERTY en « mode minuscule » sur la rangée chiffres :
  /// &→1, é→2, "→3, '→4, (→5, -→6, è→7, _→8, ç→9, à→0 — pour chercher quand même un code (ex. RPPS, CIP, LPP).
  static String _normalizeAzertyNumberRow(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .replaceAll('&', '1')
        .replaceAll('é', '2').replaceAll('É', '2')
        .replaceAll('"', '3')
        .replaceAll("'", '4')
        .replaceAll('(', '5')
        .replaceAll('-', '6')
        .replaceAll('è', '7').replaceAll('È', '7')
        .replaceAll('_', '8')
        .replaceAll('ç', '9').replaceAll('Ç', '9')
        .replaceAll('à', '0').replaceAll('À', '0');
  }

  /// Pour une recherche précise (ex. "biatain 23 Tal") : si un seul médicament BDM contient tous les tokens du libellé, on n'affiche que celui-là.
  static List<SearchResult> _tryPreciseMatchOnly(String query, List<SearchResult> results) {
    final q = query.trim();
    if (q.isEmpty) return results;
    final tokens = q
        .split(RegExp(r'\s+'))
        .map((s) => normalizeLoose(s))
        .where((t) => t.length >= 2 || RegExp(r'^\d+$').hasMatch(t))
        .toList();
    // Important: ne pas "écraser" les recherches courtes type "prava 20" qui doivent
    // retourner plusieurs présentations / labos. On n'applique ce mode précis que
    // lorsque la requête est vraiment descriptive (>= 3 tokens).
    if (tokens.length < 3) return results;
    final bdm = results.where((r) => r.source == SourceType.bdm).toList();
    if (bdm.isEmpty) return results;
    String labelNorm(SearchResult r) => normalizeLoose(r.labelRaw);
    final matches = bdm.where((r) {
      final lab = labelNorm(r);
      for (final t in tokens) {
        if (!lab.contains(t)) return false;
      }
      return true;
    }).toList();
    if (matches.isEmpty) return results;
    if (matches.length == 1) return matches;
    // Plusieurs correspondances : garder le plus spécifique (libellé le plus court)
    matches.sort((a, b) => a.labelRaw.length.compareTo(b.labelRaw.length));
    return [matches.first];
  }

  /// Pour outils métier et sites web : un seul résultat par libellé (col B). Évite les doublons quand le même libellé existe dans les deux CSVs.
  static List<SearchResult> _deduplicateKeywordSiteWebByLibelle(List<SearchResult> results) {
    final seen = <String>{};
    return results.where((r) {
      if (r.source != SourceType.keyword && r.source != SourceType.siteWeb) return true;
      final libelle = (r.commentaire ?? r.label).trim();
      final key = normalizeLooseKeepSpaces(libelle);
      if (key.isEmpty) return true;
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  void _runFilter(String query, SearchFilter? searchFilter, int seq) {
    final trimmed = query.trim();
    final q = _normalizeAzertyNumberRow(trimmed);
    currentQuery = q;
    lastScanPayload = null;
    var results = _searchEngine.search(q);
    results = _ensureLppFallback(q, results);
    if (searchFilter != null && searchFilter.hasActiveFilters) {
      results = searchFilter.applyTo(results, genericCipSet: genericCipSet, cisArretCommercialisation: cisArretCommercialisation);
    }
    results = _tryPreciseMatchOnly(q, results);
    results = OffiboxController._deduplicateKeywordSiteWebByLibelle(results);
    final sameLocal = identical(results, filteredResults);
    if (!sameLocal) {
      filteredResults = results;
      notifyListeners();
    }

    // 🔎 Lookup RPPS (Annuaire Santé) en arrière-plan : ne bloque pas la recherche locale.
    _kickRppsLookupIfNeeded(q, seq);
  }

  static String? _extractRppsFromQuery(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // RPPS = 11 chiffres (ex. 10111946058)
    if (digits.length == 11) return digits;
    return null;
  }

  static ({String? nom, String? prenom})? _extractNameQuery(String raw) {
    final cleaned = raw.trim();
    if (cleaned.length < 2) return null;
    final parts = cleaned
        .split(RegExp(r'[\s,;]+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    // Heuristique simple: 2 premiers tokens = (nom, prenom) mais on testera aussi l'inverse.
    return (nom: parts[0], prenom: parts[1]);
  }

  /// True si la requête ressemble à un nom de structure (ex. pharmacie, cabinet, centre) pour prioriser la recherche par structure.
  static bool _looksLikeStructureQuery(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.length < 2) return false;
    final firstWord = lower.split(RegExp(r'[\s,;]+')).first;
    const structureKeywords = [
      'pharmacie', 'pharmacy', 'cabinet', 'centre', 'center', 'hopital', 'hôpital',
      'clinique', 'clinique', 'laboratoire', 'labo', 'centre', 'maison', 'msp',
      'selarl', 'sarl', 'scop', 'association', 'asso', 'dispensaire', 'officine',
    ];
    if (structureKeywords.any((k) => firstWord.startsWith(k) || firstWord == k)) return true;
    if (lower.contains('pharmacie') || lower.contains('pharmacy')) return true;
    return false;
  }

  /// Délai avant de lancer le lookup annuaire (évite de lancer à chaque frappe et ralentissements).
  static const Duration _rppsLookupDebounceDuration = Duration(milliseconds: 800);

  void _kickRppsLookupIfNeeded(String query, int seq) {
    final q = query.trim();
    if (q.length < 2) return;

    final rpps = _extractRppsFromQuery(q);
    final bool preferStructure = rpps == null && _looksLikeStructureQuery(q);
    final name = (rpps == null && !preferStructure) ? _extractNameQuery(q) : null;
    // Requête structure : seulement si ça ressemble à un nom de structure (pharmacie, cabinet…) et au moins 4 caractères.
    final structureQuery = (rpps == null && name == null && preferStructure && q.length >= 4) ? q : null;
    if (rpps == null && name == null && structureQuery == null) return;

    _rppsLookupDebounce?.cancel();
    _rppsLookupDebounce = Timer(_rppsLookupDebounceDuration, () {
      _rppsLookupDebounce = null;
      _doRppsLookup(query: q, seq: seq, rpps: rpps, name: name, structureQuery: structureQuery);
    });
  }

  void _doRppsLookup({
    required String query,
    required int seq,
    required String? rpps,
    required ({String? nom, String? prenom})? name,
    required String? structureQuery,
  }) {
    final rppsSeq = ++_rppsLookupSeq;
    unawaited(() async {
      // RPPS exact: 1 call. Nom/prénom: 2 calls (ordre + inverse) puis merge. Structure (ex. pharmacie): 1 call.
      List<SearchResult> hits = const [];
      if (rpps != null) {
        hits = await _rppsService.search(rpps: rpps, limit: 20);
      } else if (structureQuery != null) {
        hits = await _rppsService.search(structure: structureQuery, limit: 50);
      } else if (name != null) {
        // Les deux ordres en parallèle pour réduire le temps (ex. ~10s → ~5s si API lente).
        final nameResults = await Future.wait([
          _rppsService.search(nom: name.nom, prenom: name.prenom, limit: 50),
          _rppsService.search(nom: name.prenom, prenom: name.nom, limit: 50),
        ]);
        final a = nameResults[0];
        final b = nameResults[1];
        // Déduplique par RPPS en gardant la "meilleure" structure (cabinet/libéral d'abord).
        final bestById = <String, SearchResult>{};
        for (final r in [...a, ...b]) {
          final id = (r.cip13 ?? '').trim();
          if (id.isEmpty) continue;
          final prev = bestById[id];
          if (prev == null) {
            bestById[id] = r;
            continue;
          }
          final sp = AnnuaireSanteRppsService.preferredStructureScore(prev);
          final sr = AnnuaireSanteRppsService.preferredStructureScore(r);
          if (sr < sp) {
            bestById[id] = r;
            continue;
          }
          if (sr == sp) {
            final ap = (prev.groupLabel ?? '').toLowerCase();
            final ar = (r.groupLabel ?? '').toLowerCase();
            if (ar.compareTo(ap) < 0) bestById[id] = r;
          }
        }
        hits = bestById.values.toList();
      }

      // Tri :
      // - RPPS exact: libéral/cabinet d'abord, puis hôpital.
      // - Nom/Prénom (homonymes): par département croissant (01→97), puis alphabétique.
      if (hits.length > 1) {
        int deptKey(String? d) {
          final raw = (d ?? '').trim();
          if (raw.isEmpty) return 9999;
          final digits = raw.replaceAll(RegExp(r'\D'), '');
          final v = int.tryParse(digits);
          return v ?? 9999;
        }

        if (rpps != null) {
          hits.sort((a, b) {
            final sa = AnnuaireSanteRppsService.preferredStructureScore(a);
            final sb = AnnuaireSanteRppsService.preferredStructureScore(b);
            if (sa != sb) return sa.compareTo(sb);
            final la = (a.groupLabel ?? '').toLowerCase();
            final lb = (b.groupLabel ?? '').toLowerCase();
            return la.compareTo(lb);
          });
        } else {
          // Annuaire RPPS (nom/prénom ou structure) : tri par métier puis département puis libellé.
          hits.sort((a, b) {
            final orderA = AnnuaireSanteRppsService.professionDisplayOrder(a.label);
            final orderB = AnnuaireSanteRppsService.professionDisplayOrder(b.label);
            if (orderA != orderB) return orderA.compareTo(orderB);
            final da = deptKey(a.departement);
            final db = deptKey(b.departement);
            if (da != db) return da.compareTo(db);
            final la = a.labelRaw.toLowerCase();
            final lb = b.labelRaw.toLowerCase();
            return la.compareTo(lb);
          });
        }
      }

      // 📧 BAL MSSanté (personnelle) : enrichit les hits RPPS (1 requête __in max).
      final rppsList = hits
          .map((r) => (r.cip13 ?? '').replaceAll(RegExp(r'\\D'), ''))
          .where((d) => d.length == 11)
          .toList();
      if (rppsList.isNotEmpty) {
        final map = await _mssanteService.fetchPreferredPersonalByRppsList(rppsList);
        if (map.isNotEmpty) {
          hits = hits.map((r) {
            final id = (r.cip13 ?? '').replaceAll(RegExp(r'\\D'), '');
            final mail = id.length == 11 ? map[id] : null;
            return (mail != null && mail.isNotEmpty)
                ? r.copyWith(mssanteEmail: mail)
                : r;
          }).toList();
        }
      }

      if (!_engineReady) return;
      if (seq != _searchSeq) return;
      if (_rppsLookupSeq != rppsSeq) return;
      if (currentQuery.trim() != query) return;
      if (hits.isEmpty) return;

      // Merge sans doublons (RPPS unique via cip13)
      final existing = filteredResults;
      final existingIds = existing
          .where((r) => r.source == SourceType.annuaireSanteRpps)
          .map((r) => (r.cip13 ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final toAdd = <SearchResult>[];
      for (final r in hits) {
        final id = (r.cip13 ?? '').trim();
        if (id.isEmpty || existingIds.contains(id)) continue;
        toAdd.add(r);
      }
      if (toAdd.isEmpty) return;

      // RPPS exact ou requête nom/prénom : on place les résultats annuaire en tête (priorité au professionnel recherché).
      // Requête par structure : on ajoute les résultats annuaire en bas.
      final nameQuery = name != null;
      if (_rppsLookupSeq != rppsSeq) return;
      final next = <SearchResult>[
        if (rpps != null || nameQuery) ...toAdd,
        ...existing,
        if (rpps == null && !nameQuery) ...toAdd,
      ];

      filteredResults = next;
      notifyListeners();
    }());
  }

  /// Filtre immédiat (sans debounce) pour scan DataMatrix ou QR mutuelle.
  /// Si [restrictToSource] est fourni (ex. AMC), ne garde que les résultats de cette source avant de sélectionner.
  void filterFromScan(String cip13, {SearchFilter? searchFilter, Gs1ScanPayload? payload, SourceType? restrictToSource}) {
    if (!_engineReady) return;

    _debounce?.cancel();
    currentQuery = '';
    lastScanPayload = payload;
    var results = _searchEngine.search(cip13);
    results = _ensureLppFallback(cip13, results);
    if (searchFilter != null && searchFilter.hasActiveFilters) {
      results = searchFilter.applyTo(results, genericCipSet: genericCipSet, cisArretCommercialisation: cisArretCommercialisation);
    }
    if (restrictToSource != null) {
      results = results.where((r) => r.source == restrictToSource).toList();
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
    final seq = ++_searchSeq;
    _scheduleSearchingIndicator(seq);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_engineReady) return;
      if (seq != _searchSeq) return;
      try {
        var results = _searchEngine.search(currentQuery);
        results = _ensureLppFallback(currentQuery, results);
        if (searchFilter.hasActiveFilters) {
          results = searchFilter.applyTo(
            results,
            genericCipSet: genericCipSet,
            cisArretCommercialisation: cisArretCommercialisation,
          );
        }
        results = _tryPreciseMatchOnly(currentQuery, results);
        results = _sortByLabelAndTake(results, _kFilterListMaxResults);
        if (identical(results, filteredResults)) return;
        filteredResults = results;
        notifyListeners();
      } finally {
        _stopSearchingIndicator(seq);
      }
    });
  }

  /// Affiche les résultats d'une source (ex. LPP, DM) sous la barre, tri alphabétique, limité à [_kFilterListMaxResults].
  void showFullListForSource(SourceType source) {
    if (!_engineReady) return;
    final results = _sortByLabelAndTake(
      allResults.where((r) => r.source == source).toList(),
      _kFilterListMaxResults,
    );
    filteredResults = results;
    currentQuery = 'Liste : ${_sourceListLabel(source)}';
    notifyListeners();
  }

  static List<SearchResult> _sortByLabelAndTake(List<SearchResult> list, int maxCount) {
    final sorted = List<SearchResult>.from(list);
    sorted.sort((a, b) {
      final la = a.labelRaw.toLowerCase();
      final lb = b.labelRaw.toLowerCase();
      return la.compareTo(lb);
    });
    return sorted.length <= maxCount ? sorted : sorted.sublist(0, maxCount);
  }

  static String _sourceListLabel(SourceType s) {
    switch (s) {
      case SourceType.bdm: return 'Médicaments';
      case SourceType.lpp: return 'LPP';
      case SourceType.dm: return 'Dispositifs médicaux';
      case SourceType.veto: return 'Vétérinaire';
      case SourceType.amo: return 'AMO';
      case SourceType.amc: return 'Mutuelles';
      case SourceType.keyword: return 'Mots-clés';
      case SourceType.siteWeb: return 'Sites web';
      case SourceType.pharmacovigilance: return 'Annuaires';
      case SourceType.centresAntiPoison: return 'Centres anti poison';
      case SourceType.chu: return 'CHU';
      case SourceType.ceipAddictovigilance: return 'Addictovigilance (CEIP-A)';
      case SourceType.annuaireSanteRpps: return 'Annuaire PS';
      default: return s.name;
    }
  }

  /// Affiche la liste correspondant au filtre sous la barre (tri alphabétique, limité à [_kFilterListMaxResults]).
  /// Utilisé quand on clique "+" sur une ligne du menu filtre ou "Afficher la liste".
  void showFullListForFilter(SearchFilter searchFilter) {
    if (!_engineReady || searchFilter.bdmOnlySubFilters.isEmpty) return;
    final results = searchFilter.applyTo(
      List<SearchResult>.from(allResults),
      genericCipSet: genericCipSet,
      cisArretCommercialisation: cisArretCommercialisation,
    );
    filteredResults = _sortByLabelAndTake(results, _kFilterListMaxResults);
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
          return 'Liste : OTC/Libre accès';
      }
    }
    final labels = subs.map((s) {
      switch (s) {
        case BdmSubFilter.generiques: return 'Génériques';
        case BdmSubFilter.stupefiants: return 'Stupéfiants';
        case BdmSubFilter.mds: return 'MDS';
        case BdmSubFilter.mte: return 'MTE';
        case BdmSubFilter.biosimilaires: return 'Biosimilaires';
        case BdmSubFilter.otc: return 'OTC/Libre accès';
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
    if (kDebugMode) debugPrint('⛔ openResult bloqué : item non sélectionné');
    return;
  }



  // 🏥 MUTUELLES (AMC) : ouvrir l’URL dans le panneau web (géré par la fenêtre) ou en secours dans le navigateur
  if (item.source == SourceType.amc) {
    if (item.url?.trim().isNotEmpty == true) {
      await openUrl(item.url!);
    }
    return;
  }

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

  /// Date du dernier commit du dépôt offiboxdata (alignée sur le dernier changement des fichiers GitHub).
  static const String _kGithubRepoCommitsUrl =
      'https://api.github.com/repos/AlexandrePerrault/offiboxdata/commits?per_page=1&sha=main';

  Future<DateTime?> _fetchLastGithubUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_kGithubRepoCommitsUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) return await fetchLastUpdate(AMC_URL);
      final list = json.decode(response.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return await fetchLastUpdate(AMC_URL);
      final commit = list.first as Map<String, dynamic>?;
      final commitObj = commit?['commit'] as Map<String, dynamic>?;
      final committer = commitObj?['committer'] as Map<String, dynamic>?;
      final dateStr = committer?['date'] as String?;
      if (dateStr != null) return DateTime.tryParse(dateStr);
    } catch (_) {}
    return fetchLastUpdate(AMC_URL);
  }

  // ========================================================================
  // 🧼 RESET
  // ========================================================================

  void selectResult(SearchResult item) {
    if (item.source == SourceType.annuaireSanteRpps && item.cip13 != null && item.cip13!.trim().isNotEmpty) {
      final rpps = item.cip13!.trim();
      rppsStructureCountForSelected = filteredResults.where((r) => r.cip13?.trim() == rpps).length;
    } else {
      rppsStructureCountForSelected = null;
    }
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
    rppsStructureCountForSelected = null;
    notifyListeners();
  }

  void cancelSearch() {
    _debounce?.cancel();
    _searchingDelayTimer?.cancel();
    if (searching) {
      searching = false;
      notifyListeners();
    }
    clearResults();
  }

  void _scheduleSearchingIndicator(int seq) {
    _searchingDelayTimer?.cancel();
    // N’affiche l’animation qu’après un délai : évite le flicker.
    _searchingDelayTimer = Timer(const Duration(milliseconds: 100), () {
      if (seq != _searchSeq) return;
      if (!searching) {
        searching = true;
        notifyListeners();
      }
    });
  }

  void _stopSearchingIndicator(int seq) {
    if (seq != _searchSeq) return;
    _searchingDelayTimer?.cancel();
    if (searching) {
      searching = false;
      notifyListeners();
    }
  }

@override
void dispose() {
  _debounce?.cancel();
  _searchingDelayTimer?.cancel();
  _rppsLookupDebounce?.cancel();
  scanController.dispose();
  _rppsService.dispose();
  _mssanteService.dispose();
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


