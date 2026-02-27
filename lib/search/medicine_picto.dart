import 'package:flutter/widgets.dart';
import 'package:offibox/models/search_result.dart';

typedef MedicinePictoBuilder = InlineSpan Function(SearchResult item);
typedef MedicinePictoPredicate = bool Function(SearchResult item);

class MedicinePicto {
  final MedicinePictoPredicate isVisible;
  final MedicinePictoBuilder build;

  const MedicinePicto({
    required this.isVisible,
    required this.build,
  });
}
