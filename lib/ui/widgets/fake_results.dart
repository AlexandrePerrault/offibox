import 'package:flutter/material.dart';

class FakeResults extends StatelessWidget {
  const FakeResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox.shrink());
  }
}

/// « Pas de résultats » en Spinnaker, affiché uniquement quand la recherche est stabilisée (Enter ou fin de saisie). Apparition en fondu.
class NoResultsMessage extends StatefulWidget {
  const NoResultsMessage({super.key});

  @override
  State<NoResultsMessage> createState() => _NoResultsMessageState();
}

class _NoResultsMessageState extends State<NoResultsMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            'pas de résultats',
            style: TextStyle(
              fontFamily: 'Spinnaker',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
