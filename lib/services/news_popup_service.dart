/// Une entrée actualité (news.csv) pour la popup sous la barre.
class NewsEntry {
  const NewsEntry({
    required this.title,
    required this.body,
    this.url,
    this.date,
  });
  final String title;
  final String body;
  final String? url;
  final String? date;
}

/// Récupère la dernière actualité (news.csv). Retourne null si aucune ou non disponible.
Future<NewsEntry?> fetchLatestNews() async {
  return null;
}

/// True si on doit afficher la popup pour cette entrée (ex. pas déjà vue, dans la fenêtre 48 h).
Future<bool> shouldShowNews(NewsEntry entry) async {
  return false;
}

/// Marque la news comme affichée (ex. SharedPreferences).
Future<void> markNewsShown() async {}
