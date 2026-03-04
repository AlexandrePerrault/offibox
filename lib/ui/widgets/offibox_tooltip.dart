import 'package:flutter/material.dart';

/// Tooltip unifié : message en minuscules, style via le thème (anthracite, blanc, non gras, compact).
class OffiboxTooltip extends StatelessWidget {
  const OffiboxTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration,
    this.preferBelow,
  });

  final String message;
  final Widget child;
  final Duration? waitDuration;
  final bool? preferBelow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message.toLowerCase(),
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      child: child,
    );
  }
}
