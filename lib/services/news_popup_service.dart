import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/data/data_sources.dart';

/// Une entrée actualité (news.csv) pour la popup sous la barre et le bandeau de démo.
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

/// Récupère la dernière actualité (news.csv).
///
/// Format attendu (séparateur `;`, UTF‑8) :
/// - col 0 : date (ex. `10/03/2026 12:00:00`)
/// - col 1 : texte d’affichage (inclut « DGS‑Urgent », « rappel », etc.)
/// - col 2 : URL (facultatif, ex. lien ANSM / DGS)
/// - col 3 : CIP13 (facultatif).
///
/// On suppose que la ligne la plus récente est en haut du fichier (après l’en‑tête).
Future<NewsEntry?> fetchLatestNews() async {
  try {
    final uri = Uri.parse(NEWS_CSV_URL);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[Offibox] ⚠ news.csv HTTP ${response.statusCode}');
      }
      return null;
    }
    final body = utf8.decode(response.bodyBytes);
    final lines = const LineSplitter().convert(body);
    if (lines.length <= 1) return null;

    // Cherche la première ligne non vide après l’en-tête.
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final row = line
          .split(';')
          .map((e) => e.replaceAll('"', '').trim())
          .toList();
      if (row.isEmpty) continue;
      final date = row.isNotEmpty ? row[0] : '';
      final text = row.length > 1 ? row[1] : '';
      final url = row.length > 2 && row[2].isNotEmpty ? row[2] : null;
      if (text.isEmpty) continue;
      return NewsEntry(
        title: text,
        body: '',
        url: url,
        date: date,
      );
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] ⚠ news.csv erreur: $e');
  }
  return null;
}

const _kNewsPrefsKey = 'offibox_latest_news_date';

/// True si on doit afficher la popup pour cette entrée (ex. pas déjà vue récemment).
Future<bool> shouldShowNews(NewsEntry entry) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kNewsPrefsKey);
    if (entry.date == null || entry.date!.isEmpty) return true;
    if (last == null || last.isEmpty) return true;
    return last != entry.date;
  } catch (_) {
    return true;
  }
}

/// Marque la news comme affichée (ex. SharedPreferences).
Future<void> markNewsShown(NewsEntry entry) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (entry.date != null && entry.date!.isNotEmpty) {
      await prefs.setString(_kNewsPrefsKey, entry.date!);
    }
  } catch (_) {}
}
