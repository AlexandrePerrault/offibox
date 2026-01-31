String normalizeScannedInput(String raw) {
  // 1️⃣ si déjà un EAN / CIP13 simple
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13) return digits;

  // 2️⃣ DataMatrix GS1 → (01) + CIP
  final match = RegExp(r'\(01\)(\d{13,14})').firstMatch(raw);
  if (match != null) {
    final v = match.group(1)!;
    return v.length == 14 ? v.substring(1) : v;
  }

  return raw; // fallback texte normal
}
