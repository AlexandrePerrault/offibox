import 'package:flutter/material.dart';

class StatutsCipPanel extends StatelessWidget {
  final String label;
  final List<String> statuts;
  final ScrollController scrollController;

  const StatutsCipPanel({
    super.key,
    required this.label,
    required this.statuts,
    required this.scrollController,
  });

  Color _colorFor(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return Colors.red;
    if (s.contains('tension')) return Colors.orange;
    return Colors.green;
  }

  String _emojiFor(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return '🔴';
    if (s.contains('tension')) return '🟠';
    return '🟢';
  }

  String _labelFor(String statut) {
    final s = statut.toLowerCase();
    if (s.contains('rupture')) return 'RUPTURE';
    if (s.contains('tension')) return 'TENSION';
    return 'DISPONIBLE';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────
            // 🏷️ Titre
            // ─────────────────────────
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            // ─────────────────────────
            // 📋 Liste statuts
            // ─────────────────────────
            Expanded(
              child: statuts.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune information de statut disponible',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: statuts.length,
                      itemBuilder: (context, index) {
                        final statut = statuts[index];
                        final color = _colorFor(statut);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _emojiFor(statut),
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _labelFor(statut),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        statut,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
