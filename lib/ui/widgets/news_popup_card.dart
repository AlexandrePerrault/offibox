import 'package:flutter/material.dart';
import 'package:offibox/services/news_popup_service.dart';

/// Carte popup actualité sous la barre (news.csv).
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
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            if (entry.body.isNotEmpty)
              Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
