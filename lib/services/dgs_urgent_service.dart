import 'package:http/http.dart' as http;

const String _dgsUrgentUrl =
    'https://sante.gouv.fr/professionnels/article/dgs-urgent';

/// Dernier message DGS-Urgent affiché (titre + lien page ou PDF).
class DgsUrgentItem {
  const DgsUrgentItem({
    required this.title,
    required this.dateLabel,
    required this.pageUrl,
    this.pdfUrl,
  });

  final String title;
  final String dateLabel;
  final String pageUrl;
  final String? pdfUrl;
}

/// Récupère le dernier DGS-Urgent depuis la page sante.gouv.fr.
class DgsUrgentService {
  DgsUrgentService._();

  static Future<DgsUrgentItem?> fetchLast() async {
    try {
      final response = await http.get(Uri.parse(_dgsUrgentUrl));
      if (response.statusCode != 200) return null;
      return _parse(response.body);
    } catch (_) {
      return null;
    }
  }

  static DgsUrgentItem? _parse(String html) {
    // Repérer la section "Les derniers DGS-Urgent" puis le premier message
    const section = 'Les derniers DGS-Urgent';
    final idx = html.indexOf(section);
    if (idx == -1) return null;

    final block = html.substring(idx, idx + 2500);

    // "Message du 04 février 2026" — \p{L} pour les mois français (é, è, etc.)
    final dateMatch = RegExp(r'Message du (\d{1,2}\s+[\p{L}]+\s+\d{4})', unicode: true).firstMatch(block);
    final dateLabel = dateMatch?.group(1) ?? '';

    // Titre depuis title="DGS-Urgent n°2026-02 ..." ou title='...'
    final titleMatch = RegExp(
      r'title=.(DGS-Urgent[^"]+).',
      caseSensitive: false,
    ).firstMatch(block);
    String parsedTitle = titleMatch?.group(1) ?? 'DGS-Urgent';
    parsedTitle = parsedTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (parsedTitle.length > 75) parsedTitle = '${parsedTitle.substring(0, 72)}…';

    // Lien PDF (premier href .pdf dans le bloc)
    final pdfRegex = RegExp(
      r'https://sante\.gouv\.fr/professionnels/article/IMG/pdf/[^\s"\)]+\.pdf',
    );
    final pdfMatch = pdfRegex.firstMatch(block);
    final pdfUrl = pdfMatch?.group(0);

    return DgsUrgentItem(
      title: parsedTitle,
      dateLabel: dateLabel,
      pageUrl: _dgsUrgentUrl,
      pdfUrl: pdfUrl,
    );
  }
}
