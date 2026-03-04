// Script d'extraction catalogue Santralia : PDF > page 4 -> CSV (Code, Nom produit, URL labo).
// Executer avec : flutter run -t lib/main_santralia_extract.dart

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:offibox/firebase_options.dart';
import 'package:offibox/services/firebase_storage_list_service.dart';
import 'package:offibox/services/santralia_catalogue_extractor.dart';

const String kStoragePrefix = 'SANTRALIA-CATALOGUE 2025';
const String kPdfPath =
    'SANTRALIA-CATALOGUE 2025/CATALOGUE Santralia avril 2025 (1).pdf';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const _SantraliaExtractApp());
}

class _SantraliaExtractApp extends StatefulWidget {
  const _SantraliaExtractApp();

  @override
  State<_SantraliaExtractApp> createState() => _SantraliaExtractAppState();
}

class _SantraliaExtractAppState extends State<_SantraliaExtractApp> {
  String _status = 'Initialisation...';
  String? _error;
  String? _csvPath;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _status = 'Verification connexion...';
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Vous n’êtes pas connecté. Lancez l’application Offibox '
              'principale, connectez-vous avec un compte autorisé, puis relancez '
              'cet export (ou utilisez l’export depuis le menu de l’app).';
          _status = 'Erreur';
        });
        return;
      }
      setState(() => _status = 'Recuperation URL du PDF...');
      final pdfRef = FirebaseStorage.instance.ref(kPdfPath);
      final pdfUrl = await pdfRef.getDownloadURL();

      setState(() => _status = 'Telechargement du PDF...');
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('PDF: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      setState(() => _status = 'Extraction des codes et libelles (pages >= 5)...');
      final rows = await SantraliaCatalogueExtractor.extractFromPdfBytes(bytes);

      setState(() => _status = 'Liste des fichiers du dossier Storage...');
      final files = await FirebaseStorageListService.listDownloadUrls(
        prefix: kStoragePrefix,
      );
      final urlByCode = <String, String>{};
      for (final f in files) {
        final name = f.name;
        for (final code in _extractCodesFromString(name)) {
          urlByCode[code] = f.url;
        }
      }
      final pdfFiles = files
          .where((e) => e.name.toLowerCase().contains('.pdf'))
          .map((e) => e.url)
          .toList();
      final fallbackUrl = pdfFiles.isEmpty ? pdfUrl : pdfFiles.first;

      setState(() => _status = 'Ecriture du CSV...');
      final dir = await getApplicationDocumentsDirectory();
      final csvFile = File('${dir.path}/santralia_catalogue_export.csv');
      await _writeCsv(csvFile, rows, urlByCode, fallbackUrl);

      setState(() {
        _status = 'Termine. ${rows.length} lignes.';
        _csvPath = csvFile.path;
        _done = true;
      });
      debugPrint('CSV ecrit : ${csvFile.path}');
    } catch (e, st) {
      final msg = '$e';
      final isUnauthorized = msg.contains('unauthorized') || msg.contains('not authorized');
      setState(() {
        _error = isUnauthorized
            ? 'Accès refusé (Firebase Storage). Vérifiez que :\n'
              '• Vous êtes bien connecté avec un compte autorisé.\n'
              '• Les règles Storage autorisent la lecture sur le chemin '
              'SANTRALIA-CATALOGUE 2025 pour les utilisateurs authentifiés.'
            : msg;
        _status = 'Erreur';
      });
      debugPrint('$e\n$st');
    }
  }

  Iterable<String> _extractCodesFromString(String s) {
    final codes = <String>{};
    final m13 = RegExp(r'\b\d{13}\b');
    final m7 = RegExp(r'\b\d{7}\b');
    for (final m in m13.allMatches(s)) {
      codes.add(m.group(0)!);
    }
    for (final m in m7.allMatches(s)) {
      codes.add(m.group(0)!);
    }
    return codes;
  }

  Future<void> _writeCsv(
    File file,
    List<({String code, String libelle})> rows,
    Map<String, String> urlByCode,
    String defaultUrl,
  ) async {
    const sep = ';';
    String escape(String cell) {
      if (cell.contains(sep) || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }
    final sb = StringBuffer();
    sb.writeln('Code${sep}Nom du produit${sep}URL du laboratoire');
    for (final r in rows) {
      final url = urlByCode[r.code] ?? defaultUrl;
      sb.writeln('${escape(r.code)}$sep${escape(r.libelle)}$sep${escape(url)}');
    }
    await file.writeAsString(sb.toString(), flush: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Export catalogue Santralia -> CSV'),
          actions: [
            if (_done)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _done = false;
                    _csvPath = null;
                  });
                  _run();
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
              if (_csvPath != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Fichier CSV genere :',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _csvPath!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
