import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/ui/widgets/below_bar_close_hoverpill.dart';
import 'package:offibox/utils/open_url.dart';

class MultiUrlBadgesPanelBelowBar extends StatelessWidget {
  const MultiUrlBadgesPanelBelowBar({
    super.key,
    required this.result,
    required this.barWidth,
    required this.onClose,
  });

  final SearchResult result;
  final double barWidth;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cipDigits = result.cip13?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
    final bdpmCip13 =
        cipDigits.length == 13 && cipDigits.startsWith('34009') ? cipDigits : '';
    final comp = (result.groupLabel ?? '').trim();

    final badges = <({String name, String url})>[
      if ((result.badge1Name ?? '').trim().isNotEmpty &&
          (result.badge1Url ?? '').trim().isNotEmpty)
        (name: result.badge1Name!.trim(), url: result.badge1Url!.trim()),
      if ((result.badge2Name ?? '').trim().isNotEmpty &&
          (result.badge2Url ?? '').trim().isNotEmpty)
        (name: result.badge2Name!.trim(), url: result.badge2Url!.trim()),
      if ((result.badge3Name ?? '').trim().isNotEmpty &&
          (result.badge3Url ?? '').trim().isNotEmpty)
        (name: result.badge3Name!.trim(), url: result.badge3Url!.trim()),
      if ((result.badge4Name ?? '').trim().isNotEmpty &&
          (result.badge4Url ?? '').trim().isNotEmpty)
        (name: result.badge4Name!.trim(), url: result.badge4Url!.trim()),
      if ((result.badge5Name ?? '').trim().isNotEmpty &&
          (result.badge5Url ?? '').trim().isNotEmpty)
        (name: result.badge5Name!.trim(), url: result.badge5Url!.trim()),
      if ((result.badge6Name ?? '').trim().isNotEmpty &&
          (result.badge6Url ?? '').trim().isNotEmpty)
        (name: result.badge6Name!.trim(), url: result.badge6Url!.trim()),
    ];
    final principal = (result.url ?? '').trim();
    if (principal.startsWith('http://') || principal.startsWith('https://')) {
      final urls = badges.map((b) => b.url).toSet();
      if (!urls.contains(principal)) {
        badges.insert(0, (name: 'Site principal', url: principal));
      }
    }

    return Container(
      width: barWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              BelowBarCloseHoverPill(onClose: onClose),
            ],
          ),
          if (result.source == SourceType.weleda && bdpmCip13.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              'CIP13 $bdpmCip13',
              style: const TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OffiboxColors.primary,
              ),
            ),
          ],
          if (result.source == SourceType.weleda && comp.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Composition',
              style: TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              comp,
              style: TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 11,
                height: 1.25,
                color: Colors.grey.shade800,
              ),
            ),
          ],
          if (badges.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Aucun lien disponible.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges
                  .map(
                    (b) => OutlinedButton.icon(
                      onPressed: () => openUrl(b.url),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(b.name),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
