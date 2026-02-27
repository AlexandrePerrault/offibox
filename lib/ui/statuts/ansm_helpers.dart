import 'package:flutter/material.dart';
import 'package:offibox/utils/date_formatters.dart';

/// =======================================================
/// 🟢🟠🔴 HELPERS STATUT ANSM (FUSIONNÉ)
/// =======================================================

Color ansmColor(String statut) {
  final s = statut.toLowerCase();
  if (s.contains('rupture')) return Colors.red;
  if (s.contains('tension')) return Colors.orange;
  return Colors.green;
}

String ansmEmoji(String statut) {
  final s = statut.toLowerCase();
  if (s.contains('rupture')) return '🔴';
  if (s.contains('tension')) return '🟠';
  return '🟢';
}

/// Libellé court pour le badge (Tension, Rupture, Remis à disposition).
String ansmLabel(String statut) {
  final s = statut.toLowerCase();
  if (s.contains('rupture')) return 'Rupture';
  if (s.contains('tension')) return 'Tension d\'approvisionnement';
  return 'Remis à disposition';
}

/// Cache par CIP (inchangé)
final Map<String, List<String>> ansmStatutCache = {};

/// =======================================================
/// 📌 WIDGET INLINE (ligne 2)
/// =======================================================
Widget ansmInlineStatus({
  required String statut,
  required String date,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ansmColor(statut).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ansmColor(statut)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ansmEmoji(statut), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'statut ANSM : ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ansmColor(statut),
                ),
              ),
              Text(
                ansmLabel(statut),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ansmColor(statut),
                ),
              ),
            ],
          ),
          if (date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(
                '- MAJ = ${formatToFrDate(date)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
