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
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/ui/results/results_panel.dart';
import 'package:offibox/ui/widgets/fake_results.dart';
import 'package:offibox/window/offibox_window_shortcuts.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/window/widgets/offibox_top_bar.dart';
import 'package:offibox/ui/widgets/offibox_info_bar.dart';
import 'package:offibox/services/admin_service.dart';
import 'package:offibox/services/google_calendar_service.dart';
import 'package:offibox/services/google_calendar_desktop_auth.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';
import 'package:offibox/window/widgets/about_dialog.dart';
import 'package:offibox/window/widgets/ideas_box_panel.dart';
import 'package:offibox/ui/widgets/xls_panel_below_bar.dart';
import 'package:offibox/ui/widgets/word_panel_below_bar.dart';
import 'package:offibox/ui/widgets/pdf_panel_below_bar.dart';
import 'dart:io' show Platform, Process;

import 'package:offibox/data/espace_pro_credentials.dart';
import 'package:offibox/ui/dialogs/espace_pro_login_dialog.dart';
import 'package:offibox/ui/screens/espace_pro_webview_screen.dart';
import 'package:offibox/services/pdf_preloader.dart';
import 'package:offibox/services/journees_mondiales.dart';
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

/// Libellé court pour la barre d'infos : "Dernier rappel de lot (DD/MM/YYYY) : [produit – labo]".
String _lastRappelLabel(String fullLabel, String? dateStr) {
  final datePart = (dateStr != null && dateStr.trim().isNotEmpty) ? ' (${dateStr.trim()})' : '';
  final prefix = 'Dernier rappel de lot$datePart : ';
  final idx = fullLabel.indexOf(' : ');
  final libelle = idx >= 0 ? fullLabel.substring(idx + 3).trim() : fullLabel;
  const maxLen = 55;
  final short = libelle.length > maxLen ? '${libelle.substring(0, maxLen - 1)}…' : libelle;
  return '$prefix$short';
}

class _OffiboxWindowState extends ConsumerState<OffiboxWindow>
    with WidgetsBindingObserver {
  bool expanded = false;
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
  String? _pdfPanelLab;
  String? _pdfPanelInitialQuery;
  bool _pdfPanelAutoSearch = false;
  /// Masquer le viewer PDF issu du résultat catalogue (isPdfHitResult) quand l'utilisateur ferme le panneau.
  bool _hidePdfHitPanel = false;
  /// XLS/XLSX ouvert sous la barre (format 16:9).
  String? _xlsPanelUrl;
  /// Word (DOC/DOCX) ouvert sous la barre (format 16:9).
  String? _wordPanelUrl;
  String _appVersion = '1.0.0';

  final GlobalKey<HamburgerMenuState> _menuPopupKey =
      GlobalKey<HamburgerMenuState>();

  Timer? _debounce;
  Timer? _ansmRefreshTimer;
  bool _filterHovered = false;

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

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  onBeforeOpenLink = _onLinkOpened;

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

    final controller = ref.read(offiboxControllerProvider);
    controller.cancelSearch();

    if (q.length < 2) {
      controller.clearResults();
      setState(() {});
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 200), () {
      controller.filter(q, searchFilter: ref.read(searchFilterProvider));
    });
  }

  void _open() {
    setState(() {
      expanded = true;
      _searchController.clear();
    });

    _windowFocus.requestFocus();
    _searchFocus.requestFocus();
    ref.read(offiboxControllerProvider).clearResults();
  }

  void _close() {
    setState(() {
      expanded = false;
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
                    child: Image.asset(
                      'assets/icons/logo_offibox_installer.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Offibox',
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
                const TextSpan(text: ' ?'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await windowManager.show();
              await windowManager.focus();
            },
            child: const Text('Non', style: TextStyle(fontSize: 13)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: OffiboxColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Oui', style: TextStyle(fontSize: 13)),
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

  /// Hauteur de la barre déployée selon le nombre de lignes du résultat (médicaments : 2, 3 ou 4 lignes).
  double? _effectiveExpandedBarHeight(SearchResult? item) {
    if (item == null) return null;
    final singleLine = item.source == SourceType.keyword ||
        item.source == SourceType.siteWeb ||
        item.source == SourceType.catalogue ||
        item.source == SourceType.dm;
    if (singleLine) return OffiboxWindowUI.barHeightExpandedSingleLine;
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
  final controller = ref.watch(offiboxControllerProvider);
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
    }
  });
  ref.listen(cataloguePdfItemsProvider, (prev, next) {
    if (next.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PdfPreloader.preloadCatalogues(next);
      });
    }
  });
  final dgsUrgent = ref.watch(dgsUrgentProvider).valueOrNull;
  final ansmRappel = ref.watch(ansmLastRappelProvider).valueOrNull;
  final ansmStatut = ref.watch(ansmLastStatutProvider).valueOrNull;
  final calendarEvents = ref.watch(calendarEventsProvider).valueOrNull ?? [];
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
    if (ansmRappel != null)
      (
        label: _lastRappelLabel(ansmRappel.label, ansmRappel.dateStr),
        url: ansmRappel.url,
        tooltip: ansmRappel.label,
        icon: TickerItemIcon.none,
        isAnsm: true,
        isDgs: false,
        colorOverride: const Color(0xFFC62828), // rouge, texte blanc
      ),
    (
      label: ansmStatut?.label ?? 'Info médicament (ANSM)',
      url: ansmStatut?.url ?? 'https://ansm.sante.fr/',
      tooltip: null, // pas de tooltip pour éviter doublon avec le libellé
      icon: TickerItemIcon.none,
      isAnsm: true,
      isDgs: false,
      colorOverride: ansmStatut != null ? colorForStatutLevel(ansmStatut.statusLevel) : const Color(0xFF42A5F5), // bleu clair
    ),
    // Journées mondiales (santé / WHO) en mauve dans la barre déroulante ; sinon fallback Actualités en gris
    if (nextJournee != null)
      (
        label: nextJournee!.label,
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
    if (_isGoogleConnected && calendarEvents.isNotEmpty)
      (
        label: 'Prochain rdv',
        url: 'https://calendar.google.com/',
        tooltip: '${calendarEvents.first.timeLabel} ${calendarEvents.first.summary}',
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
  final selectedResult = controller.selectedResult;
  final effectiveExpandedBarHeight = _effectiveExpandedBarHeight(selectedResult);
  final expandedBarH = effectiveExpandedBarHeight ?? OffiboxWindowUI.barHeightExpanded;
  final topYBelowExpandedBar = OffiboxWindowUI.topMargin +
      (_infoBarExpanded
          ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap
          : 0) +
      OffiboxWindowUI.barHeightExpanded +
      OffiboxWindowUI.gapBelowBar +
      8;
  /// Lecteur XLS : collé à la barre (sans les 8 px d’écart).
  final topYBelowExpandedBarXls = OffiboxWindowUI.topMargin +
      (_infoBarExpanded
          ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap
          : 0) +
      OffiboxWindowUI.barHeightExpanded;
  final isPdfHitResult = selectedResult != null &&
      selectedResult.source == SourceType.catalogue &&
      selectedResult.catalogueUrl != null &&
      selectedResult.label.contains(' - trouvé dans le catalogue ');
  final pdfHitQuery = isPdfHitResult
      ? selectedResult.label.split(' - trouvé dans le catalogue ').first.trim()
      : null;
  final shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyQ, control: true): const QuitIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX, control: true): const QuitIntent(),
    if (selectedResult != null)
      const SingleActivator(LogicalKeyboardKey.keyC, control: true):
          const CopyResultIntent(),
  };

  return Scaffold(
    backgroundColor: const Color(0xFFE8F0F1),
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
              SystemNavigator.pop();
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
          // TOP BAR
          // ───────────────────────────
          Positioned(
            top: OffiboxWindowUI.topMargin,
            right: OffiboxWindowUI.rightMargin,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = _barWidth(context);
                return SizedBox(
                  width: w,
                  child: OffiboxTopBar(
                    expanded: expanded,
      infoBarExpanded: _infoBarExpanded,
      onToggleInfoBar: () => setState(() => _infoBarExpanded = !_infoBarExpanded),
      barWidth: _barWidth(context),
      barBottomY: OffiboxWindowUI.topMargin +
          (_infoBarExpanded ? OffiboxWindowUI.tickerBarHeight + OffiboxWindowUI.tickerBarGap : 0) +
          (expanded ? (effectiveExpandedBarHeight ?? OffiboxWindowUI.barHeightExpanded) : OffiboxWindowUI.barHeight),
      barTopY: OffiboxWindowUI.topMargin,
      rightMargin: OffiboxWindowUI.rightMargin,
      searchController: _searchController,
      searchFocus: _searchFocus,
      onSearchChanged: _onSearchChanged,
      onSearchSubmit: (value) {
        final q = value.trim();
        if (q.isEmpty) return;
        final qLower = q.toLowerCase();
        if (qLower == 'calculatrice' && Platform.isWindows) {
          Process.start('calc.exe', []);
          return;
        }
        if (q.length >= 2) {
          _debounce?.cancel();
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
      scanPayload: controller.lastScanPayload,
      recalledProductNames: controller.recalledProductNames,
      ansmLastRappel: ref.watch(ansmLastRappelProvider).valueOrNull,
      filterHovered: _filterHovered,
      onFilterHoverChange: (v) => setState(() => _filterHovered = v),

      onTapInside: () {
        ref.read(offiboxControllerProvider).clearSelection();
        _searchFocus.requestFocus();
        // Quand on clique dans la barre (vide), faire disparaître les panneaux XLS, Word, PDF, vidéo, etc.
        if (_searchController.text.trim().isEmpty) {
          setState(() {
            _xlsPanelUrl = null;
            _wordPanelUrl = null;
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

      // 🔍 résultat sélectionné
      selectedResult: controller.selectedResult,
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
        final u = url.trim();
        final lower = u.toLowerCase();
        if (lower.endsWith('.pdf')) {
          setState(() {
            _pdfPanelUrl = u;
            _pdfPanelLab = 'Document';
            _pdfPanelInitialQuery = null;
            _pdfPanelAutoSearch = false;
          });
        } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
          setState(() {
            _xlsPanelUrl = u;
            _wordPanelUrl = null;
          });
        } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
          setState(() {
            _wordPanelUrl = u;
            _xlsPanelUrl = null;
          });
        } else {
          openUrl(u);
        }
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
        final query = searchMode ? ref.read(offiboxControllerProvider).currentQuery?.trim() : null;
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
      onClose: () => SystemNavigator.pop(),
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

      onOpenGoogleAgenda: () async {
        _onLinkOpened();
        final uri = Uri.parse('https://calendar.google.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      onConnectGoogleAgenda: GoogleCalendarDesktopAuth.isNeeded
          ? () async {
              final ok = await GoogleCalendarService.signInForDesktop();
              if (!mounted) return;
              final connected = await GoogleCalendarService.hasGoogleCalendarAccess();
              if (mounted) setState(() => _isGoogleConnected = connected);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(connected
                        ? 'Agenda Google connecté'
                        : ok
                            ? 'Connexion annulée'
                            : 'Connexion impossible (vérifier la configuration OAuth)'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : null,
      onOpenIdBox: () => setState(() => _showIdeasPanel = true),
      isGoogleConnected: _isGoogleConnected,

      infoBarItems: infoBarItems,
      leadingFilterButton: null,
      appVersion: _appVersion,

      // 🔗 OUVERTURE EXPLICITE UNIQUEMENT (bouton)
      onOpenSelected: () {
        final result = ref.read(offiboxControllerProvider).selectedResult;
        if (result != null) {
          ref.read(offiboxControllerProvider).openResult(result);
        }
      },
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
          // XLS/XLSX : panneau sous la barre (format 16:9)
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

          // ───────────────────────────
          // Word (DOC/DOCX) : panneau sous la barre (format 16:9, mêmes fonctions que XLS)
          // ───────────────────────────
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

          // ───────────────────────────
          // PDF : lecteur 16/9 sous la barre (tout PDF : clic lien ou résultat catalogue)
          // ───────────────────────────
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

          // ───────────────────────────
          // RESULTS PANEL
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
                          : const FakeResults(key: ValueKey('skeleton')))
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
                            ref
                                .read(offiboxControllerProvider)
                                .selectResult(item);
                            _searchController.clear();
                            _searchFocus.unfocus();
                          },
                          onOpenUrlFromTile: (item, _) {
                            ref
                                .read(offiboxControllerProvider)
                                .selectResult(item);
                            _searchController.clear();
                            _searchFocus.unfocus();
                          },

                          // (laisser vide pour l’instant)
                          onOpenStatuts: (cip13, label) {
                            // futur panneau ANSM / statuts
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
  );
}

}
