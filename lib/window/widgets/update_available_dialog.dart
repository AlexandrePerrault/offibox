import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/constants/app_update_config.dart';
import 'package:offibox/services/app_update_service.dart';

/// Dialogue affiché quand une nouvelle version est disponible.
/// Propose d'installer (Oui / Non) et une option « Ne plus me demander à l'avenir ».
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
    final ok = await AppUpdateService.downloadAndOpen(widget.updateInfo);
    if (!mounted) return;
    Navigator.of(context).pop(ok);
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
      title: const Text('Mise à jour'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      ),
    );
  }
}
