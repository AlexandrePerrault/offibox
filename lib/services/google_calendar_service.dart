import 'dart:convert';

import 'package:http/http.dart' as http;


import 'package:offibox/auth/google_sign_in_helper.dart';
import 'package:offibox/services/google_calendar_desktop_auth.dart';

/// Événement agenda (titre + heure de début).
class CalendarEvent {
  const CalendarEvent({
    required this.summary,
    required this.start,
    this.isAllDay = false,
  });

  final String summary;
  final DateTime start;
  final bool isAllDay;

  String get timeLabel {
    if (isAllDay) return 'Journée';
    return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  }
}

/// Récupère les prochains événements Google Calendar (utilisateur connecté avec Google).
class GoogleCalendarService {
  GoogleCalendarService._();

  static const _base = 'https://www.googleapis.com/calendar/v3';

  /// Retourne les événements du jour (date locale courante).
  /// Retourne une liste vide si pas connecté Google ou erreur.
  static Future<List<CalendarEvent>> getTodayEvents() async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) return [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final timeMin = startOfDay.toUtc().toIso8601String();
    final timeMax = endOfDay.toUtc().toIso8601String();

    final uri = Uri.parse(
      '$_base/calendars/primary/events'
      '?timeMin=${Uri.encodeComponent(timeMin)}'
      '&timeMax=${Uri.encodeComponent(timeMax)}'
      '&singleEvents=true'
      '&orderBy=startTime'
      '&maxResults=50',
    );
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      final List<CalendarEvent> events = [];

      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final summary = itemMap['summary'] as String? ?? 'Sans titre';
        final start = itemMap['start'] as Map<String, dynamic>?;
        if (start == null) continue;

        DateTime startDt;
        bool isAllDay = false;
        if (start.containsKey('dateTime')) {
          startDt = DateTime.parse(start['dateTime'] as String);
        } else if (start.containsKey('date')) {
          isAllDay = true;
          startDt = DateTime.parse(start['date'] as String);
        } else {
          continue;
        }

        events.add(CalendarEvent(
          summary: summary,
          start: startDt,
          isAllDay: isAllDay,
        ));
      }

      return events;
    } catch (_) {
      return [];
    }
  }

  /// Retourne les prochains événements du calendrier principal (max 10).
  /// Retourne une liste vide si pas connecté Google ou erreur.
  static Future<List<CalendarEvent>> getUpcomingEvents({int maxResults = 10}) async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) return [];

    final now = DateTime.now().toUtc();
    final timeMin = now.toIso8601String();

    final uri = Uri.parse(
      '$_base/calendars/primary/events'
      '?timeMin=$timeMin'
      '&maxResults=$maxResults'
      '&singleEvents=true'
      '&orderBy=startTime',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      final List<CalendarEvent> events = [];

      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final summary = itemMap['summary'] as String? ?? 'Sans titre';
        final start = itemMap['start'] as Map<String, dynamic>?;
        if (start == null) continue;

        DateTime startDt;
        bool isAllDay = false;
        if (start.containsKey('dateTime')) {
          startDt = DateTime.parse(start['dateTime'] as String);
        } else if (start.containsKey('date')) {
          isAllDay = true;
          startDt = DateTime.parse(start['date'] as String);
        } else {
          continue;
        }

        events.add(CalendarEvent(
          summary: summary,
          start: startDt,
          isAllDay: isAllDay,
        ),);
      }

      return events;
    } catch (_) {
      return [];
    }
  }

  static Future<String?> _getAccessToken() async {
    if (GoogleCalendarDesktopAuth.isNeeded) {
      return GoogleCalendarDesktopAuth.getAccessToken();
    }
    final creds = await OffiboxGoogleSignIn.signInSilently();
    return creds?.accessToken;
  }

  /// Indique si l'utilisateur a une session Google (avec scope agenda).
  static Future<bool> hasGoogleCalendarAccess() async {
    if (GoogleCalendarDesktopAuth.isNeeded) {
      final token = await GoogleCalendarDesktopAuth.getAccessToken();
      return token != null && token.isNotEmpty;
    }
    final creds = await OffiboxGoogleSignIn.signInSilently();
    return creds != null && creds.accessToken.isNotEmpty;
  }

  /// Lance la connexion OAuth pour l'agenda (Windows/Desktop uniquement).
  /// Retourne true si la connexion a réussi.
  static Future<bool> signInForDesktop() async {
    if (!GoogleCalendarDesktopAuth.isNeeded) return false;
    final token = await GoogleCalendarDesktopAuth.signIn();
    return token != null && token.isNotEmpty;
  }
}
