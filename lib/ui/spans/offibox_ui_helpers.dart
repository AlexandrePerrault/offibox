import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/date_formatters.dart';



/// Normalise pour le matching (minuscules, sans accents).
String _normalizeForHighlight(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ô]'), 'o')
      .replaceAll(RegExp(r'[ùû]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]'), ' ');
}

/// Remplit [highlight] pour les positions du texte original qui correspondent
/// aux tokens de la requête. Priorité : startsWith (début de mot) puis contains.
void _fillSearchHighlight(
  String text,
  String searchQuery,
  List<bool> highlight,
) {
  final q = searchQuery.trim().toLowerCase();
  if (q.isEmpty) return;

  final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return;

  final indexMap = <int>[];
  final normBuf = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final c = text[i].toLowerCase();
    if (RegExp(r'[a-z0-9]').hasMatch(c)) {
      final n = c
          .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
          .replaceAll('à', 'a').replaceAll('â', 'a')
          .replaceAll('î', 'i').replaceAll('ï', 'i')
          .replaceAll('ô', 'o').replaceAll('ù', 'u').replaceAll('û', 'u')
          .replaceAll('ç', 'c');
      normBuf.write(n);
      indexMap.add(i);
    }
  }
  final normalized = normBuf.toString();

  for (final token in tokens) {
    final normToken = _normalizeForHighlight(token).replaceAll(' ', '');
    if (normToken.isEmpty) continue;

    final startsWithMatches = <int>[];
    final containsMatches = <int>[];

    int start = 0;
    while (start < normalized.length) {
      final idx = normalized.indexOf(normToken, start);
      if (idx == -1) break;

      final atWordStart = idx == 0 ||
          (idx > 0 && !RegExp(r'[a-z0-9]').hasMatch(normalized[idx - 1]));
      if (atWordStart) {
        startsWithMatches.add(idx);
      } else {
        containsMatches.add(idx);
      }
      start = idx + 1;
    }

    // Surligner toutes les occurrences (début de mot ET contient) pour chaque token
    final toHighlight = [
      ...startsWithMatches,
      ...containsMatches,
    ];
    if (toHighlight.isEmpty) continue;
    for (final startIdx in toHighlight) {
      for (int k = startIdx;
          k < startIdx + normToken.length && k < indexMap.length;
          k++) {
        highlight[indexMap[k]] = true;
      }
    }
  }
}

List<InlineSpan> highlightText({
  required BuildContext context,
  required String text,
  required String searchQuery,
  bool italic = false,
  bool forceGrey = false,
  bool disableBold = false,
  bool isHop = false,
  bool isNsfp = false,
  bool disableLinks = false,
}) {
  final baseStyle = TextStyle(
    fontFamily: 'Spinnaker',
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontWeight: disableBold ? FontWeight.w400 : FontWeight.w600,
    color: forceGrey ? Colors.grey.shade500 : Colors.black87,
  );

  final searchHighlight = List<bool>.filled(text.length, false);
  _fillSearchHighlight(text, searchQuery, searchHighlight);

  final listeRegex = RegExp(r'(liste 1|liste 2)', caseSensitive: false);
  final listeMatches = listeRegex.allMatches(text).toList();

  final spans = <InlineSpan>[];
  int i = 0;

  while (i < text.length) {
    RegExpMatch? nextListe;
    for (final m in listeMatches) {
      if (m.start == i) {
        nextListe = m;
        break;
      }
    }

    if (nextListe != null) {
      final value = nextListe.group(0)!.toLowerCase();
      spans.add(
        TextSpan(
          text: value,
          style: baseStyle.copyWith(
            color: value == 'liste 1' ? Colors.red : Colors.green,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      i = nextListe.end;
      continue;
    }

    int j = i;
    final isHi = searchHighlight[i];
    while (j < text.length &&
        (listeMatches.every((m) => j < m.start || j >= m.end)) &&
        searchHighlight[j] == isHi) {
      j++;
    }

    final chunk = text.substring(i, j);
    if (chunk.isNotEmpty) {
      spans.add(
        TextSpan(
          text: chunk,
          style: isHi
              ? baseStyle.copyWith(
                  backgroundColor: Colors.yellow.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                )
              : baseStyle,
        ),
      );
    }
    i = j;
  }

  return spans;
}

InlineSpan sourceIconSpan(
  SearchResult item, {
  void Function(String url)? onOpenUrl,
}) {
  final String? url = item.url;

  final bool isDm = item.source == SourceType.dm;
  final String emoji = switch (item.source) {
    SourceType.bdm => '💊',
    SourceType.veto => '🐾',
    SourceType.amc => '🏥',
    SourceType.catalogue => '📁',
    SourceType.cerp => '📦',
    SourceType.lpp => '🩹',
    _ => '',
  };

  final Widget icon = isDm
      ? Image.asset(
          'assets/icons/dm_bandage_beige.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.medical_services_outlined,
            size: 20,
            color: OffiboxColors.primary,
          ),
        )
      : Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        );

  if (url == null || url.isEmpty || onOpenUrl == null) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: icon,
      ),
    );
  }

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onOpenUrl(url),
        child: icon,
      ),
    ),
  );
}



// ======================================================
// 🗑️ NSFP — texte en fin de ligne
// ======================================================
InlineSpan nsfpTextEndSpan(SearchResult item) {
  final rawDate = item.nsfpDate;

  if (rawDate == null || rawDate.trim().isEmpty) {
    return const TextSpan(text: '');
  }

  final date = formatToFrDate(rawDate);

  return TextSpan(
    text: ' supprimé le $date',
    style: TextStyle(
      fontSize: 12,
      fontFamily: 'Spinnaker',
      fontStyle: FontStyle.italic,
      color: item.isNsfpEffective ? Colors.red : Colors.grey,
    ),
  );
}

