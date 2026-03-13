import 'dart:async';
import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offibox/window/window_manager_stub.dart' if (dart.library.io) 'package:window_manager/window_manager.dart';

import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/constants/app_update_config.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/services/app_update_service.dart';
import 'package:offibox/window/widgets/update_available_dialog.dart';

/// Durée minimale du préchauffage (barre 10 → 100 %) avant de passer à la suite.
const Duration _kMinPreheatDuration = Duration(seconds: 12);
/// Intervalle entre chaque palier de 10 % (10, 20, …, 100). Réparti sur la durée min pour une progression fluide.
const Duration _kProgressStepInterval = Duration(milliseconds: 1200);

/// Phases du splash au démarrage (avec fondu entre chaque).
enum _SplashPhase {
  loading,
  checkingUpdate,
  ok,
}

/// Sous Windows, précharge toutes les données (BDM, LPP, extra, etc.) au démarrage,
/// affiche "Chargement…" puis en fondu "Recherche de mise à jour…" puis "Chargement Ok.... Version X.XX",
/// et n'affiche la fenêtre principale qu'ensuite.
class WindowsPreloadWrapper extends ConsumerStatefulWidget {
  const WindowsPreloadWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<WindowsPreloadWrapper> createState() =>
      _WindowsPreloadWrapperState();
}

class _WindowsPreloadWrapperState extends ConsumerState<WindowsPreloadWrapper> {
  bool _splashDone = false;
  _SplashPhase _splashPhase = _SplashPhase.loading;
  bool _phaseTransitionScheduled = false;
  bool _updateCheckDone = false;
  /// Résultat de la vérification faite pendant le splash (pour afficher le dialogue sans rappeler l'API).
  AppUpdateInfo? _pendingUpdateInfo;
  String _appVersion = '1.0';
  DateTime? _splashStartTime;
  int _timeBasedProgress = 10; // 10, 20, …, 100 par paliers
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(offiboxControllerProvider).init();
      });
    }
    if (Platform.isWindows) {
      _splashStartTime = DateTime.now();
      _progressTimer = Timer.periodic(_kProgressStepInterval, (_) {
        if (!mounted) return;
        if (_timeBasedProgress >= 100) {
          _progressTimer?.cancel();
          return;
        }
        setState(() => _timeBasedProgress = (_timeBasedProgress + 10).clamp(10, 100));
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _moveToCheckingUpdate() async {
    if (!mounted || _splashPhase != _SplashPhase.loading) return;
    setState(() => _splashPhase = _SplashPhase.checkingUpdate);
  }

  Future<void> _moveToOk() async {
    if (!mounted) return;
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _splashPhase = _SplashPhase.ok;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    try {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  void _runUpdateCheckOnce(BuildContext context) {
    if (_updateCheckDone || !mounted) return;
    _updateCheckDone = true;
    SharedPreferences.getInstance().then((prefs) async {
      final doNotAsk = prefs.getBool(AppUpdateConfig.doNotAskKey) ?? false;
      AppUpdateInfo? info = _pendingUpdateInfo;
      _pendingUpdateInfo = null;
      info ??= await AppUpdateService.checkForUpdate(force: doNotAsk);
      if (!mounted) return;
      if (info == null) return;
      if (doNotAsk) {
        await AppUpdateService.downloadAndOpen(info);
        return;
      }
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => UpdateAvailableDialog(updateInfo: info!),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return widget.child;
    }

    final controller = ref.watch(offiboxControllerProvider);
    // Barre uniquement pilotée par le temps (10 → 20 → … → 100 %) pour un démarrage toujours à 10 %
    final displayedProgress = _timeBasedProgress;
    final progress = displayedProgress / 100.0;
    final elapsed = _splashStartTime != null
        ? DateTime.now().difference(_splashStartTime!)
        : Duration.zero;
    final minDurationReached = elapsed >= _kMinPreheatDuration;
    final loadingComplete = !controller.loading &&
        controller.loadingProgress >= 100 &&
        minDurationReached;

    // Quand le chargement est terminé (données + durée min) : passer en "recherche de mise à jour" puis "Chargement Ok"
    if (loadingComplete && !_splashDone && _splashPhase == _SplashPhase.loading && !_phaseTransitionScheduled) {
      _phaseTransitionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _moveToCheckingUpdate();
        if (!mounted) return;
        // À chaque ouverture de l'app (cold start) : vérifier les mises à jour (force: true pour ne pas limiter à 1 fois/jour).
        final updateResult = await Future.wait([
          Future<void>.delayed(const Duration(milliseconds: 600)),
          AppUpdateService.checkForUpdate(force: true),
        ]);
        final info = updateResult.length > 1 ? updateResult[1] as AppUpdateInfo? : null;
        if (mounted && info != null) _pendingUpdateInfo = info;
        if (!mounted) return;
        await _moveToOk();
      });
    }

    if (_splashDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runUpdateCheckOnce(context);
      });
      return widget.child;
    }

    // Une seule structure de splash : message et barre selon la phase (AnimatedSwitcher fera le fondu)
    final showBar = _splashPhase == _SplashPhase.loading;
    final String message = switch (_splashPhase) {
      _SplashPhase.loading => 'Chargement des données — $displayedProgress %',
      _SplashPhase.checkingUpdate => 'Recherche de mise à jour…',
      _SplashPhase.ok => 'Chargement Ok.... Version $_appVersion',
    };
    return _buildSplash(
      context,
      showBar: showBar,
      progress: progress,
      message: message,
    );
  }

  Widget _buildSplash(
    BuildContext context, {
    required bool showBar,
    double progress = 0.0,
    required String message,
  }) {
    final isOk = message.startsWith('Chargement Ok');
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Image.asset(
                'assets/icons/logo_offibox.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.medication,
                  size: 72,
                  color: OffiboxApp.offiboxTeal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (showBar) ...[
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: OffiboxApp.offiboxTeal.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(OffiboxApp.offiboxTeal),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              child: Text(
                message,
                key: ValueKey<String>(message),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: isOk ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
