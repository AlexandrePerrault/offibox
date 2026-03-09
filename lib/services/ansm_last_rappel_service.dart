import 'package:http/http.dart' as http;

/// URL filtrée : rappels de produit « Médicaments » uniquement (source pour le dernier rappel et la liste).
const String ansmInformationsMedicamentsUrl =
    'https://ansm.sante.fr/informations-de-securite/?safety_news_filter%5BsafetyNewsModels%5D%5B%5D=5&safety_news_filter%5BhealthProducts%5D%5B%5D=20&safety_news_filter%5BhealthProducts%5D%5B%5D=22&safety_news_filter%5BhealthProducts%5D%5B%5D=25&safety_news_filter%5BstartDate%5D=&safety_news_filter%5BendDate%5D=';

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

  /// Décode les entités HTML les plus courantes (ex: `&#039;`, `&amp;`, `&nbsp;`).
  /// Suffisant pour normaliser les titres extraits de la page ANSM.
  static String _decodeHtmlEntities(String input) {
    if (input.isEmpty) return input;

    var s = input;
    // Named entities (subset)
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // Numeric entities: decimal &#123; and hex &#x1F4A9;
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });

    // Normalise whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static Future<AnsmRappelItem?> fetchLast() async {
    try {
      final response = await http.get(Uri.parse(ansmInformationsMedicamentsUrl));
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
      final decodedTitle = _decodeHtmlEntities(rawTitle);
      String dateStr = '';
      String libelle = decodedTitle;
      final dateMatch = RegExp(r'PUBLIÉ LE (\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(decodedTitle);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1) ?? '';
        libelle = decodedTitle.substring(dateMatch.end).trim();
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
      ),);
      isMedicament.add(isMed);
    }
    if (rappels.isEmpty) return null;
    // Barre d'infos : uniquement le dernier rappel « Médicaments » (pas les dispositifs médicaux)
    final medicaments = <AnsmRappelItem>[];
    for (var i = 0; i < rappels.length; i++) {
      if (isMedicament[i]) medicaments.add(rappels[i]);
    }
    medicaments.sort((a, b) {
      final da = _parseDate(a.dateStr);
      final db = _parseDate(b.dateStr);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // plus récent en premier
    });
    return medicaments.isNotEmpty ? medicaments.first : null;
  }

  /// Liste des rappels « Médicaments » (pour badge ligne 3 sur chaque médicament concerné). Tri par date décroissante.
  static Future<List<AnsmRappelItem>> fetchAllMedicamentRappels({int maxCount = 80}) async {
    try {
      final response = await http.get(Uri.parse(ansmInformationsMedicamentsUrl));
      if (response.statusCode != 200) return [];
      return _parseAllMedicamentRappels(response.body, maxCount: maxCount);
    } catch (_) {
      return [];
    }
  }

  static List<AnsmRappelItem> _parseAllMedicamentRappels(String html, {int maxCount = 80}) {
    final linkRegex = RegExp(
      r'<a\s+href=["\x27]([^"\x27]*informations-de-securite/[^"\x27]+)["\x27][^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final List<AnsmRappelItem> medicaments = [];
    for (final match in linkRegex.allMatches(html)) {
      var href = match.group(1) ?? '';
      final inner = match.group(2) ?? '';
      if (!inner.contains('RAPPEL DE PRODUIT')) continue;
      if (!inner.toLowerCase().contains('médicaments')) continue;
      if (href.startsWith('//')) href = 'https:$href';
      if (href.startsWith('/')) href = 'https://ansm.sante.fr$href';
      if (!href.startsWith('http')) href = 'https://ansm.sante.fr/$href';
      final rawTitle = inner
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final decodedTitle = _decodeHtmlEntities(rawTitle);
      String dateStr = '';
      String libelle = decodedTitle;
      final dateMatch = RegExp(r'PUBLIÉ LE (\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(decodedTitle);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1) ?? '';
        libelle = decodedTitle.substring(dateMatch.end).trim();
      }
      if (libelle.isEmpty) libelle = 'Rappel de produit ANSM';
      final label = dateStr.isNotEmpty
          ? 'Rappel ANSM - $dateStr : $libelle'
          : 'Rappel ANSM : $libelle';
      final slug = _slugFromRappelUrl(href);
      medicaments.add(AnsmRappelItem(
        label: label,
        url: href,
        dateStr: dateStr.isNotEmpty ? dateStr : null,
        slug: slug.isNotEmpty ? slug : null,
      ),);
    }
    medicaments.sort((a, b) {
      final da = _parseDate(a.dateStr);
      final db = _parseDate(b.dateStr);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return medicaments.length <= maxCount ? medicaments : medicaments.sublist(0, maxCount);
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
