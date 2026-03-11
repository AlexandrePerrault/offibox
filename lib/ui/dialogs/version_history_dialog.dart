import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:offibox/constants/app_update_config.dart';
import 'package:offibox/constants/ui_constants.dart'; // OffiboxColors
import 'package:offibox/constants/offibox_window_ui.dart';

/// Une release GitHub (tag, titre, notes, date).
class _ReleaseItem {
  const _ReleaseItem({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
  });
  final String tagName;
  final String name;
  final String body;
  final String? publishedAt;
}

/// Dialogue « Historique des versions » : récupère les releases GitHub et affiche les notes.
/// Les textes affichés viennent du **corps (body)** de chaque release sur GitHub.
/// Modifier la description d’une release sur GitHub (Releases → Edit) met à jour
/// automatiquement l’onglet hamburger « Historique des versions » au prochain chargement.
/// Il n’y a pas de fichier .rm ou local à éditer pour ces textes.
class VersionHistoryDialog extends StatefulWidget {
  const VersionHistoryDialog({super.key});

  @override
  State<VersionHistoryDialog> createState() => _VersionHistoryDialogState();
}

class _VersionHistoryDialogState extends State<VersionHistoryDialog> {
  List<_ReleaseItem>? _releases;
  String? _error;
  bool _loading = true;

  static String get _releasesUrl =>
      'https://api.github.com/repos/${AppUpdateConfig.githubRepo}/releases';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http
          .get(Uri.parse(_releasesUrl))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les versions (${response.statusCode})';
        });
        return;
      }
      final list = jsonDecode(response.body) as List<dynamic>? ?? [];
      final items = <_ReleaseItem>[];
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final tag = map['tag_name'] as String? ?? '';
        final name = map['name'] as String? ?? tag;
        final body = map['body'] as String? ?? '';
        final published = map['published_at'] as String?;
        items.add(_ReleaseItem(
          tagName: tag,
          name: name.trim().isEmpty ? tag : name,
          body: body.trim(),
          publishedAt: published,
        ),);
      }
      if (mounted) {
        setState(() {
          _releases = items;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur réseau';
        });
      }
    }
  }

  /// Pour la v1.1.17 (ou body = texte par défaut release_notes.md), afficher « Aucun commentaire ».
  String _displayBody(_ReleaseItem r) {
    if (r.body.isEmpty) return '';
    if (r.tagName == 'v1.1.17') return 'Aucun commentaire';
    if (r.body.contains('Editez ce fichier') || r.body.contains('release_notes.md')) return 'Aucun commentaire';
    return r.body;
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Historique des versions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Spinnaker',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                      fontFamily: 'Spinnaker',
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _releases!.length,
                    itemBuilder: (context, i) {
                      final r = _releases![i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OffiboxColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: OffiboxColors.primary,
                                    ),
                                  ),
                                  child: Text(
                                    r.tagName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Spinnaker',
                                      color: OffiboxColors.primary,
                                    ),
                                  ),
                                ),
                                if (r.name != r.tagName) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Spinnaker',
                                        color: Colors.grey.shade800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (r.publishedAt != null &&
                                    r.publishedAt!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(r.publishedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Spinnaker',
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_displayBody(r).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _displayBody(r),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Spinnaker',
                                  color: Colors.grey.shade800,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
