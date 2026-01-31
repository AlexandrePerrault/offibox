// ============================================================================
// OFFIBOX — main.dart
// ============================================================================
// Application de recherche pharmaceutique multi-sources :
// - Médicaments (BDM)
// - Dispositifs médicaux
// - Vétérinaire
// - Catalogues laboratoires (PDF)
// - Fournisseurs externes (CERP / SERP)
// - Codes LPP / AMC
//
// Ce fichier est volontairement monolithique :
// il centralise UI + logique pour garantir performance & stabilité desktop.
// ============================================================================


// ============================================================================
// 📦 IMPORTS & DÉPENDANCES
// ============================================================================
// Flutter UI, réseau, SVG
// Windows desktop (system tray, window manager)
// Données CSV GitHub + parsers Offibox
// ============================================================================



import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'data/amc_mapper.dart';
import 'data/bdm_parser.dart';
import 'data/keywords_parser.dart';
import 'data/laboratoires_parser.dart';
import 'data/pansements_parser.dart';
import 'data/search_fusion.dart';
import 'data/veto_parser.dart';
import 'models/pansement_item.dart';
import 'models/search_result.dart';
import 'models/veto_item.dart';
import 'ui/pdf/catalogue_pdf_viewer.dart';
import 'data/cip_hospitaliers_parser.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;
import 'utils/gs1_parser.dart';
import 'data/biosimilaires_loader.dart';
import 'data/generiques.dart' as gen;






// ============================================================================
// 🌍 SOURCES DE DONNÉES (CSV GitHub)
// ============================================================================
// Toutes les sources externes sont centralisées ici
// afin de faciliter maintenance, debug et mises à jour.
// ============================================================================

Future<DateTime?> fetchLastUpdate(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    final lastModified = response.headers['last-modified'];
    if (lastModified != null) return parseHttpDate(lastModified);
  } catch (_) {}
  return null;
}

// CSV principaux
const String BDM_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_MASTER2026.csv';

const String PANSEMENTS_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/PANSEMENTS+DM2026.csv';

const String VETO_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/FICHIER%20MED%20VETERINAIRES2026.csv';

const String KEYWORDS_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/keywords.csv';

const String LABORATOIRES_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/LABORATOIRES.csv';

// ✅ NOUVEAU FOURNISSEUR CERP/SERP (produits + URL)
const String CERP_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CERP.csv';

final amcUrl =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/mutuelles_2026.csv';

String medisparUrl(String cip13) =>
    'https://base-donnees-publique.medicaments.gouv.fr/affichageDoc.php?specid=$cip13';


const String STUPEFIANTS_HOP_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/stup%C3%A9fiants%2Bhopital%202026.csv';


const Color offiboxTeal = Color(0xFF5A9094);
const double actionButtonSize = 40;

// ============================================================================
// 🚀 POINT D’ENTRÉE APPLICATION
// ============================================================================
// Démarre Flutter et ouvre la fenêtre Offibox.
// ============================================================================

void main() {
  runApp(const OffiboxApp());
}

// ============================================================================
// ✅ STATUTS (Google Apps Script)
// ============================================================================

Future<List<String>> fetchStatuts(String cip13) async {
  final cleanCip = cip13.replaceAll(RegExp(r'\D'), '');

  final uri = Uri.parse(
    'https://script.google.com/macros/s/AKfycbwW4Lst4Ttb-HSMwMVm-0qMQuhMTJQ4i-MVxCTerYnreX7Ez-EhwoDhHR3EFVvUNor4mQ/exec?cip=$cleanCip',
  );

  final response = await http.get(uri);

  if (response.statusCode != 200 || response.body.startsWith('<')) {
    return [];
  }

  final decoded = jsonDecode(response.body);

  if (decoded is Map && decoded['statuts'] is List) {
    return List<String>.from(decoded['statuts']);
  }

  return [];
}

String normalizeScannedInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');

  // EAN / CIP13 simple
  if (digits.length == 13) return digits;

  // GS1 DataMatrix médicament
  final match = RegExp(r'\(01\)(\d{13,14})').firstMatch(raw);
  if (match != null) {
    final v = match.group(1)!;
    return v.length == 14 ? v.substring(1) : v;
  }

  return raw.trim();
}








// ============================================================================
// 🧱 WIDGET RACINE
// ============================================================================
// Conteneur MaterialApp
// ============================================================================

class OffiboxApp extends StatelessWidget {
  const OffiboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OffiboxWindow(),
    );
  }
}

// ============================================================================
// 🪟 FENÊTRE PRINCIPALE OFFIBOX
// ============================================================================
// Gère la barre flottante, la recherche et les résultats.
// ============================================================================

class OffiboxWindow extends StatefulWidget {
  const OffiboxWindow({super.key});

  @override
  State<OffiboxWindow> createState() => _OffiboxWindowState();
}

// ─────────────────────────────────────────────
// 🔁 KEYS ANTI-LAG
// ─────────────────────────────────────────────

class ExpandedKey extends StatelessWidget {
  final Widget child;
  const ExpandedKey({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: const ValueKey('expanded'), child: child);
  }
}

class CollapsedKey extends StatelessWidget {
  final Widget child;
  const CollapsedKey({super.key, required this.child});





  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: const ValueKey('collapsed'), child: child);
  }
}

// ============================================================================
// 🧠 ÉTAT CENTRAL DE L’APPLICATION
// ============================================================================
// - Chargement & fusion des données
// - Recherche intelligente
// - Gestion UI (barre flottante, résultats, PDF)
// ============================================================================

class _OffiboxWindowState extends State<OffiboxWindow> {
  // Tray / overlay
  OverlayEntry? _copyOverlay;
  final SystemTray _systemTray = SystemTray();

  // Données
  bool loading = true;
  bool showPlaceholder = true;
  bool isLppCodeDetected = false;
  bool _collapsedHovered = false;
  bool menuOpen = false;

  Set<String> _cipHospitaliers = {};
  Set<String> _hopCip7 = {}; // 👈 ICI

  Map<String, String> lppIndex = {}; // code LPP -> URL AMELI

  List<SearchResult> allResults = [];
  List<SearchResult> filteredResults = [];

  int bdmCount = 0;
  int dmCount = 0;
  int vetoCount = 0;
late final Map<String, String> biosimilaireByCip; 

late final Map<String, String> _generiquePrincepsByCip;
late final Map<String, String> _princepsToGenericName;


String safeText(String? input) {
  if (input == null || input.isEmpty) return '';
  return removeInvalidUtf16(input);
}


  // Recherche
  String searchQuery = '';
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool hasFocus = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  // UI barre
  bool expanded = false;
  double topOffset = 40;
  double leftOffset = 16;
  double rightAnchor = 0;


double _resultsHeight() {
    if (filteredResults.isEmpty) return 0;
    const double minHeight = 96.0;
    const double rowHeight = 72.0;
    const double maxHeight = 350.0;
    final wantedHeight = filteredResults.length * rowHeight;
    return wantedHeight.clamp(minHeight, maxHeight);
  }



  // Préchargement (désactivé mais structure conservée)
  double preloadProgress = 0.0;
  bool isPreloading = false;

  DateTime? lastGithubUpdate;

  // Const UI
  static const double barHeight = 72;
  static const double gapBelowBar = 8;
  static const double collapsedWidth = 56;
  static const double logoSizeExpanded = 40;
  static const double initialMarginCm = 114;

  double _currentBarWidth(BuildContext context) {
    return expanded ? MediaQuery.of(context).size.width * 0.8 : collapsedWidth;
  }

  // ==========================================================================
  // 🗓️ FORMAT DATES
  // ==========================================================================

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatAnsmDate(String raw) {
    if (raw.isEmpty) return raw;

    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return '${iso.day.toString().padLeft(2, '0')}/'
          '${iso.month.toString().padLeft(2, '0')}/'
          '${iso.year}';
    }

    final jsRegex = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
    final match = jsRegex.firstMatch(raw);
    if (match != null) {
      const months = {
        'Jan': '01',
        'Feb': '02',
        'Mar': '03',
        'Apr': '04',
        'May': '05',
        'Jun': '06',
        'Jul': '07',
        'Aug': '08',
        'Sep': '09',
        'Oct': '10',
        'Nov': '11',
        'Dec': '12',
      };
      final month = months[match.group(1)];
      final day = match.group(2)!.padLeft(2, '0');
      final year = match.group(3)!;
      if (month != null) return '$day/$month/$year';
    }

    return raw;
  }

 String formatToFrDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;

  // 1) FR : d/M/yyyy ou dd/MM/yyyy (avec ou sans heure)
  final fr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+\d{1,2}:\d{2}:\d{2})?$');
  final mFr = fr.firstMatch(s);
  if (mFr != null) {
    final d = mFr.group(1)!.padLeft(2, '0');
    final m = mFr.group(2)!.padLeft(2, '0');
    final y = mFr.group(3)!;
    return '$d/$m/$y';
  }

  // 2) ISO : yyyy-MM-dd (avec ou sans heure / timezone)
  final isoLike = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$');
  final mIso = isoLike.firstMatch(s);
  if (mIso != null) {
    final y = mIso.group(1)!;
    final m = mIso.group(2)!;
    final d = mIso.group(3)!;
    return '$d/$m/$y';
  }

  // 3) Date JS/texte : Tue Feb 28 2023 ...
  final jsRegex = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
  final match = jsRegex.firstMatch(s);
  if (match != null) {
    const months = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'May': '05',
      'Jun': '06',
      'Jul': '07',
      'Aug': '08',
      'Sep': '09',
      'Oct': '10',
      'Nov': '11',
      'Dec': '12',
    };
    final month = months[match.group(1)];
    final day = match.group(2)!.padLeft(2, '0');
    final year = match.group(3)!;
    if (month != null) return '$day/$month/$year';
  }

  // 4) Dernier recours : tenter parse "classique"
  final dt = DateTime.tryParse(s);
  if (dt != null) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  // Si vraiment impossible
  return s;
}



// ======================================================================
// 🔁 TRI FINAL DES RÉSULTATS
// Ordre :
// 1️⃣ NSFP / hospitaliers → à la fin
// 2️⃣ pertinence (startsWith > contains, labo boost)
// 3️⃣ alphabétique
// ======================================================================
int _compareResults(SearchResult a, SearchResult b) {
  final pa = _priority(a);
  final pb = _priority(b);
  if (pa != pb) return pa.compareTo(pb);

  final sa = _startsWithScore(a);
  final sb = _startsWithScore(b);
  if (sa != sb) return sb.compareTo(sa);

  return a.label.compareTo(b.label);
}





  // ==========================================================================
  // 🟢🟠🔴 HELPERS STATUT ANSM
  // ==========================================================================

  Color ansmColor(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return Colors.red;
    if (s.contains('tension')) return Colors.orange;
    return Colors.green;
  }

  String ansmEmoji(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return '🔴';
    if (s.contains('tension')) return '🟠';
    return '🟢';
  }

  String ansmLabel(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return 'RUPTURE';
    if (s.contains('tension')) return 'TENSION';
    return 'REMIS À DISPOSITION';
  }

  final Map<String, List<String>> _statutCache = {};



  // ==========================================================================
  // INIT / DISPOSE
  // ==========================================================================

 @override
void initState() {
  super.initState();

  loading = true;

  _searchController.addListener(() {
    if (mounted) setState(() {});
  });

  _searchFocus.addListener(() {
    if (mounted) {
      setState(() => hasFocus = _searchFocus.hasFocus);
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      topOffset = initialMarginCm;
      rightAnchor = screenWidth - initialMarginCm;
      leftOffset = rightAnchor - collapsedWidth;
    });

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    await _initSystemTray();
    if (!mounted) return;

    // 🔑 ORDRE CRITIQUE
    await _initData();   // biosimilaires 2026
    if (!mounted) return;

    await _loadAll();    // BDM / DM / VETO / LPP
    if (!mounted) return;

    setState(() {
      loading = false;
    });
  });
}


Future<void> _initData() async {
  // 1️⃣ Biosimilaires
  biosimilaireByCip = await loadBiosimilairesByCip();

_generiquePrincepsByCip = await gen.loadGeneriquesByCip();
_princepsToGenericName = await gen.loadPrincepsToGenericName();
}

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _resultsScrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 🪟 SYSTEM TRAY (safe)
  // ==========================================================================

  Future<void> _initSystemTray() async {
    if (!Platform.isWindows) return;

    try {
      final projectDir = Directory.current.path;
      final iconPath =
          '$projectDir\\windows\\runner\\resources\\logo_offibox.ico';

      if (!File(iconPath).existsSync()) {
        debugPrint('⛔ Icône introuvable: $iconPath');
        return;
      }

      await _systemTray.initSystemTray(
        title: 'Offibox',
        iconPath: iconPath,
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Afficher Offibox',
          onClicked: (_) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuItemLabel(
          label: 'Quitter',
          onClicked: (_) {
            _systemTray.destroy();
            SystemNavigator.pop();
          },
        ),
      ]);

      await _systemTray.setContextMenu(menu);
    } catch (e, st) {
      debugPrint('⛔ SystemTray init failed: $e');
      debugPrint('$st');
    }
  }

  // ==========================================================================
  // 📄 PDF VIEWER
  // ==========================================================================

  void _openCataloguePdf(String url, {required String laboratory}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CataloguePdfViewer(
          pdfUrl: url,
          laboratory: laboratory, // ✅ cache par labo
        ),
      ),
    );
  }

  void _searchInCataloguePdf(SearchResult item, String keyword) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CataloguePdfViewer(
          pdfUrl: item.url!,
          laboratory: item.label, // ✅ le labo s'appelle DONJOY (pas "don't joy")
          initialQuery: keyword,
          autoSearch: true,
        ),
      ),
    );
  }

  // ==========================================================================
  // 🧷 COPY TOAST
  // ==========================================================================

  void _showCopyToast() {
    _copyOverlay?.remove();

    _copyOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topOffset + barHeight + 60,
          left: leftOffset + 16,
          child: Material(
            color: Colors.transparent,
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Copié dans le presse-papier',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_copyOverlay!);

    Future.delayed(const Duration(milliseconds: 1000), () {
      _copyOverlay?.remove();
      _copyOverlay = null;
    });
  }

  // ==========================================================================
  // 🌐 URL LAUNCH
  // ==========================================================================

  Future<void> _openUrl(String url) async {
    final clean = url
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();

    if (!clean.startsWith('http') && !clean.startsWith('tel:')) {
      debugPrint('⛔ URL invalide ignorée : [$clean]');
      return;
    }

    final uri = Uri.parse(clean);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('⛔ Impossible d’ouvrir : $clean');
    }
  }

  // ============================================================================
// 📥 CHARGEMENT GLOBAL DES DONNÉES
// ============================================================================
// Télécharge tous les CSV (BDM, DM, VETO, LABOS, CERP…)
// Fusionne vers SearchResult
// Injecte dans allResults
// ============================================================================


  Future<void> _loadAll() async {
    // 1) dates GitHub
    final dates = await Future.wait<DateTime?>([
      fetchLastUpdate(BDM_URL),
      fetchLastUpdate(PANSEMENTS_URL),
      fetchLastUpdate(VETO_URL),
      fetchLastUpdate(LABORATOIRES_URL),
      fetchLastUpdate(STUPEFIANTS_HOP_URL),
      fetchLastUpdate(KEYWORDS_URL),
      fetchLastUpdate(CERP_URL),
    ]);

    final latest = dates.whereType<DateTime>().isNotEmpty
        ? dates.whereType<DateTime>().reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    // 2) cache-buster
    final bdmUrl = '$BDM_URL?ts=${DateTime.now().millisecondsSinceEpoch}';
    final pansementsUrl =
        '$PANSEMENTS_URL?ts=${DateTime.now().millisecondsSinceEpoch}';
    final vetoUrl = '$VETO_URL?ts=${DateTime.now().millisecondsSinceEpoch}';
    final keywordsUrl =
        '$KEYWORDS_URL?ts=${DateTime.now().millisecondsSinceEpoch}';
    final labosUrl =
        '$LABORATOIRES_URL?ts=${DateTime.now().millisecondsSinceEpoch}';
    final cerpUrl = '$CERP_URL?ts=${DateTime.now().millisecondsSinceEpoch}';

    // 3) futures
    final Future<List<Map<String, dynamic>>> bdmFuture = parseBDM(bdmUrl);
    final Future<List<PansementItem>> pansementsFuture = parsePansements(pansementsUrl);
    final Future<List<VetoItem>> vetoFuture = parseVeto(vetoUrl);
     final Future<List<SearchResult>> keywordsFuture = parseKeywords(keywordsUrl);

    // ⚠️ IMPORTANT : parseLaboratoires doit garder l’URL PDF EXACTE
    // (pas de toLowerCase) pour éviter NoSuchKey sur GCS (DONJOY 2026.pdf).
    final Future<List<SearchResult>> labosFuture = parseLaboratoires(labosUrl);

    // ✅ CERP/SERP : parser simple intégré ici (source = keyword/link)
    final Future<List<SearchResult>> cerpFuture = parseCerp(cerpUrl);

    final Future<Set<String>> hopCip7Future = parseHopCip7(STUPEFIANTS_HOP_URL);


    // 4) load parallèle
    final resultsAll = await Future.wait([
      bdmFuture,
      pansementsFuture,
      vetoFuture,
      hopCip7Future,
      keywordsFuture,
      labosFuture,
      cerpFuture,
    ]);

  final List<Map<String, dynamic>> bdmItems =
    resultsAll[0] as List<Map<String, dynamic>>;
final List<PansementItem> dmItems =
    resultsAll[1] as List<PansementItem>;
final List<VetoItem> vetoItems =
    resultsAll[2] as List<VetoItem>;
final Set<String> hopCip7 =
    resultsAll[3] as Set<String>;
final List<SearchResult> keywordResults =
    resultsAll[4] as List<SearchResult>;
final List<SearchResult> labosResults =
    resultsAll[5] as List<SearchResult>;
final List<SearchResult> cerpResults =
    resultsAll[6] as List<SearchResult>;

_hopCip7 = hopCip7; // 👈 IMPORTANT


    // 5) fuse BDM/DM/VETO
    final results = fuseSearchResults(
      bdm: bdmItems.map((row) {
        // ⛔️ on ne modifie PAS après coup : on construit correctement
       final result = mapper.fromBdm(
  row,
  _cipHospitaliers,
  hopCip7: _hopCip7,
  biosimilaireByCip: biosimilaireByCip,
  generiquePrincepsByCip: _generiquePrincepsByCip,
 princepsToGenericName: _princepsToGenericName,
);

        return result;
      }).toList(),

      dm: dmItems.map<SearchResult>(mapper.fromPansement).toList(),
      veto: vetoItems.map<SearchResult>(mapper.fromVeto).toList(),
    );



    // 6) LPP
    final List<SearchResult> lppResults = [];
    final lppData = await http.get(
      Uri.parse(
        'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/codes_lpp_ameli.csv',
      ),
    );

    if (lppData.statusCode == 200) {
      final lines = const LineSplitter().convert(lppData.body);

      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 2) continue;

        final colA = parts[0]
            .replaceAll('"', '')
            .replaceAll('(CODE LPP)', '')
            .trim();

        final match = RegExp(r'\b\d{7}\b').firstMatch(colA);
        if (match != null) {
          final code = match.group(0)!;
          final url = parts[1].replaceAll('"', '').trim();
          lppIndex[code] = url;
          lppResults.add(mapper.fromLppCode(code, url));
        }
      }
    }





    // 7) AMC
    final List<SearchResult> amcResults = [];
    final amcData = await http.get(
      Uri.parse(
        'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/mutuelles_2026.csv',
      ),
    );

    if (amcData.statusCode == 200) {
      final lines = const LineSplitter().convert(amcData.body);

      for (int i = 1; i < lines.length; i++) {
        final row = lines[i]
            .split(';')
            .map((e) => e.replaceAll('"', '').trim())
            .toList();

        if (row.length >= 2) {
          final nom = row[0];
          final code = row[1];
          final phone = row.length > 2 ? row[2] : null;

          amcResults.add(
            SearchResult(
              source: SourceType.amc,
              label: nom,
              labelRaw: nom,
              cip13: code,
              phone: phone,
              nsfp: false,
              hospitalOnly: false,
              laboratory: '',
            ),
          );
        }
      }
    }

    // 8) inject final
    setState(() {
      allResults = [
        ...labosResults,
        ...results,
        ...keywordResults,
        ...cerpResults, // ✅ CERP/SERP
        ...lppResults,
        ...amcResults,
      ];
      filteredResults = [];
      bdmCount = bdmItems.length;
      dmCount = dmItems.length;
      vetoCount = vetoItems.length;
      lastGithubUpdate = latest ?? DateTime.now();
      loading = false;
    });
  }

  // ==========================================================================
  // ✅ PARSER CERP/SERP (CSV : "nom";"cip";"url")
  // - Recherche par nom (col A) ou CIP7/CIP13 (col B)
  // - Affichage label + badge "PLUS D'INFOS" (clic => url)
  // ==========================================================================
  Future<List<SearchResult>> parseCerp(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final lines = const LineSplitter().convert(response.body);
    final results = <SearchResult>[];

    for (int i = 1; i < lines.length; i++) {
      final row = lines[i]
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();

      if (row.length < 3) continue;

      final name = row[0];
      final cip = row[1].replaceAll(RegExp(r'\D'), '');
      final link = row[2];

      if (name.isEmpty || link.isEmpty) continue;

      // Ici on réutilise SourceType.keyword (lien externe)
      // → pas besoin de toucher aux modèles pour compiler.
      results.add(
        SearchResult(
          source: SourceType.keyword,
          label: name,
          labelRaw: name,
          cip13: cip.isEmpty ? null : cip,
          url: link,
          nsfp: false,
          hospitalOnly: false,
          laboratory: 'CERP',
          // optionnels si ton modèle les a:
          iconUrl: null,
          badge1Name: 'PLUS D’INFOS',
          badge1Url: link,
        ),
      );
    }

    return results;
  }

// ============================================================================
// 💊 PICTOGRAMMES MÉDICAMENTS BDM (widgets – SAFE DESKTOP)
// ============================================================================

List<Widget> medicineIconWidgets(SearchResult item) {
  final widgets = <Widget>[];

  if (item.isStupefiant == true) {
    widgets.add(_picto('🔴', 'Médicament stupéfiant'));
  }

  if (item.liste1 == true) {
    widgets.add(_picto('🔴', 'Médicament Liste I'));
  }

  if (item.liste2 == true) {
    widgets.add(_picto('🟢', 'Médicament Liste II'));
  }

  if (item.biosimilaireOf != null &&
      item.biosimilaireOf!.isNotEmpty) {
    widgets.add(
      _picto('🧬', 'Biosimilaire de ${item.biosimilaireOf}'),
    );
  }

  if (item.hospitalOnly == true) {
    widgets.add(_picto('🟥', 'Usage hospitalier'));
  }

  if (widgets.isNotEmpty) {
    widgets.add(const SizedBox(width: 6));
  }

  return widgets;
}

Widget _picto(String emoji, String tooltip) {
  return Tooltip(
    message: tooltip,
    child: Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        emoji,
        style: const TextStyle(
          fontSize: 16,
          height: 1.0,
        ),
      ),
    ),
  );
}






// ============================================================================
// 🔍 MOTEUR DE RECHERCHE
// ============================================================================
// Recherche tolérante :
// - multi-mots
// - normalisation accent / ponctuation
// - priorité métier
// ============================================================================





  // ==========================================================================
  // 🔧 NORMALISATION & FILTRE
  // ==========================================================================

// ======================================================================
// 🔧 NORMALISATION DES CHAÎNES
// - minuscules
// - suppression de tout sauf lettres/chiffres
// ======================================================================
String _normalize(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

// ======================================================================
// 🧩 EXTRACTION DES BLOCS DE RECHERCHE
// Exemples :
//  - "tram 100 zen" → ["tram", "100", "zen"]
//  - "tramadol" → ["tra", "mad", "ol"]
// Règle :
//  - mots ≤ 3 caractères → pris tels quels
//  - mots > 3 → découpés par blocs de 3 (min 2)
// ======================================================================
List<String> _extractBlocks(String query) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(_normalize)
      .where((t) => t.length >= 2)
      .toList();

  final blocks = <String>[];

  for (final t in tokens) {
    if (t.length <= 3) {
      blocks.add(t);
    } else {
      for (int i = 0; i < t.length; i += 3) {
        final end = (i + 3 <= t.length) ? i + 3 : t.length;
        if (end - i >= 2) {
          blocks.add(t.substring(i, end));
        }
      }
    }
  }

  // suppression des doublons
  return blocks.toSet().toList();
}

// ======================================================================
// 🎯 MATCH D’UN ITEM PAR RAPPORT AUX BLOCS
// Règles :
// - chaque bloc doit matcher (label OU cip)
// - avant 4 lettres : startWith obligatoire
// - après 4 lettres : contains autorisé
// ======================================================================
bool _matchItem({
  required SearchResult r,
  required List<String> blocks,
  required bool allowContains,
}) {
  final label = _normalize(r.labelRaw ?? r.label);
  final cip = _normalize(r.cip13 ?? '');

  final tokens = searchQuery
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(_normalize)
      .where((t) => t.length >= 2)
      .toList();

  if (tokens.isEmpty) return false;

  // ==================================================
  // 🔑 1️⃣ RÈGLE SPÉCIFIQUE BDM (STRICTE)
  // ==================================================
  if (r.source == SourceType.bdm) {
    final first = tokens.first;

    if (first.length >= 3) {
      final starts =
          label.startsWith(first) || cip.startsWith(first);
      if (!starts) return false;
    }

    // 🔴 BDM → max 2 blocs filtrants
    final limit = tokens.length > 2 ? 2 : tokens.length;

    for (int i = 0; i < limit; i++) {
      final b = tokens[i];
      if (!label.contains(b) && !cip.contains(b)) {
        return false;
      }
    }

    return true;
  }

  // ==================================================
  // 🧴 2️⃣ DM / AUTRES : TOUS LES BLOCS COMPTENT
  // ==================================================
  for (final b in tokens) {
    if (!label.contains(b) && !cip.contains(b)) {
      return false;
    }
  }

  return true;
}


// ======================================================================
// 🔢 PRIORITÉ DES RÉSULTATS
// NSFP + hospitaliers → TOUJOURS À LA FIN
// ======================================================================
int _priority(SearchResult r) {
  // ⛔ NSFP TOUJOURS TOUT À LA FIN
  if (r.isNsfpEffective) {
    return 900;
  }

  // 🟥 HOP TOUJOURS TOUT À LA FIN
  if (r.hospitalOnly == true) {
    return 1000;
  }

  // 📦 ORDRE MÉTIER PRINCIPAL
  switch (r.source) {
    case SourceType.bdm:   // 💊 médicaments
      return 0;
    case SourceType.dm:    // 🩹 pansements / DM
      return 100;
    case SourceType.veto:  // 🐾 véto
      return 200;
    case SourceType.amc:   // 🏥 mutuelles
      return 300;
    default:
      return 800; // catalogues, keywords, cerp, etc.
  }
}

// ======================================================================
// 🔍 FILTRAGE DES RÉSULTATS (STARTSWITH PRIORITAIRE)
// ======================================================================
void _filterResults(String q) {
  final query = q.trim().toLowerCase();

  // ─────────────────────────
  // Champ vide → reset
  // ─────────────────────────
  if (query.isEmpty) {
    setState(() {
      searchQuery = '';
      filteredResults = [];
    });
    return;
  }

  searchQuery = query;

  // blocs de recherche (tram / 100 / zen)
  final blocks = _extractBlocks(query);

  if (blocks.isEmpty) {
    setState(() => filteredResults = []);
    return;
  }
List<String> effectiveBlocks;

if (blocks.isEmpty) {
  effectiveBlocks = blocks;
} else if (blocks.length <= 2) {
  effectiveBlocks = blocks;
} else {
  // 🧠 BDM = max 2 blocs, DM = tous les blocs
  effectiveBlocks = blocks;
}



  // règle : contains autorisé seulement après 4 caractères
  final bool allowContains = query.length >= 4;

 final results = allResults.where((r) {
  return _matchItem(
    r: r,
    blocks: effectiveBlocks,
    allowContains: allowContains,
  );
}).toList();


  // tri final (NSFP à la fin, startsWith prioritaire)
  results.sort(_compareResults);

  setState(() {
    filteredResults = results;
  });
}




// ======================================================================
// 📊 SCORE DE PERTINENCE (startWith > contains)
// ======================================================================
int _startsWithScore(SearchResult r) {
  final tokens = searchQuery
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(_normalize)
      .where((t) => t.length >= 2)
      .toList();

  final label = _normalize(r.labelRaw ?? r.label);
  final cip = _normalize(r.cip13 ?? '');
  final lab = _normalize(r.laboratory ?? '');

  int score = 0;

  // 1️⃣ startsWith du premier token (MAJEUR)
  if (tokens.isNotEmpty) {
    if (label.startsWith(tokens[0]) || cip.startsWith(tokens[0])) {
      score += 5;
    }
  }

  // 2️⃣ second token (dosage)
  if (tokens.length >= 2) {
    if (label.contains(tokens[1]) || cip.contains(tokens[1])) {
      score += 3;
    }
  }

  // 3️⃣ troisième token = labo (BOOST UNIQUEMENT)
  if (tokens.length >= 3) {
    if (lab.startsWith(tokens[2]) || label.contains(tokens[2])) {
      score += 2;
    }
  }

  return score;
}


 // ==========================================================================
// 🔍 HIGHLIGHT (robuste, règles Liste / HOP / NSFP respectées)
// ==========================================================================
List<TextSpan> _highlightText(
  BuildContext context,
  String text, {
  required bool italic,
  required bool isHop,
  required bool isNsfp,
}) {
  if (searchQuery.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    ];
  }

  final liste1Regex =
      RegExp(r'\b(liste\s*(1|i))\b', caseSensitive: false);
  final liste2Regex =
      RegExp(r'\b(liste\s*(2|ii))\b', caseSensitive: false);

  final dosageRegex = RegExp(
    r'\b\d+(?:[.,]\d+)?\s?(mg|µg|g|kg|ml|l|%)\b',
    caseSensitive: false,
  );

  final safe = safeText(text);
  final lowerText = safe.toLowerCase();

  final normalizedChars = <String>[];
  final mapIndex = <int>[];

  final reg = RegExp(r'[a-z0-9]');
  for (int i = 0; i < lowerText.length; i++) {
    final ch = lowerText[i];
    if (reg.hasMatch(ch)) {
      normalizedChars.add(ch);
      mapIndex.add(i);
    }
  }

  final normalizedText = normalizedChars.join('');

  final q = searchQuery.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final qNorm = q.replaceAll(RegExp(r'[^a-z0-9]'), '');

  if (qNorm.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    ];
  }

  final blocks = <String>[];
  for (int i = 0; i < qNorm.length; i += 3) {
    blocks.add(
      qNorm.substring(
        i,
        i + 3 > qNorm.length ? qNorm.length : i + 3,
      ),
    );
  }

  final highlight = List<bool>.filled(text.length, false);

  for (final block in blocks) {
    if (block.length < 2) continue;

    int start = 0;
    while (true) {
      final idx = normalizedText.indexOf(block, start);
      if (idx == -1) break;

      for (int k = idx;
          k < idx + block.length && k < mapIndex.length;
          k++) {
        highlight[mapIndex[k]] = true;
      }

      start = idx + 1;
    }
  }

  final themeBase = DefaultTextStyle.of(context).style;

  final baseStyle = themeBase.copyWith(
    color: italic ? Colors.grey : Colors.black,
    fontWeight: italic ? FontWeight.w400 : FontWeight.w700,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  final hiStyle = themeBase.copyWith(
    color: italic ? Colors.grey.shade700 : Colors.black,
    fontWeight: FontWeight.w800,
    backgroundColor: Colors.yellow.withOpacity(0.55),
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  final spans = <TextSpan>[];
  int i = 0;
  final int textLength = text.length;

  while (i < textLength) {
    final m1 = liste1Regex.firstMatch(text.substring(i));
    final m2 = liste2Regex.firstMatch(text.substring(i));

    int? nextListeStart;
    int? nextListeEnd;
    Color? nextListeColor;

    if (m1 != null) {
      nextListeStart = i + m1.start;
      nextListeEnd = i + m1.end;
      nextListeColor = Colors.red;
    }
    if (m2 != null) {
      final s2 = i + m2.start;
      if (nextListeStart == null || s2 < nextListeStart) {
        nextListeStart = s2;
        nextListeEnd = i + m2.end;
        nextListeColor = Colors.green;
      }
    }

    final bool isHi = highlight[i];
    int j = i + 1;
    while (j < textLength && highlight[j] == isHi) {
      j++;
    }

    if (nextListeStart != null &&
        nextListeStart > i &&
        nextListeStart < j) {
      j = nextListeStart;
    }

    if (j <= i) j = i + 1;
    if (j > textLength) j = textLength;

    if (nextListeStart != null && nextListeStart == i) {
      final matchedText =
          text.substring(nextListeStart, nextListeEnd!);

      final bool shouldColorListe = !isHop && !isNsfp;

      spans.add(
        TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            color:
                shouldColorListe ? nextListeColor : baseStyle.color,
            fontWeight: FontWeight.w700,
            fontStyle:
                italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );

      i = nextListeEnd!;
      continue;
    }

    final chunk = text.substring(i, j);
    final bool isDosage = dosageRegex.hasMatch(chunk);

    spans.add(
      TextSpan(
        text: chunk,
        style: (isHi ? hiStyle : baseStyle).copyWith(
          fontWeight: italic
              ? FontWeight.w400
              : (isDosage
                  ? FontWeight.w600
                  : (isHi
                      ? FontWeight.w800
                      : FontWeight.w700)),
        ),
      ),
    );

    i = j;
  }

  return spans;
}

  // ==========================================================================
  // ACTIONS BARRE
  // ==========================================================================
  void _collapseBar() {
    FocusScope.of(context).unfocus();

    setState(() {
      rightAnchor = leftOffset + _currentBarWidth(context);
      expanded = false;
      menuOpen = false;
      leftOffset = rightAnchor - collapsedWidth;
    });
  }

  void _expandBar() {
    setState(() {
      rightAnchor = leftOffset + collapsedWidth;
      expanded = true;
      leftOffset = rightAnchor - MediaQuery.of(context).size.width * 0.8;
    });
  }




  void _openMainDocument(SearchResult item) {
    if (item.source == SourceType.amc) return;


 // 🐾 VÉTO → TOUJOURS ouvrir l’URL du produit
  if (item.source == SourceType.veto) {
    if (item.url != null && item.url!.isNotEmpty) {
      _openUrl(item.url!);
    }
    return;
  }


    if (item.source == SourceType.lpp && item.lppCode != null) {
      final url = lppIndex[item.lppCode!];
      if (url != null) _openUrl(url);
      return;
    }

    if (item.url != null && item.url!.isNotEmpty) {
      _openUrl(item.url!);
    }
  }

  // ==========================================================================
  // UI BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
 final bool showHome =
    _searchController.text.trim().isEmpty &&
    filteredResults.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons != kPrimaryMouseButton) return;
          if (_searchFocus.hasFocus) return;
          if (menuOpen) setState(() => menuOpen = false);
        },
        child: Stack(
          children: [
            Positioned(
              top: topOffset,
              left: leftOffset,
              child: _floatingBar(context),
            ),
            if (menuOpen && !expanded)
              Positioned(
                top: topOffset + 56 + 6,
                left: leftOffset,
                child: _collapsedContextMenu(),
              ),
            if (expanded && filteredResults.isNotEmpty)
              Positioned(
                top: topOffset + barHeight + gapBelowBar,
                left: leftOffset,
                width: _currentBarWidth(context),
                child: _resultsPanel(),
              ),
          ],
        ),
      ),
    );
  }

WidgetSpan hopSquareSpan({
  String tooltip = 'Réservé à l’usage hospitalier',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'HOP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    ),
  );
}





WidgetSpan stupSquareSpan({
  String tooltip =
      'Médicament stupéfiant ou assimilé stupéfiant',
  String url =
      'https://www.meddispar.fr/Substances-veneneuses/Medicaments-stupefiants-et-assimiles/Criteres#nav-buttons',
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(4),
        child: IntrinsicWidth( // ✅ empêche toute expansion
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6, // 👈 élargi de qq pixels
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'S/AS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}





// ==========================================================================
// 🔍 SEARCH BAR
// ==========================================================================
Widget _searchBarContent() {
  final bool showPlaceholder =
      _searchController.text.isEmpty && !_searchFocus.hasFocus;

  return Listener(
    onPointerDown: (_) {},
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            const Positioned(
              left: 0,
              child: Icon(Icons.search, color: Colors.grey),
            ),

            // ===============================
            // ✏️ CHAMP DE RECHERCHE
            // ===============================
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (raw) {
                  final normalized = normalizeScannedInput(raw);

                  // 🔒 évite boucle infinie
                  if (normalized != raw) {
                    _searchController.value = TextEditingValue(
                      text: normalized,
                      selection: TextSelection.collapsed(
                        offset: normalized.length,
                      ),
                    );
                    return;
                  }

                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 120),
                    () => _filterResults(normalized),
                  );
                },
              ),
            ),

            // ===============================
            // 🏷️ PLACEHOLDER
            // ===============================
            if (_searchController.text.isEmpty)
              IgnorePointer(
                ignoring: true,
                child: Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Rechercher sur',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Image.asset(
                        'assets/icons/logo_offibox_text.png',
                        height: 18,
                      ),
                    ],
                  ),
                ),
              ),

            // ===============================
            // 📅 DATE MAJ
            // ===============================
            if (lastGithubUpdate != null && showPlaceholder)
              Positioned(
                right: 12,
                bottom: 6,
                child: Text(
                  'Dernière mise à jour le ${formatDate(lastGithubUpdate!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
  // ==========================================================================
  // 🟨 FLOATING BAR (AnimatedSwitcher stable)
  // ==========================================================================
  Widget _floatingBar(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    final double targetWidth = expanded ? screenWidth * 0.8 : collapsedWidth;
    final double targetHeight = expanded ? barHeight : collapsedWidth;

    final BorderRadius targetRadius = expanded
        ? BorderRadius.circular(barHeight / 2)
        : BorderRadius.circular(15);

    final GestureDragUpdateCallback? panUpdate =
        (!expanded || _searchFocus.hasFocus)
            ? null
            : (details) {
                leftOffset += details.delta.dx;
                topOffset += details.delta.dy;
                WidgetsBinding.instance.scheduleFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              };

    final GestureDragEndCallback? panEnd = (!expanded || _searchFocus.hasFocus)
        ? null
        : (_) {
            if (mounted) {
              setState(() {
                rightAnchor = leftOffset + _currentBarWidth(context);
              });
            }
          };

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: panUpdate,
      onPanEnd: panEnd,
      child: RepaintBoundary(
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: targetRadius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previous,
                    if (current != null) current,
                  ],
                );
              },
              child: expanded ? const _ExpandedKey() : const _CollapsedKey(),
            ),
          ),
        ),
      ),
    );
  }

Widget _expandedContent() {
final bool showHome = searchQuery.trim().isEmpty;

  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ============================================================
            // 🔎 BARRE DE RECHERCHE (TOUJOURS VISIBLE)
            // ============================================================
            SizedBox(
              height: barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: actionButtonSize,
                      height: actionButtonSize,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.tune, size: 22),
                        onPressed: () {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _searchBarContent()),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _collapseBar,
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: actionButtonSize,
                            height: actionButtonSize,
                            child: Center(
                              child: Image.asset(
                                'assets/icons/logo_offibox.png',
                                height: logoSizeExpanded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: actionButtonSize,
                          height: actionButtonSize,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.menu, size: 22),
                            onPressed: () =>
                                debugPrint('🍔 Hamburger cliqué'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ============================================================
            // ⏳ PRÉCHARGEMENT (inchangé)
            // ============================================================
            if (isPreloading) const SizedBox(height: 2),
            if (isPreloading)
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: preloadProgress,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF5A9094)),
                ),
              ),

            // ============================================================
            // 🏠 HOME (logo + aide) OU 📋 RÉSULTATS
            // ============================================================
Expanded(
  child: AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    child: showHome
        ? Column(
            key: const ValueKey('home'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OffiboxLogo(),
              const SizedBox(height: 12),
              OffiboxLogoText(),
              const SizedBox(height: 16),
              SearchHelpButtons(),
            ],
          )
        : _resultsPanel(),
  ),
),
          ],
        ),
      );
    },
  );
}

  Widget _collapsedContent() {
    const double size = 56;

    return MouseRegion(
      onEnter: (_) {
        if (!_collapsedHovered && mounted) setState(() => _collapsedHovered = true);
      },
      onExit: (_) {
        if (_collapsedHovered && mounted) setState(() => _collapsedHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expandBar,
        onPanUpdate: (details) {
          setState(() {
            leftOffset += details.delta.dx;
            topOffset += details.delta.dy;
            rightAnchor = leftOffset + collapsedWidth;
          });
        },
        onPanEnd: (_) {
          setState(() {
            rightAnchor = leftOffset + collapsedWidth;
          });
        },
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_collapsedHovered ? 0.25 : 0.18),
                  blurRadius: _collapsedHovered ? 26 : 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Transform.scale(
                  scale: 1.15,
                  child: Image.asset(
                    'assets/icons/logo_offibox.png',
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsedContextMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              icon: Icons.expand_less,
              label: 'Réduire',
              onTap: () => setState(() {
                expanded = false;
                menuOpen = false;
              }),
            ),
            _menuItem(
              icon: Icons.close,
              label: 'Fermer',
              onTap: () {
                menuOpen = false;
                SystemNavigator.pop();
              },
            ),
            _menuItem(
              icon: Icons.open_in_new,
              label: 'Ouvrir Officebox.fr',
              onTap: () {
                setState(() => menuOpen = false);
                _openUrl('https://officebox.fr');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5A9094)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
// ============================================================================
// 🎯 PANNEAU DES RÉSULTATS
// ============================================================================
// Affiche la liste filtrée avec pictos, badges et actions
// ============================================================================
Widget _resultsPanel() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutQuart,
    height: _resultsHeight(),
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ListView.builder(
      controller: _resultsScrollController,
      physics: const ClampingScrollPhysics(),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final item = filteredResults[index];

        final String cipKey =
            item.cip13?.replaceAll(RegExp(r'\D'), '').trim() ?? '';

        

        String displayLabel = item.label;
        if (item.source == SourceType.veto) {
          displayLabel = displayLabel
              .replaceFirst(RegExp(r'^\s*(?:🐾\s*)+'), '')
              .replaceFirst(
                RegExp(r'^\(VETO\)\s*🐾\s*', caseSensitive: false),
                '(VETO) ',
              )
              .trimLeft();
        }


        final label = displayLabel
            .replaceAll(RegExp(r'\(BIOSIMILAIRE\)', caseSensitive: false), '')
            .replaceAll(
              RegExp(r'\s*–\s*biosimilaire de [^–]+$',
                  caseSensitive: false),
              '',
            )
            .replaceAll('(EXCEPTION)', '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();

     

 final bool hasNsfpDate =
    item.nsfpDate != null && item.nsfpDate!.trim().isNotEmpty;

        final bool isPdfItem = item.isPdf && item.url != null;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 220 + index * 25),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: child,
              ),
            );
          },
          child: ListTile(
            onTap: () => _openMainDocument(item),
            dense: true,
            visualDensity: const VisualDensity(vertical: -3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    // ─────────────────────────
    // LIGNE 1 — 💊 + PICTOS + TEXTE
    // ─────────────────────────
    RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: [
          sourceIconSpan(item),

          if (item.source == SourceType.bdm)
            ...medicineIconSpans(item),

          if (hasNsfpDate)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: 'Ne se fait plus',
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: const Text('❌', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),

          ..._highlightText(
            context,
            label,
            italic: item.isInactive,
            isHop: item.hospitalOnly == true,
            isNsfp: item.isNsfpEffective,
          ),

          if (hasNsfpDate)
            TextSpan(
              text:
                  '  (date d’arrêt le ${formatToFrDate(item.nsfpDate!)})',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    ),

    // ─────────────────────────
    // LIGNE 2 — BADGES / ACTIONS
    // ─────────────────────────
    if (item.source == SourceType.bdm ||
        item.source == SourceType.veto ||
        item.source == SourceType.dm ||
        item.source == SourceType.amc ||
        item.source == SourceType.catalogue ||
        item.source == SourceType.keyword)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: RichText(
          text: TextSpan(
            children: [

              // 🧬 BIOSIMILAIRE
              if (item.source == SourceType.bdm &&
                  item.biosimilaireOf?.isNotEmpty == true)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _openUrl(
                        'https://ansm.sante.fr/documents/reference/medicaments-biosimilaires',
                      ),
                      child: _badgeContainer(
                        text:
                            'BIOSIMILAIRE DE ${item.biosimilaireOf}',
                      ),
                    ),
                  ),
                ),

              // 🧬 BIORÉFÉRENT
              if (item.source == SourceType.bdm &&
                  item.biosimilaireOf?.isEmpty != false &&
                  item.isGeneric != true)
                bioreferentBadgeSpan(),

              // 🧬 GÉNÉRIQUE / PRINCEPS
              if (genericBadgeSpan(item) != null)
                genericBadgeSpan(item)!,

              if (princepsBadgeSpan(item) != null)
                princepsBadgeSpan(item)!,

              // 📋 COPIER CIP
              if ((item.source == SourceType.bdm ||
                      item.source == SourceType.dm ||
                      item.source == SourceType.veto) &&
                  item.cip13?.isNotEmpty == true)
                copyPillSpan(
                  context: context,
                  value: item.cip13!,
                  tooltip: 'Copier le code produit',
                ),

              // 📄 RCP
              if (item.source == SourceType.bdm &&
                  item.url?.isNotEmpty == true)
                rcpSpan(onTap: () => _openUrl(item.url!)),

              if (item.source == SourceType.veto &&
                  item.url?.isNotEmpty == true)
                rcpVetoSpan(onTap: () => _openUrl(item.url!)),

              // ⚠️ MEDDISPAR
              if (item.source == SourceType.bdm &&
                  item.meddisparUrl?.isNotEmpty == true)
                medisparSpan(
                  onTap: () => _openUrl(item.meddisparUrl!),
                ),
            ],
          ),
        ),
      ),
  ],
);



// ============================================================================
// 💊 PICTOGRAMMES MÉDICAMENTS BDM
// ============================================================================
// Icônes métier : stupéfiant, listes, biosimilaires, OTC, hospitalier
// ============================================================================

List<InlineSpan> medicineIconSpans(SearchResult item) {
  final List<InlineSpan> spans = [];
  final raw = (item.labelRaw ?? item.label).toLowerCase();

  // 🟥 HOP — USAGE HOSPITALIER (TOUJOURS EN PREMIER)
  if (item.hospitalOnly == true) {
    spans.add(
      hopSquareSpan(
        tooltip: 'Réservé à l’usage hospitalier',
      ),
    );
  }

  // 🚨 STUPÉFIANT
  if (item.isStupefiant == true) {
    spans.add(
      stupSquareSpan(
        tooltip: 'Médicament stupéfiant ou assimilé stupéfiant',
        url: 'https://www.meddispar.fr/Substances-veneneuses/Medicaments-stupefiants-et-assimiles/Criteres#nav-buttons',
      ),
    );
  }



  // 🧬 Biosimilaire
  if (item.biosimilaireOf != null || raw.contains('biosimilaire')) {
    spans.add(
      clickableMarkerSpan(
        emoji: '🧬',
        tooltip: item.biosimilaireOf != null &&
                item.biosimilaireOf!.isNotEmpty
            ? 'Biosimilaire de ${item.biosimilaireOf}'
            : 'Médicament biosimilaire',
        url:
            'https://www.ameli.fr/charente-maritime/pharmacien/exercice-professionnel/delivrance-produits-sante/regles-delivrance-prise-charge/medicaments-biosimilaires/regles-dispensation-et-substitution',
      ),
    );
  }

  // 🟦 Médicament d’exception
if (item.isException == true) {
  spans.add(
    clickableMarkerSpan(
      emoji: '🟦',
      tooltip: 'Médicament d’exception',
      url:
          'https://www.meddispar.fr/Medicaments-d-exception/Criteres#nav-buttons',
    ),
  );
}


  // 🟩 OTC
  if (raw.contains('(otc)') || raw.contains('(otc-libre-acces)')) {
    spans.add(
      clickableMarkerSpan(
        emoji: '🟩',
        tooltip: 'OTC / Libre accès',
        url:
            'https://ansm.sante.fr/uploads/2025/12/22/20251222-liste-medication-officinale-listecomplete-decembre-2025.xls',
      ),
    );
  }


  // espace après les pictos
  spans.add(const WidgetSpan(child: SizedBox(width: 6)));

  return spans;
}



// ============================================================================
// 🧩 PICTOGRAMMES & SOURCES
// ============================================================================
// Centralise l’affichage des icônes par type de source
// (BDM, DM, VETO, CATALOGUE, CERP…)
// ============================================================================


InlineSpan sourceIconSpan(SearchResult item) {
  // ==========================================================
  // 🏭 LOGO LABO — CATALOGUE
  // ==========================================================
  if (item.source == SourceType.catalogue &&
      item.iconUrl != null &&
      item.iconUrl!.isNotEmpty) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Image.network(
          item.iconUrl!,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.factory, size: 20, color: Colors.grey),
        ),
      ),
    );
  }



  // ==========================================================
  // 🔗 KEYWORD (PDF / lien externe)
  // ==========================================================
  if (item.source == SourceType.keyword) {
    return item.isPdf ? pdfIconSpan() : externalLinkIconSpan();
  }

  // ==========================================================
  // 🟢 CERP / SERP — LOGO SVG
  // ==========================================================
  if (item.source == SourceType.cerp) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: SvgPicture.asset(
          'assets/icons/cerp.svg',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          // optionnel si SVG monochrome
          // colorFilter: const ColorFilter.mode(
          //   Color(0xFF5A9094),
          //   BlendMode.srcIn,
          // ),
        ),
      ),
    );
  }

  // ==========================================================
  // 💊 AUTRES SOURCES — EMOJIS
  // ==========================================================
  String emoji;
  switch (item.source) {
    case SourceType.bdm:
      emoji = '💊';
      break;
    case SourceType.dm:
      emoji = '🩹';
      break;
    case SourceType.veto:
      emoji = '🐾';
      break;
    case SourceType.lpp:
      emoji = '📘';
      break;
    case SourceType.amc:
      emoji = '🏥';
      break;
    case SourceType.catalogue:
      emoji = '📁';
      break;
    default:
      emoji = '';
  }

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Text(
      emoji,
      style: const TextStyle(fontSize: 20),
    ),
  );
}











  // ==========================================================================
  // STATUTS bottom sheet
  // ==========================================================================
  Future<void> _ouvrirStatuts(String cip13, String label) async {
    List<String> statuts;

    if (_statutCache.containsKey(cip13)) {
      statuts = _statutCache[cip13]!;
    } else {
      statuts = await fetchStatuts(cip13);
      _statutCache[cip13] = statuts;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return _StatutsCipPanel(
              label: label,
              statuts: statuts,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 🔑 WIDGETS CLÉS (hors State)
// ============================================================================

class _ExpandedKey extends StatelessWidget {
  const _ExpandedKey({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_OffiboxWindowState>()!;
    return state._expandedContent();
  }
}

class _CollapsedKey extends StatelessWidget {
  const _CollapsedKey({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_OffiboxWindowState>()!;
    return state._collapsedContent();
  }
}

// ============================================================================
// STATUTS PANEL
// ============================================================================

class _StatutsCipPanel extends StatelessWidget {
  final String label;
  final List<String> statuts;
  final ScrollController scrollController;

  const _StatutsCipPanel({
    super.key,
    required this.label,
    required this.statuts,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            controller: scrollController,
            itemCount: statuts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: Colors.black87),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statuts[index],
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// 🧩 WIDGETS HOME (À COLLER ICI)
// ======================================================================

class OffiboxLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo_offibox.png',
      height: 72,
      fit: BoxFit.contain,
    );
  }
}

class OffiboxLogoText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo_offibox_text.png',
      height: 32,
      fit: BoxFit.contain,
    );
  }
}
class SearchHelpButtons extends StatelessWidget {
  const SearchHelpButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: const [
        _HelpChip(label: 'Par nom'),
        _HelpChip(label: 'Par CIP'),
        _HelpChip(label: 'Par laboratoire'),
        _HelpChip(label: 'Par indication'),
      ],
    );
  }
}

class _HelpChip extends StatelessWidget {
  final String label;

  const _HelpChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 13),
      ),
      backgroundColor: const Color(0xFFE8F3F4),
      side: const BorderSide(color: Color(0xFF5A9094)),
    );
  }
}



// ============================================================================
// BUTTONS / SPANS (helpers)
// ============================================================================

WidgetSpan _badgeSpan(String text) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2F3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF5A9094)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: Color(0xFF5A9094),
          ),
        ),
      ),
    ),
  );
}

WidgetSpan? genericBadgeSpan(SearchResult item) {
  if (item.isGeneric == true &&
      item.princepsName != null &&
      item.princepsName!.isNotEmpty) {
    return _badgeSpan(
      'PRINCEPS : ${item.princepsName!.toUpperCase()}',
    );
  }
  return null;
}


WidgetSpan? princepsBadgeSpan(SearchResult item) {
  if (item.isGeneric != true &&
      item.genericName != null &&
      item.genericName!.isNotEmpty) {
    return _badgeSpan(
      'GÉNÉRIQUE : ${item.genericName!.toUpperCase()}',
    );
  }
  return null;
}



WidgetSpan pdfIconSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SvgPicture.asset(
        'assets/icons/pdf_red.svg',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      ),
    ),
  );
}

WidgetSpan externalLinkIconSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SvgPicture.asset(
        'assets/icons/link-external.svg',
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Color(0xFF5A9094), BlendMode.srcIn),
      ),
    ),
  );
}

WidgetSpan rcpSpan({required VoidCallback onTap}) {
  return pillSpan(
    label: 'RCP',
    icon: Icons.description_outlined,
    tooltip: 'accès aux RCP',
    onTap: onTap,
  );
}

WidgetSpan rcpVetoSpan({required VoidCallback onTap}) {
  return pillSpan(
    label: 'RCP VÉTO',
    icon: Icons.description_outlined,
    tooltip: 'Accès au RCP vétérinaire',
    onTap: onTap,
  );
}


WidgetSpan medisparSpan({required VoidCallback onTap}) {
  return pillSpan(
    label: 'MEDDISPAR',
    icon: Icons.warning_amber_rounded,
    tooltip: 'ouvrir la page Meddispar',
    onTap: onTap,
  );
}

WidgetSpan resopharmaSpan({required VoidCallback onTap}) {
  return pillSpan(
    label: "PLUS D’INFOS",
    icon: Icons.open_in_new,
    tooltip: 'accès Resopharma',
    onTap: onTap,
  );
}

WidgetSpan plusInfosSpan({required VoidCallback onTap}) {
  return pillSpan(
    label: "PLUS D’INFOS",
    icon: Icons.open_in_new,
    tooltip: 'Ouvrir la fiche produit',
    onTap: onTap,
  );
}

WidgetSpan ansmStatutSpan({
  required String statut,
  required String date,
  required String url,
}) {
  // Cette fonction est appelée depuis le State ; on garde le widget neutre ici.
  // Si tu veux, je te la remets côté State avec accès ansmColor/formatAnsmDate.
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: const SizedBox.shrink(),
  );
}

WidgetSpan pillSpan({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
  required String tooltip,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: HoverPillButton(
        label: label,
        icon: icon,
        tooltip: tooltip,
        onTap: onTap,
      ),
    ),
  );
}

WidgetSpan copyPillSpan({
  required BuildContext context,
  required String value,
  required String tooltip,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: HoverPillButton(
        label: 'COPIER',
        icon: Icons.copy,
        tooltip: tooltip,
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          final state = context.findAncestorStateOfType<_OffiboxWindowState>();
          state?._showCopyToast();
        },
      ),
    ),
  );
}

Widget _badgeContainer({required String text}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F2F3),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: const Color(0xFF5A9094),
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: Color(0xFF5A9094),
      ),
    ),
  );
}



WidgetSpan clickableMarkerSpan({
  required String emoji,
  required String tooltip,
  required String url,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    ),
  );
}

WidgetSpan markerSpan({
  required String emoji,
  required String tooltip,
  required Color color,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Tooltip(
      message: tooltip,
      child: Text(
        emoji,
        style: TextStyle(fontSize: 16, color: color),
      ),
    ),
  );
}

InlineSpan bioreferentBadgeSpan() {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(
            'https://www.ameli.fr/charente-maritime/pharmacien/exercice-professionnel/delivrance-produits-sante/regles-delivrance-prise-charge/medicaments-biosimilaires/regles-dispensation-et-substitution',
          ),
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF7C3AED)),
          ),
          child: const Text(
            'BIORÉFÉRENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Color(0xFF7C3AED),
            ),
          ),
        ),
      ),
    ),
  );
}





// ============================================================================
// 🎛️ BOUTON PILULE INTERACTIF
// ============================================================================
// Bouton cliquable avec hover desktop
// Utilisé pour : PDF, rechercher, copier, plus d’infos
// ============================================================================

class HoverPillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const HoverPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<HoverPillButton> createState() => _HoverPillButtonState();
}

class _HoverPillButtonState extends State<HoverPillButton> {
  static const Color offiboxTeal = Color(0xFF5A9094);
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: hovered ? offiboxTeal : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: offiboxTeal),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(hovered ? 0.28 : 0.14),
                  blurRadius: hovered ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: hovered ? Colors.white : offiboxTeal,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hovered ? Colors.white : offiboxTeal,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
