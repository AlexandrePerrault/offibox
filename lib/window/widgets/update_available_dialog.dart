import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/constants/app_update_config.dart';
import 'package:offibox/services/app_update_service.dart';

/// Dialogue affiché quand une nouvelle version est disponible.
/// Propose d'installer (Oui / Non) avec barre de progression, installation silencieuse (pas d'UI du setup).
class UpdateAvailableDialog extends StatefulWidget {
  const UpdateAvailableDialog({
    super.key,
    required this.updateInfo,
  });

  final AppUpdateInfo updateInfo;

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  bool _doNotAskAgain = false;
  bool _installing = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<void> _install() async {
    if (_doNotAskAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppUpdateConfig.doNotAskKey, true);
    }
    if (widget.updateInfo.isIos) {
      final uri = Uri.tryParse(widget.updateInfo.downloadUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    if (!Platform.isWindows) {
      final ok = await AppUpdateService.downloadAndOpen(widget.updateInfo);
      if (!mounted) return;
      Navigator.of(context).pop(ok);
      return;
    }
    setState(() {
      _installing = true;
      _downloadProgress = 0.0;
      _statusText = 'Téléchargement…';
    });
    final ok = await AppUpdateService.downloadAndInstallSilent(
      widget.updateInfo,
      onProgress: (progress, received, total) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
          if (total > 0) {
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
            _statusText = 'Téléchargement… $mbReceived / $mbTotal Mo';
          } else {
            _statusText = 'Téléchargement… ${(received / (1024 * 1024)).toStringAsFixed(1)} Mo';
          }
        });
      },
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _statusText = 'Installation terminée. Fermeture…';
        _downloadProgress = 1.0;
      });
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      SystemNavigator.pop();
    } else {
      setState(() => _installing = false);
    }
  }

  Future<void> _skip() async {
    if (_doNotAskAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppUpdateConfig.doNotAskKey, true);
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_installing ? 'Mise à jour en cours' : 'Mise à jour'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_installing) ...[
            Text(_statusText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: OffiboxApp.offiboxTeal.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(OffiboxApp.offiboxTeal),
                  minHeight: 8,
                ),
              ),
            ),
          ] else ...[
            Text(
              widget.updateInfo.isIos
                  ? 'Une mise à jour est disponible (${widget.updateInfo.version}). Ouvrir la page de téléchargement ?'
                  : 'Nouvelle version disponible (${widget.updateInfo.version}). Installer maintenant ?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _skip,
                  child: const Text('Non'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OffiboxApp.offiboxTeal,
                  ),
                  onPressed: _install,
                  child: Text(widget.updateInfo.isIos ? 'Ouvrir' : 'Oui'),
                ),
              ],
            ),
          ],
          if (!_installing) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
            value: _doNotAskAgain,
            onChanged: (v) => setState(() => _doNotAskAgain = v ?? false),
            title: Text(
              'Ne plus me demander à l\'avenir',
              style: theme.textTheme.bodySmall,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          ],
        ],
      ),
    );
  }
}
