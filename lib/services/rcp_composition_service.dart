import 'package:http/http.dart' as http;

/// Extrait la section "2. COMPOSITION QUALITATIVE ET QUANTITATIVE" du HTML RCP.
/// Retourne le texte brut de cette section (sans HTML) ou null si introuvable / erreur.
Future<String?> fetchRcpSection2Composition(String rcpUrl) async {
  if (rcpUrl.trim().isEmpty) return null;
  try {
    final uri = Uri.parse(rcpUrl.trim());
    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Délai dépassé'),
    );
    if (response.statusCode != 200) return null;
    String html = response.body;
    // Encodage : essayer UTF-8 puis Latin-1
    if (response.bodyBytes.length != response.body.length) {
      html = String.fromCharCodes(response.bodyBytes);
    }
    return _extractSection2FromHtml(html);
  } catch (_) {
    return null;
  }
}

/// Cherche la section 2 (COMPOSITION QUALITATIVE ET QUANTITATIVE) et extrait jusqu'à la section 3.
String? _extractSection2FromHtml(String html) {
  // Remplacer les balises par des espaces pour que le titre soit trouvable même avec du HTML entre les mots
  final withSpaces = html.replaceAllMapped(
    RegExp(r'<[^>]+>'),
    (_) => ' ',
  );
  final normalized = withSpaces.replaceAll(RegExp(r'\s+'), ' ');

  // Titre section 2 : variantes (2. COMPOSITION..., 2 - COMPOSITION..., etc.)
  final section2Start = RegExp(
    r'2\s*[\.\-]\s*COMPOSITION\s+QUALITATIVE\s+ET\s+QUANTITATIVE',
    caseSensitive: false,
  );
  final startMatch = section2Start.firstMatch(normalized);
  if (startMatch == null) return null;

  final startIndex = startMatch.end;
  // Fin : début de la section 3 (3. FORME PHARMACEUTIQUE ou 3 - ...)
  final section3Start = RegExp(
    r'3\s*[\.\-]\s+[A-ZÀÂÄÉÈÊËÏÎÔÙÛÜÇ\s]+',
    caseSensitive: false,
  );
  final endMatch = section3Start.firstMatch(normalized.substring(startIndex));
  final endIndex = endMatch != null
      ? startIndex + endMatch.start
      : normalized.length;

  String block = normalized.substring(startIndex, endIndex);
  block = _decodeHtmlEntities(block);
  block = block
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (block.isEmpty) return null;
  return block;
}

String _decodeHtmlEntities(String s) {
  String r = s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&egrave;', 'è')
      .replaceAll('&ecirc;', 'ê')
      .replaceAll('&agrave;', 'à')
      .replaceAll('&acirc;', 'â')
      .replaceAll('&ocirc;', 'ô')
      .replaceAll('&ucirc;', 'û')
      .replaceAll('&ccedil;', 'ç')
      .replaceAll('&icirc;', 'î')
      .replaceAll('&Eacute;', 'É');
  // &#123; et &#x7B; (décimal et hex)
  r = r.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '0');
    return code != null && code < 0x10FFFF ? String.fromCharCode(code) : m.group(0)!;
  });
  r = r.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '0', radix: 16);
    return code != null && code < 0x10FFFF ? String.fromCharCode(code) : m.group(0)!;
  });
  return r;
}
