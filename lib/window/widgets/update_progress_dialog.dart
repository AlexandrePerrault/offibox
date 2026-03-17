import 'package:offibox/io_platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/app/offibox_app.dart';
import 'package:offibox/services/app_update_service.dart';

class UpdateProgressDialog extends StatefulWidget {
  const UpdateProgressDialog({super.key, required this.updateInfo});
  final AppUpdateInfo updateInfo;
  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0.0;
  String _status = 'Téléchargement…';
  bool _done = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!Platform.isWindows) return;
    final ok = await AppUpdateService.downloadAndInstallSilent(widget.updateInfo, onProgress: (p, received, total) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        if (total > 0) {
          final mbR = (received / (1024 * 1024)).toStringAsFixed(1);
          final mbT = (total / (1024 * 1024)).toStringAsFixed(1);
          _status = 'Téléchargement… $mbR / $mbT Mo';
        } else {
          _status = 'Téléchargement… ${(received / (1024 * 1024)).toStringAsFixed(1)} Mo';
        }
      });
    });
    if (!mounted) return;
    if (ok) {
      setState(() { _status = 'Installation terminée. Fermeture…'; _progress = 1.0; _done = true; });
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      SystemNavigator.pop();
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_error ? 'Erreur' : (_done ? 'Mise à jour' : 'Mise à jour en cours')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_status),
        if (!_error) ...[
          const SizedBox(height: 16),
          SizedBox(width: 280, child: LinearProgressIndicator(value: _progress, backgroundColor: OffiboxApp.offiboxTeal.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation<Color>(OffiboxApp.offiboxTeal), minHeight: 8)),
        ],
        if (_error) ...[const SizedBox(height: 12), TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer'))],
      ]),
    );
  }
}