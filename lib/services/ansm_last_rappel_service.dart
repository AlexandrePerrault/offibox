import 'package:http/http.dart' as http;

const String _ansmInformationsUrl =
    'https://ansm.sante.fr/informations-de-securite/';

/// Dernier rappel de produit ANSM affiché sur la barre d'info (date + libellé complet + URL).
class AnsmRappelItem {
  const AnsmRappelItem({
    required this.label,
    required this.url,
    this.dateStr,
    this.slug,
  });

  /// Format : Rappel ANSM - DD/MM/YYYY : libellé complet du site ANSM.
  final String label;
  final String url;
  /// Date du rappel au format DD/MM/YYYY (ex. "21/02/2025"), null si non parsée.
  final String? dateStr;
  /// Slug du produit depuis l'URL (ex. doliprane-2-4-pour-cent-suspension-buvable-opella-healthcare-france-sas) pour cibler uniquement ce produit.
  final String? slug;
}

/// Récupère le dernier "RAPPEL DE PRODUIT" depuis la page Informations de sécurité ANSM.
class AnsmLastRappelService {
  AnsmLastRappelService._();

  static Future<AnsmRappelItem?> fetchLast() async {
    try {
      final response = await http.get(Uri.parse(_ansmInformationsUrl));
      if (response.statusCode != 200) return null;
      return _parse(response.body);
    } catch (_) {
      return null;
    }
  }

  static AnsmRappelItem? _parse(String html) {
    // Tous les liens "RAPPEL DE PRODUIT", puis on garde le plus récent des rappels "Médicaments"
    // (sinon le premier de la page peut être un dispositif et le rappel Doliprane n'apparaît pas)
    final linkRegex = RegExp(
      r'<a\s+href=["\x27]([^"\x27]*informations-de-securite/[^"\x27]+)["\x27][^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final List<AnsmRappelItem> rappels = [];
    final List<bool> isMedicament = [];
    for (final match in linkRegex.allMatches(html)) {
      var href = match.group(1) ?? '';
      final inner = match.group(2) ?? '';
      if (!inner.contains('RAPPEL DE PRODUIT')) continue;
      final isMed = inner.toLowerCase().contains('médicaments');
      if (href.startsWith('//')) href = 'https:$href';
      if (href.startsWith('/')) href = 'https://ansm.sante.fr$href';
      if (!href.startsWith('http')) href = 'https://ansm.sante.fr/$href';
      final rawTitle = inner
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      String dateStr = '';
      String libelle = rawTitle;
      final dateMatch = RegExp(r'PUBLIÉ LE (\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(rawTitle);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1) ?? '';
        libelle = rawTitle.substring(dateMatch.end).trim();
      }
      if (libelle.isEmpty) libelle = 'Rappel de produit ANSM';
      final label = dateStr.isNotEmpty
          ? 'Rappel ANSM - $dateStr : $libelle'
          : 'Rappel ANSM : $libelle';
      final slug = _slugFromRappelUrl(href);
      rappels.add(AnsmRappelItem(
        label: label,
        url: href,
        dateStr: dateStr.isNotEmpty ? dateStr : null,
        slug: slug.isNotEmpty ? slug : null,
      ));
      isMedicament.add(isMed);
    }
    if (rappels.isEmpty) return null;
    // Priorité : rappels "Médicaments" (ex. Doliprane), tri par date décroissante
    final medicaments = <AnsmRappelItem>[];
    for (var i = 0; i < rappels.length; i++) {
      if (isMedicament[i]) medicaments.add(rappels[i]);
    }
    final toSort = medicaments.isNotEmpty ? medicaments : rappels;
    toSort.sort((a, b) {
      final da = _parseDate(a.dateStr);
      final db = _parseDate(b.dateStr);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // plus récent en premier
    });
    return toSort.isNotEmpty ? toSort.first : null;
  }

  /// Extrait le slug produit de l'URL (segment après informations-de-securite/).
  static String _slugFromRappelUrl(String href) {
    try {
      final uri = Uri.parse(href);
      final path = uri.path;
      const prefix = '/informations-de-securite/';
      final i = path.toLowerCase().indexOf(prefix);
      if (i < 0) return '';
      final after = path.substring(i + prefix.length).trim();
      final end = after.contains('/') ? after.indexOf('/') : after.length;
      return after.substring(0, end).trim();
    } catch (_) {
      return '';
    }
  }

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
