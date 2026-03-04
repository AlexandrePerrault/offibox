import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_type.g.dart';

@JsonEnum(alwaysCreate: true)
enum SourceType {
  bdm,
  dm,
  veto,
  lpp,
  amc,
  keyword,
  siteWeb,
  catalogue,
  cerp,
  amo,
  pharmacovigilance,
  centresAntiPoison,
  chu,
  codesActes,
}

extension SourceTypePriority on SourceType {
  int get priority {
    switch (this) {
      case SourceType.bdm:
        return 0;
      case SourceType.keyword:
      case SourceType.siteWeb:
      case SourceType.codesActes:
        return 1;
      case SourceType.dm:
        return 2;
      case SourceType.veto:
        return 3;
      case SourceType.lpp:
        return 4;
      case SourceType.amc:
        return 5;
      case SourceType.amo:
        return 5; // 🟩 même niveau qu’AMC (organismes)
      case SourceType.catalogue:
      case SourceType.cerp:
        return 6;
      case SourceType.pharmacovigilance:
      case SourceType.centresAntiPoison:
      case SourceType.chu:
        return 5;
    }
  }
}
