import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/ui/results/results_panel.dart';
import 'package:offibox/ui/widgets/fake_results.dart';

class OffiboxResultsPanel extends StatelessWidget {
  const OffiboxResultsPanel({
    super.key,
    required this.visible,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.results,
    required this.scrollController,
    required this.query,
    required this.onOpen,
    required this.onOpenStatuts,
  });

  final bool visible;
  final double top;
  final double width;
  final double maxHeight;

  final List<SearchResult> results;
  final ScrollController scrollController;
  final String query;
  final void Function(SearchResult) onOpen;
  final void Function(String cip13, String label) onOpenStatuts;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const IgnorePointer(child: SizedBox.shrink());

    final panelHeight = results.isEmpty
        ? 120.0
        : (results.length == 1 ? 118.0 : results.length * 78.0).clamp(96.0, maxHeight);

    return Positioned(
      top: top,
      right: kIsWeb ? OffiboxWindowUI.rightMarginWeb : OffiboxWindowUI.rightMargin,
      width: width,
      child: SizedBox(
        height: panelHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: results.isEmpty
              ? Container(
                  key: const ValueKey('empty'),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
                  ),
                  alignment: Alignment.center,
                  child: const FakeResults(),
                )
              : ResultsPanel(
                  key: const ValueKey('results'),
                  results: results,
                  scrollController: scrollController,
                  onOpen: onOpen,
                  onOpenStatuts: onOpenStatuts,
                  query: query,
                ),
        ),
      ),
    );
  }
}
