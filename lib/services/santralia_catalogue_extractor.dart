import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';

/// Extrait codes (7 ou 13 chiffres) et libellés du catalogue Santralia PDF à partir de la page 5.
class SantraliaCatalogueExtractor {
  /// Numéro de page à partir duquel extraire (1-based). Pages 1-4 ignorées.
  static const int firstPageIndex = 5;

  /// Codes à 13 chiffres (CIP13) ou 7 chiffres.
  static final RegExp code13 = RegExp(r'\b(\d{13})\b');
  static final RegExp code7 = RegExp(r'\b(\d{7})\b');

  /// À partir des octets du PDF, extrait (code, libellé) pour toutes les pages >= [firstPageIndex].
  /// Le libellé est le texte sur la même ligne après le code, ou la ligne suivante si la ligne ne contient que le code.
  static Future<List<({String code, String libelle})>> extractFromPdfBytes(
    List<int> bytes,
  ) async {
    final document = await PdfDocument.openData(Uint8List.fromList(bytes));
    final rows = <({String code, String libelle})>[];
    try {
      for (final page in document.pages) {
        if (page.pageNumber < firstPageIndex) continue;
        await page.ensureLoaded();
        final raw = await page.loadText();
        final text = raw?.fullText ?? '';
        _parsePageText(text, rows);
      }
    } finally {
      await document.dispose();
    }
    return _dedupeByCode(rows);
  }

  static void _parsePageText(String text, List<({String code, String libelle})> out) {
    final lines = text.split(RegExp(r'\r?\n'));
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Chercher un code 13 chiffres en premier, sinon 7 chiffres
      String? code;
      final match13 = code13.firstMatch(trimmed);
      final match7 = code7.firstMatch(trimmed);
      if (match13 != null) {
        code = match13.group(1);
      } else if (match7 != null) {
        code = match7.group(1);
      }
      if (code == null) continue;

      // Libellé : reste de la ligne après le code (ou ligne suivante si rien après)
      String libelle = '';
      final idx = trimmed.indexOf(code);
      if (idx >= 0) {
        final after = trimmed.substring(idx + code.length).trim();
        libelle = after;
      }
      if (libelle.isEmpty && i + 1 < lines.length) {
        libelle = lines[i + 1].trim();
      }
      libelle = _cleanLibelle(libelle);
      if (code.isNotEmpty) {
        out.add((code: code, libelle: libelle));
      }
    }
  }

  static String _cleanLibelle(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Garde la première occurrence par code (évite doublons multi-pages).
  static List<({String code, String libelle})> _dedupeByCode(
    List<({String code, String libelle})> rows,
  ) {
    final seen = <String>{};
    return rows.where((r) {
      if (seen.contains(r.code)) return false;
      seen.add(r.code);
      return true;
    }).toList();
  }
}
