String normalizeScannedInput(String raw) {
  // 🔢 Extraction brute des chiffres
  final digits = raw.replaceAll(RegExp(r'\D'), '');

  // ✅ CIP13 / EAN13 direct
  if (digits.length == 13) return digits;

  // ✅ GS1 (01)xxxxxxxxxxxxx
  final match = RegExp(r'\(01\)(\d{13,14})').firstMatch(raw);
  if (match != null) {
    final v = match.group(1)!;
    // GS1 peut inclure un chiffre de tête
    return v.length == 14 ? v.substring(1) : v;
  }

  // 🔁 fallback texte
  return raw;
}

/// 🎯 Contrôleur de scan Offibox
class ScanController {
  void handle({
    required String raw,
    required void Function(String) onSearch,
  }) {
    final normalized = normalizeScannedInput(raw);
    onSearch(normalized);
  }

  void dispose() {}
}
