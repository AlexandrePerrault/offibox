// Version web : pas d'écoute du schéma offibox://, on renvoie juste l'enfant.
import 'package:flutter/material.dart';

class OffiboxProtocolListenerWrapper extends StatelessWidget {
  const OffiboxProtocolListenerWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
