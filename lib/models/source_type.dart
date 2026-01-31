enum SourceType {
  bdm,
  dm,
  veto,
}

extension SourceTypePriority on SourceType {
  int get priority {
    switch (this) {
      case SourceType.bdm:
        return 3; // priorité maximale
      case SourceType.dm:
        return 2;
      case SourceType.veto:
        return 1;
    }
  }
}
