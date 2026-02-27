import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:protocol_handler/protocol_handler.dart';

import 'package:offibox/auth/offibox_protocol_handler.dart';

/// Wrapper qui écoute les URLs du schéma `offibox://` (Windows : une instance déjà ouverte
/// reçoit l’URL quand l’utilisateur ouvre un lien offibox:// depuis le navigateur).
/// Utilisé uniquement sur Windows.
class OffiboxProtocolListenerWrapper extends StatefulWidget {
  const OffiboxProtocolListenerWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OffiboxProtocolListenerWrapper> createState() =>
      _OffiboxProtocolListenerWrapperState();
}

class _OffiboxProtocolListenerWrapperState
    extends State<OffiboxProtocolListenerWrapper> with ProtocolListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      protocolHandler.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      protocolHandler.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onProtocolUrlReceived(String url) {
    OffiboxProtocolHandler.handleUrl(url).then((handled) {
      if (handled && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Échec de la connexion via le lien'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
