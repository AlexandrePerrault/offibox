import 'package:flutter/material.dart';
import 'package:offibox/services/google_calendar_service.dart';

/// Une ligne compacte "Agenda : 14h Réunion, 16h RDV…" sous la barre de recherche.
class AgendaBar extends StatelessWidget {
  const AgendaBar({
    super.key,
    required this.events,
  });

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Text(
            'Agenda : ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontFamily: 'Spinnaker',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < events.length; i++) ...[
                    if (i > 0)
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'Spinnaker',
                        ),
                      ),
                    Text(
                      '${events[i].timeLabel} ${events[i].summary}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                        fontFamily: 'Spinnaker',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
