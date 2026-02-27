import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/auth/login_page.dart';
import 'package:offibox/auth/first_launch_check.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/ui/widgets/debug_banner.dart';
import 'package:offibox/window/widgets/about_dialog.dart';
import 'package:offibox/ui/widgets/hamburger_menu.dart';
import 'package:offibox/window/widgets/offibox_top_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Sur Windows, authStateChanges() peut déclencher une erreur "non-platform thread"
/// (voir https://github.com/firebase/flutterfire/issues/13340). On utilise un stream
/// par polling pour éviter d'écouter le canal natif depuis un mauvais thread.
Stream<User?> _authStreamForPlatform() {
  if (Platform.isWindows) {
    final controller = StreamController<User?>.broadcast();
    Timer? timer;
    Future<void> emit() async {
      try {
        controller.add(FirebaseAuth.instance.currentUser);
      } catch (_) {}
    }
    emit(); // valeur initiale
    timer = Timer.periodic(const Duration(seconds: 2), (_) => emit());
    controller.onCancel = () => timer.cancel();
    return controller.stream;
  }
  return FirebaseAuth.instance.authStateChanges();
}

/// Écran selon l'état d'auth (login ou FirstLaunchCheck).
/// Affiche la barre Offibox (pill + search) dès le départ.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _expanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<HamburgerMenuState> _menuPopupKey =
      GlobalKey<HamburgerMenuState>();
  Timer? _searchDebounce;

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

    return StreamBuilder<User?>(
      stream: _authStreamForPlatform(),
      builder: (context, snapshot) {
        String debugLabel;
        Widget content;

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugLabel = 'AuthGate: waiting auth stream';
          content = const Scaffold(
            backgroundColor: Color(0xFFE8F0F1),
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          final user = snapshot.data;
          if (user == null) {
            debugLabel = 'AuthGate: LoginPage';
            content = const LoginPage();
          } else {
            debugLabel = 'AuthGate: FirstLaunchCheck';
            content = const FirstLaunchCheck();
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
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
                      if (!_expanded) {
                        ref.read(offiboxControllerProvider).clearResults();
                      }
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
                            'Ctrl+O : Ouvrir\nCtrl+L : Réinitialiser\nCtrl+C : Copier\nCtrl+Q : Quitter\nÉchap : Fermer',
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
      },
    );
  }
}
