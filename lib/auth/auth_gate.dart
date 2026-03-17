import 'dart:async';
import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:offibox/window/window_manager_stub.dart' if (dart.library.io) 'package:window_manager/window_manager.dart';

import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/auth/login_page.dart';
import 'package:offibox/auth/first_launch_check.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/services/app_update_service.dart';
import 'package:offibox/services/google_calendar_desktop_auth.dart';
import 'package:offibox/ui/widgets/debug_banner.dart';
import 'package:offibox/services/annuaire_ps_count_service.dart';
import 'package:offibox/window/widgets/about_dialog.dart';
import 'package:offibox/window/widgets/update_progress_dialog.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/window/widgets/account_dialog.dart';
import 'package:offibox/ui/results/result_tile.dart';
import 'package:offibox/window/widgets/offibox_top_bar.dart';
import 'package:offibox/system/window_click_through_stub.dart' if (dart.library.io) 'package:offibox/system/window_click_through.dart';
import 'package:offibox/diagnostics/startup_diagnostic.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Écran selon l'état d'auth (login ou FirstLaunchCheck).
/// Affiche la barre Offibox (pill + search) dès le départ.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _expanded = false;
  bool _windowSizeSynced = false;
  bool _postLoginFlowDone = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<HamburgerMenuState> _menuPopupKey =
      GlobalKey<HamburgerMenuState>();
  Timer? _searchDebounce;

  static bool _isGoogleUser(User? user) {
    return user != null &&
        user.providerData.any((p) => p.providerId == 'google.com');
  }

  Future<void> _runPostGoogleLoginFlow(BuildContext context) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Téléchargement en cours'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Vérification de la dernière version…')),
          ],
        ),
      ),
    );
    try {
      final info = await AppUpdateService.checkForUpdate(force: true);
      if (!context.mounted) return;
      if (info != null) {
        Navigator.of(context).pop();
        if (!context.mounted) return;
        if (Platform.isWindows) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => UpdateProgressDialog(updateInfo: info),
          );
        } else {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Téléchargement en cours'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 16),
                  Expanded(child: Text('Téléchargement de la version ${info.version}…')),
                ],
              ),
            ),
          );
          await AppUpdateService.downloadAndOpen(info);
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
    }
    try {
      if (!context.mounted) return;
      if (GoogleCalendarDesktopAuth.isNeeded) {
        await GoogleCalendarDesktopAuth.signIn();
        if (context.mounted) ref.invalidate(calendarEventsProvider);
      }
    } catch (_) {}
  }

  Future<void> _syncWindowSizeToExpanded(BuildContext context) async {
    if (!Platform.isWindows || !mounted) return;
    try {
      final w = _expanded
          ? (MediaQuery.sizeOf(context).width * 0.8).round() + 48
          : (OffiboxWindowUI.collapsedWidth + 24).round();
      final h = _expanded ? 420.0 : OffiboxWindowUI.barHeight + 24;
      await windowManager.setSize(Size(w.toDouble(), h));
    } catch (_) {}
  }

  void _showOpenOffiboxConfirmationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierLabel: 'Fermer la boîte de dialogue',
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Spinnaker',
                color: OffiboxColors.darkGray,
                height: 1.25,
              ),
              children: const [
                TextSpan(text: 'Fermer '),
                TextSpan(
                  text: 'Offi',
                  style: TextStyle(
                    color: OffiboxColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFamily: 'Spinnaker',
                  ),
                ),
                TextSpan(text: 'box et aller sur Offibox.fr ?'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Uri uri = Uri.parse('https://offibox.fr');
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  final token = await user.getIdToken();
                  if (token != null && token.isNotEmpty) {
                    uri = uri.replace(
                        queryParameters: {'app_login_token': token},);
                  }
                } catch (_) {}
              }
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              SystemNavigator.pop();
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  double _barWidth(BuildContext context) {
    if (!_expanded) return OffiboxWindowUI.collapsedWidth;
    return MediaQuery.of(context).size.width * 0.8;
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    _searchDebounce?.cancel();
    final controller = ref.read(offiboxControllerProvider);
    controller.cancelSearch();

    if (q.isEmpty || q.length < 2) {
      controller.clearResults();
      setState(() {});
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(offiboxControllerProvider).filter(
            q,
            searchFilter: ref.read(searchFilterProvider),
          );
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(offiboxControllerProvider);
    final authAsync = ref.watch(authStateProvider);

    String debugLabel = 'AuthGate';
    Widget content = const LoginPage();
    switch (authAsync) {
      case AsyncLoading():
        debugLabel = 'AuthGate: waiting auth stream';
        content = const Scaffold(
          backgroundColor: Color(0xFFE8F0F1),
          body: Center(child: CircularProgressIndicator()),
        );
        break;
      case AsyncData(:final value):
        final user = value;
        if (user == null) {
          debugLabel = 'AuthGate: LoginPage';
          content = const LoginPage();
        } else {
          debugLabel = 'AuthGate: FirstLaunchCheck';
          content = const FirstLaunchCheck();
        }
        break;
      case AsyncError():
        debugLabel = 'AuthGate: LoginPage';
        content = const LoginPage();
        break;
    }

    final userForWindowSync = authAsync.valueOrNull;
    if (userForWindowSync != null && !_windowSizeSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncWindowSizeToExpanded(context);
        if (mounted) setState(() => _windowSizeSynced = true);
      });
    }
    final userForPostLogin = authAsync.valueOrNull;
    if (userForPostLogin != null && _isGoogleUser(userForPostLogin) && !_postLoginFlowDone) {
      _postLoginFlowDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _runPostGoogleLoginFlow(context);
      });
    }
    final showOnlyPill = !_expanded && (authAsync.valueOrNull != null);
    // Diagnostic démarrage (une fois par affichage AuthGate)
    StartupDiagnostic.logAuthGateState(
      expanded: _expanded,
      windowSizeSynced: _windowSizeSynced,
      authLabel: debugLabel,
    );
    // Sur Windows, écran de login = fenêtre entière cliquable (pas de région).
    if (Platform.isWindows && authAsync.valueOrNull == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clearWindowRegion();
      });
    }
    return Stack(
          fit: StackFit.expand,
          children: [
            if (showOnlyPill)
              const ColoredBox(
                color: Colors.transparent,
                child: SizedBox.expand(),
              )
            else
              DebugBanner(label: debugLabel, child: content),
            Positioned(
              top: OffiboxWindowUI.topMargin,
              right: OffiboxWindowUI.rightMargin,
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: _barWidth(context),
                  child: OffiboxTopBar(
                  expanded: _expanded,
                  barWidth: _barWidth(context),
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  onSearchChanged: _onSearchChanged,
                  onTapInside: () {
                    ref.read(offiboxControllerProvider).clearSelection();
                    _searchFocus.requestFocus();
                  },
                  onToggleWindow: () {
                    setState(() {
                      _expanded = !_expanded;
                      _windowSizeSynced = false;
                      if (!_expanded) {
                        ref.read(offiboxControllerProvider).clearResults();
                      }
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _syncWindowSizeToExpanded(context);
                      if (mounted) setState(() => _windowSizeSynced = true);
                    });
                  },
                  selectedResult: controller.selectedResult,
                  statutsByCis: controller.statutsByCis,
                  ansmStatutsByCis: controller.ansmStatutsByCis,
                  generiques2026ByCis: controller.generiques2026ByCis,
                  generiques2026PrincepsKeyToGenericName: controller.generiques2026PrincepsKeyToGenericName,
                  generiques2026DciToGenericName: controller.generiques2026DciToGenericName,
                  generiques2026CisSet: controller.generiques2026CisSet,
                  cisArretCommercialisation: controller.cisArretCommercialisation,
                  arretCommercialisationByCis: controller.arretCommercialisationByCis,
                  tauxRemboursementByCis: controller.tauxRemboursementByCis,
                  getVocUrlsForItem: (item) {
                    final displayLabel = ResultLabelHelper.displayLabel(item);
                    final f = controller.getVocFicheForLabel(displayLabel, controller.currentQuery);
                    return (f?.urlPatient, f?.urlPro);
                  },
                  menuPopupKey: _menuPopupKey,
                  onOpenOffibox: () => _showOpenOffiboxConfirmationDialog(context),
                  onMinimize: () {},
                  onClose: () => SystemNavigator.pop(),
                  onShowAccount: authAsync.valueOrNull == null
                      ? null
                      : () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const AccountDialog(),
                          );
                        },
                  onShowAbout: () async {
                    final packageInfo = await PackageInfo.fromPlatform();
                    final annuairePsCount = await getAnnuairePsCount();
                    if (!context.mounted) return;
                    showDialog<void>(
                      context: context,
                      builder: (_) => OffiboxAboutDialog(
                        version: packageInfo.version,
                        versionDate: kVersionDate,
                        countsByFamily: countByFamilyForAbout(
                          controller.allResults,
                          annuairePsCount: annuairePsCount,
                        ),
                      ),
                    );
                  },
                  onShowShortcuts: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Raccourcis clavier'),
                        content: const SingleChildScrollView(
                          child: Text(
                            '''Ctrl+O : Ouvrir
Ctrl+L : Réinitialiser
Ctrl+C : Copier
Ctrl+Q : Quitter
Échap : Fermer''',
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
                    final uri = Uri.parse('https://calendar.google.com');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  isGoogleConnected: false,
                  onOpenSelected: controller.selectedResult != null
                      ? () => ref
                          .read(offiboxControllerProvider)
                          .openResult(controller.selectedResult!)
                      : null,
                  dataUpdateDate: kVersionDate,
                  licenseEndDate: null,
                ),
              ),
            ),
            ),
          ],
        );
  }
}




