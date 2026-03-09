import 'dart:async';
import 'package:offibox/services/device_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:offibox/window/copy_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:offibox/utils/device_id.dart';

import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/controllers/offibox_controller.dart';
import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/utils/ansm_rappel_match.dart';
import 'package:offibox/ui/results/results_panel.dart';
import 'package:offibox/ui/widgets/fake_results.dart';
import 'package:offibox/window/offibox_window_shortcuts.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/window/widgets/offibox_top_bar.dart';
import 'package:offibox/ui/widgets/offibox_info_bar.dart';
import 'package:offibox/ui/widgets/calendar_reminder_bubble.dart';
import 'package:offibox/services/admin_service.dart';
import 'package:offibox/services/google_calendar_service.dart';
import 'package:offibox/services/google_calendar_desktop_auth.dart';
import 'package:offibox/config/google_oauth_config.dart';
import 'package:offibox/config/app_config.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/window/widgets/about_dialog.dart';
import 'package:offibox/window/widgets/account_dialog.dart';
import 'package:offibox/window/widgets/ideas_box_panel.dart';
import 'package:offibox/ui/widgets/xls_panel_below_bar.dart';
import 'package:offibox/ui/widgets/word_panel_below_bar.dart';
import 'package:offibox/ui/widgets/news_popup_card.dart';
import 'package:offibox/ui/widgets/pdf_panel_below_bar.dart';
import 'package:offibox/ui/widgets/web_panel_below_bar.dart';
import 'package:offibox/ui/widgets/image_panel_below_bar.dart';
import 'package:offibox/ui/widgets/margin_calculator_panel.dart';
import 'package:offibox/services/news_popup_service.dart';
import 'dart:io' show exit, Platform, Process;
import 'package:offibox/constants/catalogue_cart_config.dart';

import 'package:offibox/data/espace_pro_credentials.dart';
import 'package:offibox/ui/dialogs/espace_pro_login_dialog.dart';
import 'package:offibox/ui/dialogs/contact_dialog.dart';
import 'package:offibox/ui/dialogs/version_history_dialog.dart';
import 'package:offibox/ui/screens/espace_pro_webview_screen.dart';
import 'package:offibox/services/pdf_preloader.dart';
import 'package:offibox/services/journees_mondiales.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/services/ansm_statuts_csv_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OffiboxWindow extends ConsumerStatefulWidget {
  const OffiboxWindow({super.key});

  @override
  ConsumerState<OffiboxWindow> createState() => _OffiboxWindowState();
}


class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// Libellé court pour la barre d'infos : "Dernier rappel de produit (DD/MM/YYYY) : [produit – labo]".
String _lastRappelLabel(String fullLabel, String? dateStr) {
  final datePart = (dateStr != null && dateStr.trim().isNotEmpty) ? ' (${dateStr.trim()})' : '';
  final prefix = 'Dernier rappel de produit$datePart : ';
  final idx = fullLabel.indexOf(' : ');
  final libelle = idx >= 0 ? fullLabel.substring(idx + 3).trim() : fullLabel;
  const maxLen = 55;
  final short = libelle.length > maxLen ? '${libelle.substring(0, maxLen - 1)}…' : libelle;
  return '$prefix$short';
}

class _OffiboxWindowState extends ConsumerState<OffiboxWindow>
    with WidgetsBindingObserver {
  bool expanded = false;

  /// Convenience accessor used by the results panel layout.
  /// Using a getter avoids scope issues if the local variable is moved/refactored.
  List<SearchResult> get effectiveResults => ref.watch(effectiveResultsProvider);

  String? _lastAutoOpenedCerpEquipQuery;

  static bool _isCerpEquipmentQuery(String q) {
    final s = q
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.isEmpty) return false;
    return s.contains('catalogue equipement') ||
        s.contains('catalogue équipement') ||
        s.contains('fournitures');
  }
  bool _isGoogleConnected = false;
  bool _showIdeasPanel = false;
  /// Barre d’infos déroulante en haut : true = déployée, false = repliée
  bool _infoBarExpanded = true;
  /// Panneau catalogue sous la barre (affiché uniquement après clic sur le badge Catalogue).
  bool _showCataloguePanel = false;
  /// Panneau vidéo YouTube sous la barre (affiché au clic sur pill YouTube).
  bool _showYouTubePanel = false;
  String? _youtubeVideoUrl;
  bool _showTherapeuticVideoPanel = false;
  String? _therapeuticVideoUrl;
  /// Panneau Flash info Pharmaradio sous la barre (affiché au clic sur Pharmaradio).
  bool _showPharmaradioFlashPanel = false;
  /// PDF ouvert sous la barre (clic « Télécharger PDF » / « Rechercher sur le catalogue » ou lien PDF).
  String? _pdfPanelUrl;
  // Réservés pour usage futur (ex. titre panneau PDF, recherche initiale).
  // ignore: unused_field
  String? _pdfPanelLab;
  // ignore: unused_field
  String? _pdfPanelInitialQuery;
  // ignore: unused_field
  bool _pdfPanelAutoSearch = false;
  /// Masquer le viewer PDF issu du résultat catalogue (isPdfHitResult) quand l'utilisateur ferme le panneau.
  bool _hidePdfHitPanel = false;
  /// XLS/XLSX ouvert sous la barre (format 16:9).
  String? _xlsPanelUrl;
  /// Word (DOC/DOCX) ouvert sous la barre (format 16:9).
  String? _wordPanelUrl;
  /// URL d’une page web ouverte sous la barre (même zone que PDF/Word/XLS).
  String? _webPanelUrl;
  /// Chemin asset d'une image ouverte sous la barre (ex. assets/images/xxx.png).
  String? _imagePanelAssetPath;
  /// Calculatrice de marge (mot-clé « calculatrice de marge ») ouverte sous la barre.
  bool _showMarginCalculatorPanel = false;
  String _appVersion = '1.0.0';
  /// Actualités (news.csv) : popup sous la barre, 48 h, 2×/jour (matin + après 14h).
  NewsEntry? _newsPopupEntry;
  bool _showNewsPopup = false;
  bool _newsPopupCheckDone = false;
  bool _newsPopupCheckInProgress = false;

  Future<void> _maybeShowNewsPopup() async {
    if (_newsPopupCheckDone || _newsPopupCheckInProgress) return;
    _newsPopupCheckInProgress = true;
    final entry = await fetchLatestNews();
    final show = entry != null && await shouldShowNews(entry);
    if (!mounted) {
      _newsPopupCheckInProgress = false;
      return;
    }
    if (show) {
      await markNewsShown();
      setState(() {
        _newsPopupEntry = entry;
        _showNewsPopup = true;
      });
    }
    setState(() {
      _newsPopupCheckDone = true;
      _newsPopupCheckInProgress = false;
    });
  }

  final GlobalKey<HamburgerMenuState> _menuPopupKey =
      GlobalKey<HamburgerMenuState>();

  Timer? _debounce;
  Timer? _ansmRefreshTimer;
  bool _filterHovered = false;

  /// Clé unique pour le placeholder "skeleton" (évite doublon dans l’AnimatedSwitcher lors des rebuilds).
  Key? _skeletonKey;
  bool _wasSkeleton = false;

  bool get _hasQuery => _searchController.text.trim().length >= 2;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _windowFocus = FocusNode(debugLabel: 'window');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  final ScrollController _resultsScroll = ScrollController();

Future<void> _registerDeviceIfNeeded() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Admins (ex. offibox@offibox.fr) : pas de limite 5 appareils
  if (AdminService.isDeviceLimitExempt(user.email)) return;

  try {
    final deviceId = await getDeviceId();

    await DeviceService.secureRegisterDevice(
      deviceId: deviceId,
      deviceName: 'PC principal',
      appVersion: _appVersion,
    );

  } catch (e) {

    debugPrint('❌ Device limit reached: $e');

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Limite atteinte'),
        content: const Text(
          'Vous avez atteint la limite de 5 appareils pour cette licence.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}



  void _onLinkOpened() {
    // Ne pas refermer la barre : laisser les résultats visibles après ouverture d’un lien.
    if (!mounted) return;
    _searchFocus.unfocus();
  }

  /// Efface tout le contenu affiché sous la barre (PDF, page web, XLS, Word, vidéos). N'appelle pas setState.
  void _clearBelowBarPanels() {
    _pdfPanelUrl = null;
    _pdfPanelLab = null;
    _pdfPanelInitialQuery = null;
    _pdfPanelAutoSearch = false;
    _webPanelUrl = null;
    _xlsPanelUrl = null;
    _wordPanelUrl = null;
    _imagePanelAssetPath = null;
    _showMarginCalculatorPanel = false;
    _showYouTubePanel = false;
    _youtubeVideoUrl = null;
    _showTherapeuticVideoPanel = false;
    _therapeuticVideoUrl = null;
    _showPharmaradioFlashPanel = false;
    _hidePdfHitPanel = true;
  }

  /// Ouvre une image asset (assets/images/...) dans le panneau sous la barre.
  void _openAssetImageInBelowBar(String assetPath) {
    final path = assetPath.trim().replaceAll(r'\', '/');
    if (path.isEmpty || !path.toLowerCase().startsWith('assets/')) return;
    setState(() {
      _clearBelowBarPanels();
      expanded = true;
      _imagePanelAssetPath = path;
    });
  }

  void _openHttpUrlInBelowBar(String url) {
    final u = url.trim();
    if (u.isEmpty) return;
    final lower = u.toLowerCase();

    if (lower.endsWith('.pdf')) {
      setState(() {
        _clearBelowBarPanels();
        expanded = true;
        _pdfPanelUrl = u;
        _pdfPanelLab = 'Document';
        _pdfPanelInitialQuery = null;
        _pdfPanelAutoSearch = false;
        _hidePdfHitPanel = true;
      });
      return;
    }

    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.ods')) {
      setState(() {
        _clearBelowBarPanels();
        expanded = true;
        _xlsPanelUrl = u;
      });
      return;
    }

    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.odt')) {
      setState(() {
        _clearBelowBarPanels();
        expanded = true;
        _wordPanelUrl = u;
      });
      return;
    }

    if (u.startsWith('http://') || u.startsWith('https://')) {
      setState(() {
        _clearBelowBarPanels();
        expanded = true;
        _webPanelUrl = u;
      });
      return;
    }
  }

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  onBeforeOpenLink = _onLinkOpened;
  onOpenHttpUrlInApp = _openHttpUrlInBelowBar;
  onBeforeOpenExternalBrowser = () {
    windowManager.minimize();
  };

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    // Capturer les providers AVANT tout await (ref invalide après dispose)
    final controller = ref.read(offiboxControllerProvider);
    final filterNotifier = ref.read(searchFilterProvider.notifier);
    final searchFilter = ref.read(searchFilterProvider);
    _windowFocus.requestFocus();

    // Rafraîchir rappel + statuts ANSM 3 fois par jour (7h, 13h, 18h heure locale)
    void scheduleNextAnsmRefresh() {
      _ansmRefreshTimer?.cancel();
      final now = DateTime.now();
      final slots = [7, 13, 18]; // heures cibles
      DateTime? next;
      for (final h in slots) {
        var t = DateTime(now.year, now.month, now.day, h);
        if (t.isAfter(now)) { next = t; break; }
      }
      next ??= DateTime(now.year, now.month, now.day + 1, 7);
      final delay = next.difference(now);
      _ansmRefreshTimer = Timer(delay, () {
        if (!mounted) return;
        ref.invalidate(ansmLastRappelProvider);
        ref.invalidate(ansmMedicamentRappelsProvider);
        ref.invalidate(ansmLastStatutProvider);
        // Vérifier statuts ANSM et rappels de lot au moins une fois par jour
        final controller = ref.read(offiboxControllerProvider);
        controller.refreshAnsmStatutsIfNeeded();
        controller.refreshAnsmRappelsIfNeeded();
        scheduleNextAnsmRefresh();
      });
    }
    scheduleNextAnsmRefresh();

    Future(() async {
      await controller.init();
      if (!mounted) return;

      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);

      // Rebrancher les médicaments (BDM) au démarrage pour avoir des résultats
      filterNotifier.enableSource(SourceType.bdm);
      final q = _searchController.text.trim();
      if (q.length >= 2) controller.filter(q, searchFilter: searchFilter);

      // Connexion Google (agenda) pour afficher "Google Agenda" dans le menu
      final connected = await GoogleCalendarService.hasGoogleCalendarAccess();
      if (mounted) setState(() => _isGoogleConnected = connected);

      // 🔐 Vérification appareil (5 PC max)
      await _registerDeviceIfNeeded();
    });
  });
}


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(offiboxControllerProvider);
      controller.refreshAnsmStatutsIfNeeded();
      controller.refreshAnsmRappelsIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    onBeforeOpenLink = null;
    onOpenHttpUrlInApp = null;
    onBeforeOpenExternalBrowser = null;
    _debounce?.cancel();
    _ansmRefreshTimer?.cancel();
    _windowFocus.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  /// True si la recherche est stabilisée (Enter ou fin de saisie) et a renvoyé 0 résultat.
  bool _searchSettledEmpty(OffiboxController controller) {
    final q = controller.currentQuery;
    if (q.isEmpty || q.length < 2) return false;
    return _searchController.text.trim() == q && controller.filteredResults.isEmpty;
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    _debounce?.cancel();

    // Fermer la fenêtre précédente (web, PDF, doc, etc.) dès qu'on tape un nouveau mot-clé
    setState(() => _clearBelowBarPanels());

    final controller = ref.read(offiboxControllerProvider);
    controller.cancelSearch();

    if (q.length < 2) {
      controller.clearResults();
      setState(() {});
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 280), () {
      controller.filter(q, searchFilter: ref.read(searchFilterProvider));

      // Auto-ouverture du catalogue équipement (CERP) sous la barre — uniquement si CERP activé.
      if (AppConfig.cerpFeaturesEnabled) {
        final pdfUrl = CatalogueCartConfig.cerpEquipmentPdfUrl.trim();
        if (pdfUrl.isNotEmpty && _isCerpEquipmentQuery(q) && _lastAutoOpenedCerpEquipQuery != q) {
          _lastAutoOpenedCerpEquipQuery = q;
          setState(() {
            expanded = true;
            _pdfPanelUrl = pdfUrl;
            _pdfPanelLab = 'Catalogue équipement (CERP)';
            _pdfPanelInitialQuery = null;
            _pdfPanelAutoSearch = false;
            // fermer les autres panneaux potentiellement ouverts
            _webPanelUrl = null;
            _xlsPanelUrl = null;
            _wordPanelUrl = null;
          });
        }
      }
    });
  }

  void _open() {
    setState(() {
      expanded = true;
      _searchController.clear();
    });
    _maybeShowNewsPopup();

    _windowFocus.requestFocus();
    _searchFocus.requestFocus();
    ref.read(offiboxControllerProvider).clearResults();
  }

  void _close() {
    setState(() {
      expanded = false;
      _showNewsPopup = false;
      _newsPopupEntry = null;
      _newsPopupCheckDone = false;
    });

    _searchFocus.unfocus();
    _windowFocus.requestFocus();
    ref.read(offiboxControllerProvider).clearResults();
  }

  void _showQuitConfirmationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierLabel: 'Fermer la boîte de dialogue',
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius)),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 125),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Spinnaker',
                color: OffiboxColors.darkGray,
                height: 1.25,
              ),
              children: [
                const TextSpan(text: 'Fermer '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Image.asset(
                        'assets/icons/logo_offibox_installer.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          AppConfig.appName,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Spinnaker',
                            color: OffiboxColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' ?'),
              ],
            ),
          ),
        ),
        actions: [
          IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuitDialogPill(
                  label: 'Non',
                  atRestTeal: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await windowManager.show();
                    await windowManager.focus();
                  },
                ),
                const SizedBox(width: 12),
                _QuitDialogPill(
                  label: 'Oui',
                  atRestTeal: false,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (Platform.isWindows) {
                      exit(0);
                    } else {
                      SystemNavigator.pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCopyChoiceMenu(BuildContext context, dynamic result) {
    final options = getCopyOptions(result);
    if (options.isEmpty) return;
    if (options.length == 1) {
      copyToClipboard(options.first.value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copié'),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final size = MediaQuery.sizeOf(context);
    const topY = OffiboxWindowUI.topMargin +
        OffiboxWindowUI.barHeight +
        OffiboxWindowUI.gapBelowBar;
    final barW = _barWidth(context);
    final left = size.width - OffiboxWindowUI.rightMargin - barW + 12;
    const top = topY + 4;
    final position = RelativeRect.fromLTRB(
      left,
      top,
      size.width - left - 1,
      size.height - top - 1,
    );
    showMenu<CopyOption?>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius)),
      color: Colors.white,
      elevation: 8,
      items: [
        const PopupMenuItem<CopyOption?>(
          enabled: false,
          value: null,
          child: Text(
            'Que voulez-vous copier ?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Spinnaker',
              fontSize: 13,
            ),
          ),
        ),
        ...options.map(
          (o) => PopupMenuItem<CopyOption?>(
            value: o,
            child: Text('${o.label} : ${o.value}'),
          ),
        ),
      ],
    ).then((selected) {
      if (selected != null && mounted) {
        copyToClipboard(selected.value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copié'),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

KeyEventResult _handleKey(
  FocusNode node,
  KeyEvent event,
) {
  OffiboxWindowShortcuts.handle(
    event: event,
    expanded: expanded,
    open: _open,
    close: _close,
    reset: () {
      _searchController.clear();
      ref.read(offiboxControllerProvider).clearResults();
      _searchFocus.requestFocus();
    },
    quit: () => SystemNavigator.pop(),
    selectedResult: ref.read(offiboxControllerProvider).selectedResult,
    onCopyWithOptions: (result) => _showCopyChoiceMenu(context, result),
    onCopySuccess: () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copié'),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    },
  );
 
  return KeyEventResult.ignored;
}
//ok
  double _barWidth(BuildContext context) {
    if (!expanded) {
      return OffiboxWindowUI.collapsedWidth;
    }
    // Largeur initiale de la barre déployée : 80 % de la largeur de l'écran.
    return MediaQuery.of(context).size.width * 0.8;
  }

  /// Hauteur de la barre déployée selon le nombre de lignes du résultat (médicaments : 2, 3 ou 4 ; annuaire RPPS : 4 pour voir la source).
  double? _effectiveExpandedBarHeight(SearchResult? item) {
    if (item == null) return null;
    final singleLine = item.source == SourceType.keyword ||
        item.source == SourceType.siteWeb ||
        item.source == SourceType.catalogue ||
        item.source == SourceType.dm;
    if (singleLine) return OffiboxWindowUI.barHeightExpandedSingleLine;
    if (item.source == SourceType.annuaireSanteRpps) return OffiboxWindowUI.barHeightExpandedFourLines;
    final hasLine3 = (item.url != null && item.url!.trim().isNotEmpty) ||
        (item.meddisparUrl != null && item.meddisparUrl!.trim().isNotEmpty);
    final hasBiosimRelation = item.biosimilaireOf != null && item.biosimilaireOf!.trim().isNotEmpty;
    final hasGenericRelation = item.isGeneric == true ||
        (item.princepsName != null && item.princepsName!.trim().isNotEmpty) ||
        (item.genericName != null && item.genericName!.trim().isNotEmpty) ||
        item.isBioreferent == true;
    final showBiosimLine = item.source == SourceType.bdm && (hasBiosimRelation || hasGenericRelation);
    final lineCount = 2 + (hasLine3 ? 1 : 0) + (showBiosimLine ? 1 : 0);
    switch (lineCount) {
      case 2: return OffiboxWindowUI.barHeightExpanded;
      case 3: return OffiboxWindowUI.barHeightExpandedThreeLines;
      case 4: return OffiboxWindowUI.barHeightExpandedFourLines;
      default: return OffiboxWindowUI.barHeightExpanded;
    }
  }

@override
Widget build(BuildContext context) {
  // Ne rebuilder que quand la sélection ou l’état searching change (pas à chaque frappe) pour limiter le lag.
  final selectedResult = ref.watch(offiboxControllerProvider.select((c) => c.selectedResult));
  final searching = ref.watch(offiboxControllerProvider.select((c) => c.searching));
  final controller = ref.read(offiboxControllerProvider);
  ref.listen<OffiboxController>(offiboxControllerProvider, (prev, next) {
    if (prev?.selectedResult != next.selectedResult && mounted) {
      setState(() {
        _showCataloguePanel = false;
        _showYouTubePanel = false;
        _youtubeVideoUrl = null;
        _showTherapeuticVideoPanel = false;
        _therapeuticVideoUrl = null;
        _hidePdfHitPanel = false;
      });
      // Outils métier / Sites web : une seule URL sur la ligne → ouvrir dans la fenêtre sous la barre
      final r = next.selectedResult;
      if (r != null &&
          (r.source == SourceType.keyword || r.source == SourceType.siteWeb) &&
          (r.url?.trim().isNotEmpty ?? false)) {
        final hasOtherBadges =
            (r.badge2Url?.trim().isNotEmpty ?? false) ||
            (r.badge3Url?.trim().isNotEmpty ?? false);
        if (!hasOtherBadges && mounted) {
          setState(() {
            expanded = true;
            _webPanelUrl = r.url!.trim();
            _pdfPanelUrl = null;
            _xlsPanelUrl = null;
            _wordPanelUrl = null;
          });
        }
      }
    }
  });
  ref.listen(cataloguePdfItemsProvider, (prev, next) {
    if (next.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PdfPreloader.preloadCatalogues(next);
      });
    }
  });
  ref.listen(authStateProvider, (prev, next) {
    if (prev?.valueOrNull != next.valueOrNull && next.valueOrNull != null && mounted) {
      GoogleCalendarService.hasGoogleCalendarAccess().then((connected) {
        if (mounted) setState(() => _isGoogleConnected = connected);
      });
    }
  });
  final dgsUrgent = ref.watch(dgsUrgentProvider).valueOrNull;
  final ansmRappel = ref.watch(ansmLastRappelProvider).valueOrNull;
  final ansmStatut = ref.watch(ansmLastStatutProvider).valueOrNull;
  final todayCalendarEvents = ref.watch(todayCalendarEventsProvider).valueOrNull ?? [];
  final authUser = ref.watch(authStateProvider).valueOrNull;
  /// Sur desktop (OAuth configuré), tout le monde peut cliquer « Connecter l'agenda » même si refus à l'installation.
  final canConnectGoogleAgenda = GoogleCalendarDesktopAuth.isNeeded ||
      (authUser?.email?.toLowerCase().endsWith('@gmail.com') ?? false);
  final nextJournee = JourneesMondiales.getNext(DateTime.now());
  final dgsLabel = dgsUrgent != null
      ? 'dernier ${dgsUrgent.title}${dgsUrgent.dateLabel.isNotEmpty ? ' (${dgsUrgent.dateLabel})' : ''}'
      : 'DGS-Urgent';
  final infoBarItems = <TickerItem>[
    (
      label: dgsLabel,
      url: dgsUrgent?.pdfUrl ?? dgsUrgent?.pageUrl ?? 'https://sante.gouv.fr/professionnels/article/dgs-urgent',
      tooltip: 'Cliquer pour plus d\'infos',
      icon: TickerItemIcon.danger,
      isAnsm: false,
      isDgs: true,
      colorOverride: null,
    ),
    // Dernier rappel de produit (toujours affiché ; lien vers rappel ou page ANSM)
    (
      label: ansmRappel != null
          ? _lastRappelLabel(ansmRappel.label, ansmRappel.dateStr)
          : 'Dernier rappel de produit',
      url: ansmRappel?.url ?? ansmInformationsMedicamentsUrl,
      tooltip: '+ d\'infos',
      icon: TickerItemIcon.none,
      isAnsm: true,
      isDgs: false,
      colorOverride: ansmRappel != null ? const Color(0xFFC62828) : const Color(0xFF42A5F5), // rouge si rappel, sinon bleu
    ),
    // Dernière alerte ANSM (statuts médicaments : rupture, tension, etc.)
    (
      label: ansmStatut != null
          ? 'Dernière alerte ANSM : ${ansmStatut.label}'
          : 'Dernière alerte ANSM',
      url: ansmStatut?.url ?? 'https://ansm.sante.fr/',
      tooltip: ansmStatut?.label ?? 'Voir les alertes ANSM',
      icon: TickerItemIcon.none,
      isAnsm: true,
      isDgs: false,
      colorOverride: ansmStatut != null ? colorForStatutLevel(ansmStatut.statusLevel) : const Color(0xFF42A5F5), // bleu clair
    ),
    // Journées mondiales (santé / WHO) en mauve dans la barre déroulante ; sinon fallback Actualités en gris
    if (nextJournee != null)
      (
        label: nextJournee.label,
        url: 'https://www.who.int/fr/campaigns',
        tooltip: 'Cliquer pour plus d\'infos',
        icon: TickerItemIcon.none,
        isAnsm: false,
        isDgs: false,
        colorOverride: const Color(0xFF8E44AD), // mauve (règles journées mondiales)
      )
    else
      (
        label: 'Actualités',
        url: 'https://www.who.int/fr/campaigns',
        tooltip: 'Cliquer pour plus d\'infos',
        icon: TickerItemIcon.none,
        isAnsm: false,
        isDgs: false,
        colorOverride: const Color(0xFF37474F), // gris anthracite
      ),
    // RDV du jour (agenda Google connecté) : un seul badge "x rendez vous aujourd'hui", clic → fenêtre avec la liste
    if (_isGoogleConnected && todayCalendarEvents.isNotEmpty)
      (
        label: todayCalendarEvents.length == 1
            ? '1 rendez vous aujourd\'hui'
            : '${todayCalendarEvents.length} rendez vous aujourd\'hui',
        url: 'offibox://agenda-today',
        tooltip: 'Cliquer pour voir les rendez-vous du jour',
        icon: TickerItemIcon.none,
        isAnsm: false,
        isDgs: false,
        colorOverride: const Color(0xFF546E7A), // gris bleuté
      ),
  ];

  final screenH = MediaQuery.of(context).size.height;
  final effectiveResults = ref.watch(effectiveResultsProvider);
  // Sous la barre de recherche : inclure la barre d'infos (ticker) si déployée pour éviter le chevauchement
  final topY = OffiboxWindowUI.topMargin +
      (_infoBarExpanded
          ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap
          : 0) +
      OffiboxWindowUI.barHeight +
      OffiboxWindowUI.gapBelowBar;
  final maxPanelH = screenH - topY - 20;
  final isSkeleton = effectiveResults.isEmpty && !_searchSettledEmpty(controller);
  if (isSkeleton && !_wasSkeleton) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _skeletonKey = UniqueKey(); _wasSkeleton = true; });
    });
  } else if (!isSkeleton && _wasSkeleton) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _wasSkeleton = false; _skeletonKey = null; });
    });
  }
  final medicamentRappels = ref.watch(ansmMedicamentRappelsProvider).valueOrNull ?? [];
  final rappelForLine3Badge = selectedResult != null && selectedResult.source == SourceType.bdm
      ? findMatchingRappel(selectedResult, medicamentRappels)
      : null;
  final effectiveExpandedBarHeight = _effectiveExpandedBarHeight(selectedResult);
  final expandedBarH = effectiveExpandedBarHeight ?? OffiboxWindowUI.barHeightExpanded;
  /// PDF/Word/XLS/Web : sous la barre de résultats, sans empiéter (hauteur réelle barre + écart).
  final topYBelowExpandedBarXls = OffiboxWindowUI.topMargin +
      (_infoBarExpanded
          ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap
          : 0) +
      expandedBarH +
      OffiboxWindowUI.gapBelowBar;
  final isPdfHitResult = selectedResult != null &&
      selectedResult.source == SourceType.catalogue &&
      selectedResult.catalogueUrl != null &&
      selectedResult.label.contains(' - trouvé dans le catalogue ');
  final shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyQ, control: true): const QuitIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX, control: true): const QuitIntent(),
    if (selectedResult != null)
      const SingleActivator(LogicalKeyboardKey.keyC, control: true):
          const CopyResultIntent(),
  };

  return Scaffold(
    backgroundColor: const Color(0xFF1A1A1A),
    body: Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) {
              if (expanded) {
                _close();
              } else {
                _showQuitConfirmationDialog(context);
              }
              return null;
            },
          ),
          QuitIntent: CallbackAction<QuitIntent>(
            onInvoke: (_) {
              _showQuitConfirmationDialog(context);
              return null;
            },
          ),
          CopyResultIntent: CallbackAction<CopyResultIntent>(
            onInvoke: (_) {
              if (selectedResult == null) return null;
              final options = getCopyOptions(selectedResult);
              if (options.isEmpty) return null;
              if (options.length == 1) {
                copyToClipboard(options.first.value);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copié'),
                      duration: Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                _showCopyChoiceMenu(context, selectedResult);
              }
              return null;
            },
          ),
        },
        child: KeyboardListener(
          focusNode: _windowFocus,
          autofocus: true,
          onKeyEvent: (event) {
            _handleKey(_windowFocus, event);
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF1A1A1A),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
              child: Stack(
        children: [
          // Clic à l'extérieur de la barre et des résultats → effacer la recherche et faire disparaître les résultats
          if (expanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_hasQuery || ref.read(offiboxControllerProvider).selectedResult != null) {
                    _searchController.clear();
                    _searchFocus.unfocus();
                    ref.read(offiboxControllerProvider).clearSelection();
                    setState(() {});
                  }
                },
              ),
            ),
          // ───────────────────────────
          // BULLE RAPPEL RDV (30 min avant, au-dessus / à côté de la barre d'infos)
          // ───────────────────────────
          if (_isGoogleConnected && todayCalendarEvents.isNotEmpty)
            CalendarReminderBubble(
              events: todayCalendarEvents,
              topOffset: OffiboxWindowUI.topMargin + 4,
              leftOffset: 20,
              barWidth: _barWidth(context),
            ),
          // ───────────────────────────
          // TOP BAR
          // ───────────────────────────
          Positioned(
            top: OffiboxWindowUI.topMargin,
            right: OffiboxWindowUI.rightMargin,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = _barWidth(context);
                return DragToMoveArea(
                  child: SizedBox(
                    width: w,
                    child: OffiboxTopBar(
                    expanded: expanded,
                    searching: searching,
      infoBarExpanded: _infoBarExpanded,
      onToggleInfoBar: () => setState(() => _infoBarExpanded = !_infoBarExpanded),
      onInfoBarUrlTap: (url) {
            if (url == 'offibox://agenda-today') {
              final events = ref.read(todayCalendarEventsProvider).valueOrNull ?? [];
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Rendez-vous du jour'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: events
                          .map((ev) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${ev.timeLabel}  ${ev.summary}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),)
                          .toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
              return;
            }
            setState(() {
              expanded = true;
              _webPanelUrl = url;
              _pdfPanelUrl = null;
              _xlsPanelUrl = null;
              _wordPanelUrl = null;
            });
          },
      barWidth: _barWidth(context),
      barBottomY: OffiboxWindowUI.topMargin +
          (_infoBarExpanded ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap : 0) +
          (expanded ? (effectiveExpandedBarHeight ?? OffiboxWindowUI.barHeightExpanded) : OffiboxWindowUI.barHeight),
      barTopY: OffiboxWindowUI.topMargin,
      rightMargin: OffiboxWindowUI.rightMargin,
      searchController: _searchController,
      searchFocus: _searchFocus,
      onSearchChanged: _onSearchChanged,
      onSearchSubmit: (value) async {
        final q = value.trim();
        if (q.isEmpty) return;
        final qLower = q.toLowerCase();
        if (qLower == 'calculatrice' && Platform.isWindows) {
          Process.start('calc.exe', []);
          return;
        }
        if (qLower.startsWith('http://') || qLower.startsWith('https://')) {
          final uri = Uri.parse(q);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return;
        }
        if (q.length >= 2) {
          _debounce?.cancel();
          setState(() => _clearBelowBarPanels());
          ref.read(offiboxControllerProvider).filterImmediate(
                q,
                searchFilter: ref.read(searchFilterProvider),
              );
        }
      },
      onScanDataMatrix: (cip13, payload) {
        _searchController.clear();
        ref.read(offiboxControllerProvider).filterFromScan(
              cip13,
              searchFilter: ref.read(searchFilterProvider),
              payload: payload,
            );
      },
      onScanMutuelleQr: (codePrefectoral) {
        _searchController.clear();
        ref.read(offiboxControllerProvider).filterFromScan(
              codePrefectoral,
              searchFilter: ref.read(searchFilterProvider),
              restrictToSource: SourceType.amc,
            );
      },
      scanPayload: controller.lastScanPayload,
      recalledProductNames: controller.recalledProductNames,
      ansmLastRappel: ref.watch(ansmLastRappelProvider).valueOrNull,
      rappelForLine3Badge: rappelForLine3Badge,
      filterHovered: _filterHovered,
      onFilterHoverChange: (v) => setState(() => _filterHovered = v),
      onSearchWithQuery: (query) {
        // Clic sur le badge DCI (ex. zolpidem) : fermer modale éventuelle, effacer page/URL/PDF, afficher la liste des médicaments (génériques).
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        setState(() => _clearBelowBarPanels());
        ref.read(offiboxControllerProvider).clearSelection();
        _searchController.text = query;
        _searchFocus.requestFocus();
        ref.read(offiboxControllerProvider).filterImmediate(
              query,
              searchFilter: ref.read(searchFilterProvider),
            );
      },

      onTapInside: () {
        ref.read(offiboxControllerProvider).clearSelection();
        _searchFocus.requestFocus();
        // Quand on clique dans la barre (vide), faire disparaître les panneaux XLS, Word, PDF, vidéo, etc.
        if (_searchController.text.trim().isEmpty) {
          setState(() {
            _xlsPanelUrl = null;
            _wordPanelUrl = null;
            _webPanelUrl = null;
            _pdfPanelUrl = null;
            _pdfPanelLab = null;
            _pdfPanelInitialQuery = null;
            _pdfPanelAutoSearch = false;
            _hidePdfHitPanel = true;
            _youtubeVideoUrl = null;
            _showYouTubePanel = false;
            _showTherapeuticVideoPanel = false;
            _therapeuticVideoUrl = null;
            _showPharmaradioFlashPanel = false;
          });
        }
      },

      onToggleWindow: expanded ? _close : _open,
      onEscape: _close,
      onProposeQuit: () => _showQuitConfirmationDialog(context),

      // 🔍 résultat sélectionné
      selectedResult: controller.selectedResult,
      rppsStructureCountForSelected: controller.rppsStructureCountForSelected,
      statutsByCis: controller.statutsByCis,
      ansmStatutsByCis: controller.ansmStatutsByCis,
      generiques2026ByCis: controller.generiques2026ByCis,
      generiques2026PrincepsKeyToGenericName: controller.generiques2026PrincepsKeyToGenericName,
      generiques2026DciToGenericName: controller.generiques2026DciToGenericName,
      generiques2026CisSet: controller.generiques2026CisSet,
      cip13ToFic03Status: controller.cip13ToFic03Status,
      biosimilairesInfoByCip: controller.biosimilairesInfoByCip,
      compositionBdpmByCis: controller.compositionBdpmByCis,
      hospitalCip13Set: controller.hospitalCip13Set,
      cisArretCommercialisation: controller.cisArretCommercialisation,
      arretCommercialisationByCis: controller.arretCommercialisationByCis,
      tauxRemboursementByCis: controller.tauxRemboursementByCis,
      getVocUrlsForItem: (item) {
        final f = controller.getVocFicheForLabel(item.label, controller.currentQuery);
        return (f?.urlPatient, f?.urlPro);
      },
      onOpenUrl: (String url) {
        // En passant d'un badge à un autre : fermer la modale « plus d'infos » si ouverte, puis effacer page/URL/PDF et afficher le nouveau contenu.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        final u = url.trim();
        // Fichiers image (assets/) : ouvrir dans la fenêtre sous la barre, pas comme URL.
        if (u.toLowerCase().startsWith('assets/')) {
          _openAssetImageInBelowBar(u);
          return;
        }
        final lower = u.toLowerCase();
        // Tout ce qui est HTTP(S) / PDF / Word / XLS est forcé dans le panneau sous la barre.
        if (lower.endsWith('.pdf') ||
            lower.endsWith('.xls') ||
            lower.endsWith('.xlsx') ||
            lower.endsWith('.ods') ||
            lower.endsWith('.doc') ||
            lower.endsWith('.docx') ||
            lower.endsWith('.odt') ||
            u.startsWith('http://') ||
            u.startsWith('https://')) {
          _openHttpUrlInBelowBar(u);
          return;
        }
        // mailto:, tel:, etc.
        openUrl(u);
      },

      onOpenEspacePro: (BuildContext context, String url, String labName, String? iconUrl) async {
        final saved = await EspaceProCredentials.load(url);
        if (!context.mounted) return;
        // Connexion automatique : si des identifiants sont enregistrés et qu'on est sous Windows, ouvrir directement la WebView
        if (Platform.isWindows &&
            saved != null &&
            saved.email.trim().isNotEmpty &&
            saved.password.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EspaceProWebViewScreen(
                url: url,
                username: saved.email,
                password: saved.password,
                labName: labName,
              ),
            ),
          );
          return;
        }
        final result = await showDialog<EspaceProConnectResult?>(
          context: context,
          barrierLabel: 'Fermer la boîte de dialogue',
          builder: (_) => EspaceProLoginDialog(
            url: url,
            labName: labName,
            iconPath: iconUrl,
            initialEmail: saved?.email,
            initialPassword: saved?.password,
          ),
        );
        if (!context.mounted || result == null) return;
        if (Platform.isWindows) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EspaceProWebViewScreen(
                url: result.url,
                username: result.username,
                password: result.password,
                labName: labName,
              ),
            ),
          );
        } else {
          await openUrl(result.url);
        }
      },

      onOpenCataloguePdf: (BuildContext context, String pdfUrl, String labName, bool searchMode) {
        final query = searchMode ? ref.read(offiboxControllerProvider).currentQuery.trim() : null;
        setState(() {
          _pdfPanelUrl = pdfUrl;
          _pdfPanelLab = labName;
          _pdfPanelInitialQuery = query?.isNotEmpty == true ? query : null;
          _pdfPanelAutoSearch = searchMode && (query?.isNotEmpty ?? false);
        });
      },
      onDownloadCataloguePdf: controller.selectedResult?.catalogueUrl != null
          ? () {
              final result = ref.read(offiboxControllerProvider).selectedResult;
              final url = result?.catalogueUrl?.trim();
              if (url != null && url.isNotEmpty) {
                setState(() {
                  _pdfPanelUrl = url;
                  _pdfPanelLab = result?.label.split(' - trouvé dans le catalogue ').last ?? result?.label ?? '';
                  _pdfPanelInitialQuery = null;
                  _pdfPanelAutoSearch = false;
                });
              }
            }
          : null,
      showCataloguePanel: _showCataloguePanel,
      onOpenCataloguePanel: () => setState(() => _showCataloguePanel = true),
      showYouTubePanel: _showYouTubePanel,
      youtubeVideoUrl: _youtubeVideoUrl,
      onOpenYouTubeVideo: (url) => setState(() {
        _showYouTubePanel = true;
        _youtubeVideoUrl = url;
      }),
      onCloseYouTubePanel: () => setState(() {
        _showYouTubePanel = false;
        _youtubeVideoUrl = null;
      }),
      showTherapeuticVideoPanel: _showTherapeuticVideoPanel,
      therapeuticVideoUrl: _therapeuticVideoUrl,
      onOpenTherapeuticVideo: (url) => setState(() {
        _showTherapeuticVideoPanel = true;
        _therapeuticVideoUrl = url;
      }),
      onCloseTherapeuticVideo: () => setState(() {
        _showTherapeuticVideoPanel = false;
        _therapeuticVideoUrl = null;
      }),
      videosByCip13: controller.videosByCip13,
      showPharmaradioFlashPanel: _showPharmaradioFlashPanel,
      onOpenPharmaradioFlash: () => setState(() => _showPharmaradioFlashPanel = true),
      onClosePharmaradioFlash: () => setState(() => _showPharmaradioFlashPanel = false),

      // 🍔 Menu à droite du logo + clic droit sur le logo
      menuPopupKey: _menuPopupKey,
      onOpenOffibox: () async {
        _onLinkOpened();
        final uri = Uri.parse('https://offibox.fr');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      onMinimize: () => windowManager.minimize(),
      onClose: () => _showQuitConfirmationDialog(context),
      onShowAccount: () {
        showDialog<void>(
          context: context,
          barrierLabel: 'Fermer',
          builder: (_) => const AccountDialog(),
        );
      },
      onShowAbout: () async {
        final controller = ref.read(offiboxControllerProvider);
        final packageInfo = await PackageInfo.fromPlatform();
        if (!context.mounted) return;
        final countsByFamily = countByFamilyForAbout(controller.allResults);
        showDialog<void>(
          context: context,
          barrierLabel: 'Fermer',
          builder: (_) => OffiboxAboutDialog(
            version: packageInfo.version,
            versionDate: kVersionDate,
            countsByFamily: countsByFamily,
          ),
        );
      },
      onShowShortcuts: () {
        showDialog<void>(
          context: context,
          barrierLabel: 'Fermer',
          builder: (_) => AlertDialog(
            title: const Text('Raccourcis clavier'),
            content: const SingleChildScrollView(
              child: Text(
                'Échap : Refermer la barre déployée\nCtrl+O : Ouvrir la barre\nCtrl+L : Réinitialiser\nCtrl+C : Copier (résultat injecté ; si plusieurs codes : choix)\nCtrl+Q : Quitter l’application',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      onShowContact: () {
        showDialog<void>(
          context: context,
          barrierLabel: 'Fermer',
          builder: (_) => const ContactDialog(),
        );
      },
      onShowVersionHistory: () {
        showDialog<void>(
          context: context,
          barrierLabel: 'Fermer',
          builder: (_) => const VersionHistoryDialog(),
        );
      },

      onOpenGoogleAgenda: () async {
        _onLinkOpened();
        final uri = Uri.parse('https://calendar.google.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      onConnectGoogleAgenda: GoogleCalendarDesktopAuth.isNeeded
          ? () async {
              final configured = await GoogleOAuthConfig.isConfigured;
              if (!configured && mounted) {
                final credPath = await GoogleOAuthConfig.credentialsPath;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'OAuth non configuré. Créez config/oauth_credentials.json à la racine du projet '
                      '(ou $credPath pour l\'app installée) avec client_id et client_secret '
                      '(Google Cloud Console → APIs → Identifiants → OAuth 2.0).',
                    ),
                    duration: const Duration(seconds: 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final ok = await GoogleCalendarService.signInForDesktop();
              if (!mounted) return;
              final connected = await GoogleCalendarService.hasGoogleCalendarAccess();
              if (mounted) {
                setState(() => _isGoogleConnected = connected);
                if (connected) {
                  ref.invalidate(calendarEventsProvider);
                  ref.invalidate(todayCalendarEventsProvider);
                }
              }
              if (mounted) {
                final String message;
                if (connected) {
                  message = 'Agenda Google connecté';
                } else if (ok) {
                  message = 'Connexion annulée';
                } else {
                  message = 'Connexion impossible. Vérifiez : 1) API Calendrier activée dans Google Cloud, '
                      '2) URI de redirection http://localhost (autoriser le port dynamique ou ajouter http://localhost) '
                      'dans Identifiants OAuth 2.0, 3) Fichier credentials (client_id, client_secret) présent.';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: Duration(seconds: connected ? 3 : 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : null,
      onOpenIdBox: () => setState(() => _showIdeasPanel = true),
      isGoogleConnected: _isGoogleConnected,
      canConnectGoogleAgenda: canConnectGoogleAgenda,

      infoBarItems: infoBarItems,
      leadingFilterButton: null,
      appVersion: _appVersion,
      // Date de MAJ = dernier commit offiboxdata (GitHub), affichée en heure locale
      dataUpdateDate: controller.lastGithubUpdate != null
          ? () {
              final d = controller.lastGithubUpdate!.toLocal();
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }()
          : null,

      // 🔗 OUVERTURE EXPLICITE UNIQUEMENT (bouton)
      onOpenSelected: () {
        final result = ref.read(offiboxControllerProvider).selectedResult;
        if (result == null) return;
        // Mutuelles / AMO : ouvrir le site web dans le panneau sous la barre
        if ((result.source == SourceType.amc || result.source == SourceType.amo) &&
            result.url != null &&
            result.url!.trim().isNotEmpty) {
          setState(() {
            expanded = true;
            _webPanelUrl = result.url!.trim();
            _pdfPanelUrl = null;
            _xlsPanelUrl = null;
            _wordPanelUrl = null;
          });
          return;
        }
        // Outils métier / Sites web : une seule URL → ouvrir dans la fenêtre sous la barre
        if ((result.source == SourceType.keyword || result.source == SourceType.siteWeb) &&
            (result.url?.trim().isNotEmpty ?? false)) {
          final hasOther =
              (result.badge2Url?.trim().isNotEmpty ?? false) ||
              (result.badge3Url?.trim().isNotEmpty ?? false);
          if (!hasOther) {
            setState(() {
              expanded = true;
              _webPanelUrl = result.url!.trim();
              _pdfPanelUrl = null;
              _xlsPanelUrl = null;
              _wordPanelUrl = null;
            });
            return;
          }
        }
        ref.read(offiboxControllerProvider).openResult(result);
      },
                  ),
                  ),
                );
              },
            ),
          ),

          // ───────────────────────────
          // BOÎTE À IDÉES (sous la barre, sans empiéter)
          // ───────────────────────────
          if (_showIdeasPanel && expanded)
            Positioned(
              top: OffiboxWindowUI.menuBelowBarTop,
              right: OffiboxWindowUI.rightMargin,
              child: IdeasBoxPanel(
                barWidth: _barWidth(context),
                onClose: () => setState(() => _showIdeasPanel = false),
              ),
            ),

          // ───────────────────────────
          // ACTUALITÉS (news.csv) : fenêtre avant déploiement de la barre, 48 h, 2×/jour
          // ───────────────────────────
          if (_showNewsPopup && _newsPopupEntry != null)
            Positioned(
              top: OffiboxWindowUI.topMargin + 8,
              right: OffiboxWindowUI.rightMargin,
              child: NewsPopupCard(
                entry: _newsPopupEntry!,
                onClose: () => setState(() {
                  _showNewsPopup = false;
                  _newsPopupEntry = null;
                }),
              ),
            ),

          // ───────────────────────────
          // RESULTS PANEL (sous les panneaux document pour que XLS/PDF/Word/Web reçoivent les clics en priorité)
          // ───────────────────────────
          if (expanded &&
              _hasQuery &&
              controller.selectedResult == null &&
              !_showIdeasPanel)
            Positioned(
              top: topY,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: SizedBox(
                height: effectiveResults.isEmpty
                    ? 120
                    : (effectiveResults.length == 1
                        ? 118.0
                        : effectiveResults.length > 20
                            ? (21 * 78.0 + 24)
                            : effectiveResults.length * 78.0)
                        .clamp(96.0, maxPanelH),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  child: effectiveResults.isEmpty
                      ? (_searchSettledEmpty(controller)
                          ? const NoResultsMessage(key: ValueKey('no-results'))
                          : FakeResults(key: ValueKey(_skeletonKey ?? 'skeleton-pending')))
                      : ResultsPanel(
                          key: const ValueKey('results'),
                          results: effectiveResults,
                          scrollController: _resultsScroll,
                          query: controller.currentQuery,
                          statutsByCis: controller.statutsByCis,
                          tauxRemboursementByCis: controller.tauxRemboursementByCis,
                          ansmStatutsByCis: controller.ansmStatutsByCis,
                          generiques2026ByCis: controller.generiques2026ByCis,
                          generiques2026PrincepsKeyToGenericName: controller.generiques2026PrincepsKeyToGenericName,
                          generiques2026DciToGenericName: controller.generiques2026DciToGenericName,
                          generiques2026CisSet: controller.generiques2026CisSet,
                          cip13ToFic03Status: controller.cip13ToFic03Status,
                          biosimilairesInfoByCip: controller.biosimilairesInfoByCip,
                          compositionBdpmByCis: controller.compositionBdpmByCis,
                          hospitalCip13Set: controller.hospitalCip13Set,
                          recalledProductNames: controller.recalledProductNames,
                          ansmLastRappel: ref.watch(ansmLastRappelProvider).valueOrNull,
                          videosByCip13: controller.videosByCip13,
                          cisArretCommercialisation: controller.cisArretCommercialisation,
                          arretCommercialisationByCis: controller.arretCommercialisationByCis,
                          getVocUrlsForItem: (item) {
                            final f = controller.getVocFicheForLabel(item.label, controller.currentQuery);
                            return (f?.urlPatient, f?.urlPro);
                          },
                          onOpenTherapeuticVideo: (url) => setState(() {
                            _showTherapeuticVideoPanel = true;
                            _therapeuticVideoUrl = url;
                          }),

                          // ✅ CLIC SUR UN RÉSULTAT = INJECTION
                          onOpen: (item) {
                            if (item.source == SourceType.keyword &&
                                (item.label.trim().toLowerCase() == 'calculatrice' ||
                                    item.labelRaw.trim().toLowerCase() == 'calculatrice') &&
                                Platform.isWindows) {
                              Process.start('calc.exe', []);
                            }
                            final labelLower = item.label.trim().toLowerCase();
                            final labelRawLower = item.labelRaw.trim().toLowerCase();
                            if (item.source == SourceType.keyword &&
                                (labelLower == 'calculatrice de marge' || labelRawLower == 'calculatrice de marge')) {
                              setState(() {
                                _clearBelowBarPanels();
                                expanded = true;
                                _showMarginCalculatorPanel = true;
                              });
                              ref.read(offiboxControllerProvider).selectResult(item);
                              _searchController.clear();
                              _searchFocus.unfocus();
                              return;
                            }
                            ref
                                .read(offiboxControllerProvider)
                                .selectResult(item);
                            _searchController.clear();
                            _searchFocus.unfocus();
                            // Mutuelles / AMO : ouvrir le site dans le panneau sous la barre au clic
                            if ((item.source == SourceType.amc || item.source == SourceType.amo) &&
                                item.url != null &&
                                item.url!.trim().isNotEmpty) {
                              setState(() {
                                expanded = true;
                                _webPanelUrl = item.url!.trim();
                                _pdfPanelUrl = null;
                                _xlsPanelUrl = null;
                                _wordPanelUrl = null;
                              });
                              return;
                            }
                            // Outils métier / Sites web : une seule URL → ouvrir dans la fenêtre sous la barre
                            if ((item.source == SourceType.keyword || item.source == SourceType.siteWeb) &&
                                (item.url?.trim().isNotEmpty ?? false)) {
                              final hasOther =
                                  (item.badge2Url?.trim().isNotEmpty ?? false) ||
                                  (item.badge3Url?.trim().isNotEmpty ?? false);
                              if (!hasOther) {
                                setState(() {
                                  expanded = true;
                                  _webPanelUrl = item.url!.trim();
                                  _pdfPanelUrl = null;
                                  _xlsPanelUrl = null;
                                  _wordPanelUrl = null;
                                });
                              }
                            }
                          },
                          onOpenUrlFromTile: (item, url) {
                            ref
                                .read(offiboxControllerProvider)
                                .selectResult(item);
                            _searchController.clear();
                            _searchFocus.unfocus();
                            final u = url.trim();
                            if (u.toLowerCase().startsWith('assets/')) {
                              _openAssetImageInBelowBar(u);
                              return;
                            }
                            final lower = u.toLowerCase();
                            if (lower.endsWith('.pdf') ||
                                lower.endsWith('.xls') ||
                                lower.endsWith('.xlsx') ||
                                lower.endsWith('.ods') ||
                                lower.endsWith('.doc') ||
                                lower.endsWith('.docx') ||
                                lower.endsWith('.odt') ||
                                u.startsWith('http://') ||
                                u.startsWith('https://')) {
                              _openHttpUrlInBelowBar(u);
                              return;
                            }
                            openUrl(u);
                          },

                          // (laisser vide pour l’instant)
                          onOpenStatuts: (cip13, label) {
                            // futur panneau ANSM / statuts
                          },
                        ),
                ),
              ),
            ),

          // ───────────────────────────
          // XLS / PDF / Word / Web : au premier plan pour que les clics soient dans la zone document (pas en arrière-plan)
          // ───────────────────────────
          if (expanded && _xlsPanelUrl != null)
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: XlsPanelBelowBar(
                xlsUrl: _xlsPanelUrl!,
                barWidth: _barWidth(context),
                onClose: () => setState(() => _xlsPanelUrl = null),
              ),
            ),
          if (expanded && _wordPanelUrl != null)
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: WordPanelBelowBar(
                wordUrl: _wordPanelUrl!,
                barWidth: _barWidth(context),
                onClose: () => setState(() => _wordPanelUrl = null),
              ),
            ),
          if (expanded && _webPanelUrl != null)
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: WebPanelBelowBar(
                url: _webPanelUrl!,
                barWidth: _barWidth(context),
                onClose: () => setState(() => _webPanelUrl = null),
              ),
            ),
          if (expanded && _imagePanelAssetPath != null)
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: ImagePanelBelowBar(
                assetPath: _imagePanelAssetPath!,
                barWidth: _barWidth(context),
                onClose: () => setState(() => _imagePanelAssetPath = null),
              ),
            ),
          if (expanded && _showMarginCalculatorPanel)
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: MarginCalculatorPanel(
                barWidth: _barWidth(context),
                onClose: () => setState(() => _showMarginCalculatorPanel = false),
              ),
            ),
          if (expanded && (_pdfPanelUrl != null || (isPdfHitResult && selectedResult.catalogueUrl != null && !_hidePdfHitPanel)))
            Positioned(
              top: topYBelowExpandedBarXls,
              right: OffiboxWindowUI.rightMargin,
              width: _barWidth(context),
              child: PdfPanelBelowBar(
                pdfUrl: (_pdfPanelUrl ?? selectedResult!.catalogueUrl!).trim(),
                barWidth: _barWidth(context),
                onClose: () => setState(() {
                  if (_pdfPanelUrl != null) {
                    _pdfPanelUrl = null;
                    _pdfPanelLab = null;
                    _pdfPanelInitialQuery = null;
                    _pdfPanelAutoSearch = false;
                  } else {
                    _hidePdfHitPanel = true;
                  }
                }),
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

/// Badge Oui/Non du dialogue « Fermer Offibox » : style hover pill (couleurs inversées au survol).
class _QuitDialogPill extends StatefulWidget {
  const _QuitDialogPill({
    required this.label,
    required this.atRestTeal,
    required this.onTap,
  });

  final String label;
  /// true = au repos fond teal (Non), false = au repos fond blanc (Oui).
  final bool atRestTeal;
  final VoidCallback onTap;

  @override
  State<_QuitDialogPill> createState() => _QuitDialogPillState();
}

class _QuitDialogPillState extends State<_QuitDialogPill> {
  static const Color _teal = Color(0xFF5A9094);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isTealBg = _hovered ? !widget.atRestTeal : widget.atRestTeal;
    final bg = isTealBg ? _teal : Colors.white;
    final fg = isTealBg ? Colors.white : _teal;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _teal, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.30 : 0.15),
                blurRadius: _hovered ? 14 : 5,
                offset: Offset(0, _hovered ? 6 : 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Spinnaker',
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
