import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/search_result_extensions.dart';

String normalizeLooseChar(String c) {
  return c
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String normalizeLoose(String input) {
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    buf.write(normalizeLooseChar(ch));
  }
  return buf.toString();
}

List<InlineSpan> highlightTextAdvanced(
  BuildContext context,
  String text, {
  required String query,
  required SearchResult item,
  bool italic = false,
}) {
  final qRaw = query.trim();
  if (qRaw.length < 3) {
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: Colors.black,
        ),
      ),
    ];
  }

  final lowerText = text.toLowerCase();
  final isDrug = item.isDrug;

  // ──────────────────────────────
  // NORMALISATION + INDEX MAP
  // ──────────────────────────────
  final indexMap = <int>[];
  final normalizedBuffer = StringBuffer();

  for (int i = 0; i < lowerText.length; i++) {
    final loose = normalizeLooseChar(lowerText[i]);
    if (loose.isNotEmpty) {
      normalizedBuffer.write(loose);
      indexMap.add(i);
    }
  }

  final normalizedText = normalizeLoose(normalizedBuffer.toString());
 final normalizedQuery = normalizeLoose(qRaw)
    .replaceAll(RegExp(r'(ants?|antes?|es?|s)$'), '');


  if (normalizedQuery.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    ];
  }

  // ──────────────────────────────
  // BLOCS DE 3
  // ──────────────────────────────
 final tokens = qRaw.split(RegExp(r'\s+')).where((t) => t.length >= 2);

final blocks = <String>[];

for (final token in tokens) {
  final norm = normalizeLoose(token);

  for (int i = 0; i < norm.length; i += 3) {
    final end = (i + 3 <= norm.length) ? i + 3 : norm.length;
    if (end - i >= 2) {
      blocks.add(norm.substring(i, end));
    }
  }
}


  // ──────────────────────────────
  // CONDITION D’ÉLIGIBILITÉ
  // ──────────────────────────────
  final eligible = isDrug
      ? (blocks.isNotEmpty &&
          normalizedText.startsWith(blocks.first))
      : blocks.any(normalizedText.contains);

  if (!eligible) {
    return [
      TextSpan(
        text: text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: Colors.black,
        ),
      ),
    ];
  }

  // ──────────────────────────────
  // CALCUL HIGHLIGHT
  // ──────────────────────────────
  final highlight = List<bool>.filled(text.length, false);

  for (final block in blocks) {
    int start = 0;
    while (true) {
      final idx = normalizedText.indexOf(block, start);
      if (idx == -1) break;

      for (int k = idx;
          k < idx + block.length && k < indexMap.length;
          k++) {
        highlight[indexMap[k]] = true;
      }

      start = idx + 1;
    }
  }

  // ──────────────────────────────
  // STYLES
  // ──────────────────────────────
  final baseStyle = TextStyle(
    color: italic ? Colors.grey : Colors.black,
    fontWeight: italic ? FontWeight.w400 : FontWeight.w700,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  final hiStyle = baseStyle.copyWith(
    backgroundColor: Colors.yellow.withValues(alpha: 0.55),
    fontWeight: FontWeight.w800,
  );

  // ──────────────────────────────
  // CONSTRUCTION DES SPANS
  // ──────────────────────────────
  final spans = <InlineSpan>[];
  int i = 0;

  while (i < text.length) {
    final isHi = highlight[i];
    int j = i + 1;
    while (j < text.length && highlight[j] == isHi) {
      j++;
    }

    spans.add(
      TextSpan(
        text: text.substring(i, j),
        style: isHi ? hiStyle : baseStyle,
      ),
    );
    i = j;
  }

  return spans;
}
