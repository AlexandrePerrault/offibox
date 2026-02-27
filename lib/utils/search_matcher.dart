import 'package:offibox/models/search_result.dart';

String normalizeForSearch(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâ]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ô]'), 'o')
      .replaceAll(RegExp('[ùû]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? extractCipForSearch(String raw) {
  final s = raw.trim();

  final m = RegExp(r'\(01\)\s*(\d{14})').firstMatch(s);
  if (m != null) {
    final gtin14 = m.group(1)!;
    if (gtin14.startsWith('0')) return gtin14.substring(1);
    return gtin14.substring(gtin14.length - 13);
  }

  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 14) {
    if (digits.startsWith('0')) return digits.substring(1);
    return digits.substring(digits.length - 13);
  }
  if (digits.length == 13 || digits.length == 7) return digits;

  return null;
}

bool matches(SearchResult r, String query) {
  final code = extractCipForSearch(query);

  if (code != null) {
    if (code.length == 13) return r.cip13 == code;
    if (code.length == 7) return r.cip7 == code;
  }

  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;

  return r.normalizedLabel.contains(q) ||
      (r.laboratory.isNotEmpty &&
          normalizeForSearch(r.laboratory).contains(q));
}
