import 'package:flutter/material.dart';
import 'package:offibox/services/cahier_liaison_service.dart';

/// Cahier de liaison partagé entre tous les postes de la même officine (même pharmacyName).
/// Données en temps réel via Firestore.
class CahierLiaisonScreen extends StatefulWidget {
  const CahierLiaisonScreen({super.key});

  @override
  State<CahierLiaisonScreen> createState() => _CahierLiaisonScreenState();
}

class _CahierLiaisonScreenState extends State<CahierLiaisonScreen> {
  String? _groupId;
  String? _error;
  bool _loading = true;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  static const Color _teal = Color(0xFF5A9094);

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await CahierLiaisonService.instance.getGroupIdForCurrentUser();
      if (!mounted) return;
      setState(() {
        _groupId = id;
        _loading = false;
        if (id == null || id.isEmpty) {
          _error = 'Renseignez le nom de votre pharmacie dans votre profil pour partager le cahier de liaison avec votre équipe.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger le cahier. Réessayez.';
      });
    }
  }

  Future<void> _sendEntry() async {
    final groupId = _groupId;
    final text = _textController.text.trim();
    if (groupId == null || groupId.isEmpty || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await CahierLiaisonService.instance.addEntry(groupId: groupId, text: text);
      if (!mounted) return;
      _textController.clear();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envoi impossible. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F0F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F0F1),
        appBar: AppBar(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          title: const Text('Cahier de liaison'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final groupId = _groupId!;
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F1),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('Cahier de liaison'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zone de saisie
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Écrire un message pour l\'équipe…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _teal),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendEntry(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _sending
                        ? null
                        : () => _sendEntry(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 20),
                    label: Text(_sending ? 'Envoi…' : 'Envoyer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Liste des entrées (temps réel)
          Expanded(
            child: StreamBuilder<List<CahierEntry>>(
              stream: CahierLiaisonService.instance.streamEntries(groupId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de chargement',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun message pour l\'instant.\nAjoutez le premier pour votre équipe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return _EntryCard(entry: e);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final CahierEntry entry;

  static const Color _teal = Color(0xFF5A9094);

  @override
  Widget build(BuildContext context) {
    final dateStr = '${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year}';
    final timeStr = '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _teal.withValues(alpha: 0.2),
                  radius: 18,
                  child: Text(
                    entry.authorName.isNotEmpty ? entry.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _teal, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3F4346),
                        ),
                      ),
                      Text(
                        '$dateStr à $timeStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              entry.text,
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
