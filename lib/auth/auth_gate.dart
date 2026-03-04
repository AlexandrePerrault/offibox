import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'package:offibox/auth/auth_state_provider.dart';
import 'package:offibox/auth/login_page.dart';
import 'package:offibox/auth/first_launch_check.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/services/app_update_service.dart';
import 'package:offibox/services/google_calendar_desktop_auth.dart';
import 'package:offibox/ui/widgets/debug_banner.dart';
import 'package:offibox/window/widgets/about_dialog.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/window/widgets/offibox_top_bar.dart';
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
      if (info != null && mounted) {
        Navigator.of(context).pop();
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Téléchargement en cours'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Téléchargement de la version ${info.version}…',
                  ),
                ),
              ],
            ),
          ),
        );
        await AppUpdateService.downloadAndOpen(info);
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
    try {
      if (mounted && GoogleCalendarDesktopAuth.isNeeded) {
        await GoogleCalendarDesktopAuth.signIn();
        if (mounted) ref.invalidate(calendarEventsProvider);
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
                    final f = controller.getVocFicheForLabel(item.label, controller.currentQuery);
                    return (f?.urlPatient, f?.urlPro);
                  },
                  menuPopupKey: _menuPopupKey,
                  onOpenOffibox: () async {
                    final uri = Uri.parse('https://offibox.fr');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  onMinimize: () {},
                  onClose: () => SystemNavigator.pop(),
                  onShowAbout: () async {
                    final packageInfo = await PackageInfo.fromPlatform();
                    if (!context.mounted) return;
                    showDialog<void>(
                      context: context,
                      builder: (_) => OffiboxAboutDialog(
                        version: packageInfo.version,
                        versionDate: kVersionDate,
                        countsByFamily: countByFamilyForAbout(controller.allResults),
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
                ),
              ),
            ),
            ),
          ],
        );
  }
}




