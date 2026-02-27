import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/utils/ansm_rappel_match.dart';
import 'package:offibox/utils/open_url.dart';

/// Ligne 3 : alerte rappel (pendant 7 jours) — message en rouge "Ce médicament a fait l'objet d'un rappel le [date]" + badge "+ d'infos" vers l'URL ANSM.
/// Affiché si le produit correspond au dernier rappel et que le rappel a moins de 7 jours.
class ResultLine4RappelAlert extends StatelessWidget {
  const ResultLine4RappelAlert({
    super.key,
    required this.item,
    this.ansmLastRappel,
    this.onOpenUrl,
  });

  final SearchResult item;
  final AnsmRappelItem? ansmLastRappel;
  final void Function(String url)? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    if (ansmLastRappel == null) return const SizedBox.shrink();
    final rappel = ansmLastRappel!;
    if (!isProductConcernedByLastRappel(item, rappel)) return const SizedBox.shrink();
    if (!isRappelRecent(rappel, maxDays: 7)) return const SizedBox.shrink();

    final url = rappel.url.trim();
    final dateStr = rappel.dateStr?.trim().isNotEmpty == true
        ? rappel.dateStr!
        : '';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              dateStr.isNotEmpty
                  ? "Ce médicament a fait l'objet d'un rappel le $dateStr"
                  : "Ce médicament a fait l'objet d'un rappel de lot",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
                fontFamily: 'Spinnaker',
              ),
            ),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Plus d\'infos sur le rappel (ANSM)',
              child: GestureDetector(
                onTap: () {
                  if (onOpenUrl != null) {
                    onOpenUrl!(url);
                  } else {
                    openUrl(url);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5A9094).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF5A9094).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: Color(0xFF5A9094)),
                      SizedBox(width: 4),
                      Text(
                        '+ d\'infos',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Spinnaker',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A9094),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
