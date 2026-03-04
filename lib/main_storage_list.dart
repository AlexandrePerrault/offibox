// Point d'entrée one-shot : liste les fichiers Storage et affiche leurs URL.
// Exécuter avec : flutter run -t lib/main_storage_list.dart
// (ou depuis un appareil/émulateur : l'app se lance, imprime les URL dans la console puis reste ouverte)

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:offibox/firebase_options.dart';
import 'package:offibox/services/firebase_storage_list_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const _StorageListApp());
}

class _StorageListApp extends StatefulWidget {
  const _StorageListApp();

  @override
  State<_StorageListApp> createState() => _StorageListAppState();
}

class _StorageListAppState extends State<_StorageListApp> {
  List<({String name, String url})> _urls = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _urls = [];
    });
    try {
      final list = await FirebaseStorageListService.listDownloadUrls(
        prefix: FirebaseStorageListService.defaultPrefix,
      );
      setState(() {
        _urls = list;
        _loading = false;
      });
      // Aussi imprimer en console pour copier/coller
      for (final e in list) {
        debugPrint('${e.name}\t${e.url}');
      }
      debugPrint('--- Total: ${list.length} URL(s) ---');
    } catch (e, st) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
      debugPrint('Erreur: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('URLs Storage – SANTRALIA-CATALOGUE 2025'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _urls.length,
                    itemBuilder: (context, i) {
                      final e = _urls[i];
                      return ListTile(
                        title: Text(
                          e.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: SelectableText(
                          e.url,
                          style: const TextStyle(fontSize: 11),
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
      ),
    );
  }
}
