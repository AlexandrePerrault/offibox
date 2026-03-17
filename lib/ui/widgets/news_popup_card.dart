import 'package:flutter/material.dart';
import 'package:offibox/services/news_popup_service.dart';
import 'package:offibox/utils/open_url.dart';

/// Carte popup actualité sous la barre (news.csv).
/// Affiche date JJ:mm/YYYY + titre, source en italique, badge « +d'infos » vers URL (col C).
class NewsPopupCard extends StatelessWidget {
  const NewsPopupCard({
    super.key,
    required this.entry,
    required this.onClose,
  });

  final NewsEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dateFormatted = formatNewsDateDisplay(entry.date);
    final displayLine = dateFormatted != null
        ? '$dateFormatted ${entry.title.trim()}'
        : entry.title.trim();
    final hasUrl = entry.url != null && entry.url!.trim().isNotEmpty;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 360,
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayLine,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUrl)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text("+d'infos"),
                      onPressed: () => openUrl(entry.url!, forceExternal: true),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            if (entry.source != null && entry.source!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.source!.trim(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (entry.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
