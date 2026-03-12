import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/data/data_sources.dart';
import 'package:offibox/data/offiboxdata_fetch.dart';

/// Une entrée actualité (news.csv) pour la popup sous la barre et le bandeau de démo.
class NewsEntry {
  const NewsEntry({
    required this.title,
    required this.body,
    this.url,
    this.date,
    this.source,
  });
  final String title;
  final String body;
  final String? url;
  final String? date;
  /// Source (colonne D du CSV), affichée en italique sous l'info.
  final String? source;
}

/// Récupère la dernière actualité (news.csv).
///
/// Format attendu (séparateur `;`, UTF‑8) :
/// - col 0 : date (ex. `10/03/2026 12:00:00`)
/// - col 1 : texte d’affichage (inclut « DGS‑Urgent », « rappel », etc.)
/// - col 2 : URL (facultatif, ex. lien ANSM / DGS)
/// - col 3 (D) : source (facultatif), affichée en italique sous l'info.
///
/// On suppose que la ligne la plus récente est en haut du fichier (après l’en‑tête).
Future<NewsEntry?> fetchLatestNews() async {
  try {
    final response = await OffiboxDataFetch.get(NEWS_CSV_URL);
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[Offibox] Actualités non disponibles (HTTP ${response.statusCode})');
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
      final source = row.length > 3 && row[3].isNotEmpty ? row[3] : null;
      if (text.isEmpty) continue;
      return NewsEntry(
        title: text,
        body: '',
        url: url,
        date: date,
        source: source,
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

/// Formate la date brute (ex. "10/03/2026 12:00:00" ou "2026-03-10") en JJ:mm/YYYY (ex. "10:03/2026").
String? formatNewsDateDisplay(String? rawDate) {
  if (rawDate == null || rawDate.trim().isEmpty) return null;
  final s = rawDate.trim();
  // DD/MM/YYYY ou DD/MM/YYYY HH:MM:SS
  final ddmmyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
  final m = ddmmyyyy.firstMatch(s);
  if (m != null) {
    final j = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    final a = m.group(3)!;
    return '$j:$mo/$a';
  }
  // YYYY-MM-DD
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
  final m2 = iso.firstMatch(s);
  if (m2 != null) {
    final a = m2.group(1)!;
    final mo = m2.group(2)!;
    final j = m2.group(3)!;
    return '$j:$mo/$a';
  }
  return null;
}
