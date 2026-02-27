import 'package:flutter/widgets.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/search/medicine_picto_registry.dart';

List<InlineSpan> buildMedicinePictos(SearchResult item) {
  final spans = medicinePictos
      .where((picto) => picto.isVisible(item))
      .map((picto) => picto.build(item))
      .toList();

  if (spans.isNotEmpty) {
    spans.add(const WidgetSpan(child: SizedBox(width: 6)));
  }

  return spans;
}
