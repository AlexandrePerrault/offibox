import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/ui/screens/scanner_screen.dart';
import 'package:offibox/utils/scan_controller.dart';
import 'package:offibox/services/app_update_service.dart';
import 'package:offibox/window/widgets/update_available_dialog.dart';

/// Full-screen message asking the user to rotate to landscape.
class RotateToLandscapeMessage extends StatelessWidget {
  const RotateToLandscapeMessage({
    super.key,
    this.onScanPressed,
  });

  final VoidCallback? onScanPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.screen_rotation,
                  size: 80,
                  color: OffiboxApp.offiboxTeal.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tournez votre iPad ou téléphone en mode paysage pour profiter pleinement des fonctionnalités d\'Offibox.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade300,
                    height: 1.35,
                  ),
                ),
                if (onScanPressed != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onScanPressed,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner un code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OffiboxApp.offiboxTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS shell: portrait shows rotate message, landscape shows search bar + results list.
class IosOffiboxShell extends ConsumerStatefulWidget {
  const IosOffiboxShell({super.key});

  @override
  ConsumerState<IosOffiboxShell> createState() => _IosOffiboxShellState();
}

class _IosOffiboxShellState extends ConsumerState<IosOffiboxShell> {
  final TextEditingController _searchController = TextEditingController();

  Future<void> _openScanner() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScannerScreen(
          onScanned: (raw) {
            final trimmed = raw.trim();
            final lower = trimmed.toLowerCase();
            if (lower.startsWith('http://') || lower.startsWith('https://')) {
              launchUrl(
                Uri.parse(trimmed),
                mode: LaunchMode.externalApplication,
              );
              return;
            }

            final scan = ScanController();
            scan.handle(
              raw: raw,
              onSearch: (q) {
                ref.read(offiboxControllerProvider).filter(
                      q,
                      searchFilter: ref.read(searchFilterProvider),
                    );
                setState(() {});
              },
              onScanDataMatrix: (cip13, payload) {
                ref.read(offiboxControllerProvider).filterFromScan(
                      cip13,
                      searchFilter: ref.read(searchFilterProvider),
                      payload: payload,
                    );
                setState(() {});
              },
              onScanMutuelleQr: (codePref) {
                ref.read(offiboxControllerProvider).filterFromScan(
                      codePref,
                      searchFilter: ref.read(searchFilterProvider),
                      restrictToSource: SourceType.amc,
                    );
                setState(() {});
              },
            );
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(offiboxControllerProvider).init();
      ref.read(searchFilterProvider.notifier).enableSource(SourceType.bdm);
      final updateInfo = await AppUpdateService.checkForUpdate();
      if (!mounted) return;
      if (updateInfo != null && context.mounted) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateAvailableDialog(updateInfo: updateInfo),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      return RotateToLandscapeMessage(onScanPressed: _openScanner);
    }

    final controller = ref.watch(offiboxControllerProvider);
    final results = ref.watch(effectiveResultsProvider);

    final query = _searchController.text.trim();
    final hasQuery = query.length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade900,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) {
                        final t = q.trim();
                        if (t.length >= 2) {
                          controller.filter(
                            t,
                            searchFilter: ref.read(searchFilterProvider),
                          );
                        } else {
                          controller.clearResults();
                        }
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher medicaments, LPP, mutuelles...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    tooltip: 'Scanner DataMatrix / QR',
                    onPressed: () async {
                      await _openScanner();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: !hasQuery
                  ? const Center(
                      child: Text(
                        'Saisissez au moins 2 caracteres pour rechercher',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    )
                  : controller.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF5A9094)),
                        )
                      : results.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun resultat',
                                style: TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final result = results[index];
                                return ListTile(
                                  title: Text(
                                    result.label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () => controller.selectResult(result),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
