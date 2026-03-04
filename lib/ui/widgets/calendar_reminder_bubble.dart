import 'dart:async';

import 'package:flutter/material.dart';

import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/services/google_calendar_service.dart';

/// Clé unique pour un événement (pour savoir si on a déjà affiché ou fermé la bulle).
String _eventKey(CalendarEvent ev) =>
    '${ev.start.millisecondsSinceEpoch}_${ev.summary}';

/// Bulle affichée 30 minutes avant un RDV Google Calendar, avec croix pour fermer.
class CalendarReminderBubble extends StatefulWidget {
  const CalendarReminderBubble({
    super.key,
    required this.events,
    required this.topOffset,
    required this.leftOffset,
    this.barWidth,
  });

  final List<CalendarEvent> events;
  /// Offset vertical (top) pour placer la bulle devant la barre d'info.
  final double topOffset;
  final double leftOffset;
  final double? barWidth;

  @override
  State<CalendarReminderBubble> createState() => _CalendarReminderBubbleState();
}

class _CalendarReminderBubbleState extends State<CalendarReminderBubble> {
  Timer? _timer;
  Timer? _autoDismissTimer;
  final Set<String> _dismissedKeys = {};
  String? _shownKey;

  static const Duration _checkInterval = Duration(minutes: 1);
  static const Duration _windowBefore = Duration(minutes: 30);
  /// Fermeture automatique après ce délai si l'utilisateur ne ferme pas au X.
  static const Duration _autoDismissAfter = Duration(seconds: 30);

  CalendarEvent? _eventToShow() {
    final now = DateTime.now();
    final limit = now.add(_windowBefore);
    for (final ev in widget.events) {
      if (ev.start.isBefore(now)) continue;
      if (ev.start.isAfter(limit)) continue;
      final key = _eventKey(ev);
      if (_dismissedKeys.contains(key)) continue;
      return ev;
    }
    return null;
  }

  void _check() {
    if (!mounted) return;
    final toShow = _eventToShow();
    final key = toShow != null ? _eventKey(toShow) : null;
    if (key != _shownKey && toShow != null) {
      _shownKey = key;
      _autoDismissTimer?.cancel();
      _autoDismissTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showReminderDialog(toShow);
      });
    } else if (key != _shownKey) {
      setState(() => _shownKey = key);
    }
  }

  void _showReminderDialog(CalendarEvent ev) {
    final mins = ev.start.difference(DateTime.now()).inMinutes;
    final inMinLabel = mins <= 0
        ? 'maintenant'
        : mins == 1
            ? 'dans 1 min'
            : 'dans $mins min';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event_available, color: OffiboxColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('RDV $inMinLabel'),
          ],
        ),
        content: Text(
          '${ev.timeLabel} – ${ev.summary}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _dismiss(ev);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => _dismiss(ev));
  }

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  @override
  void didUpdateWidget(CalendarReminderBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _dismiss(CalendarEvent ev) {
    setState(() {
      _dismissedKeys.add(_eventKey(ev));
      _shownKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Le rappel 30 min est affiché en fenêtre (dialog) par _check() / _showReminderDialog, pas en bulle.
    return const SizedBox.shrink();
  }
}
