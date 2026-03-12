// ignore_for_file: avoid_print
//
// Met à jour lib/generated/build_info.dart avec la date de la version
// affichée dans « À propos » et dans la barre (kVersionDate).
//
// La date est prise depuis le dernier commit Git du dépôt (format JJ/MM/AAAA),
// ce qui correspond à la date de la version publiée sur GitHub.
//
// Utilisation :
//   dart run scripts/update_build_info.dart
//
// Appelé automatiquement par build_msi.ps1 avant flutter build windows.

import 'dart:io';

const String _outPath = 'lib/generated/build_info.dart';

Future<String?> _getGitDate() async {
  try {
    final result = await Process.run(
      'git',
      ['log', '-1', '--format=%cs'],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      return null;
    }
    final raw = (result.stdout as String).trim();
    if (raw.isEmpty) return null;
    // %cs renvoie YYYY-MM-DD — on convertit en JJ/MM/AAAA.
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    return '$day/$month/$year';
  } catch (_) {
    return null;
  }
}

Future<String?> _readExistingDateIfAny() async {
  try {
    final file = File(_outPath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final regex = RegExp(r\"kVersionDate\\s*=\\s*'([^']+)'\\s*;\");
    final match = regex.firstMatch(content);
    if (match == null) return null;
    return match.group(1);
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  var date = await _getGitDate();
  if (date == null || date.isEmpty) {
    final existing = await _readExistingDateIfAny();
    if (existing != null && existing.isNotEmpty) {
      print(
          'build_info: git log a echoue, conservation de la date existante $existing');
      date = existing;
    } else {
      // Dernier recours : date fixe au format attendu.
      date = '01/01/2025';
      print(
          'build_info: git log indisponible et aucune valeur existante, utilisation de la date par defaut $date');
    }
  }

  final outFile = File(_outPath);
  final dir = outFile.parent;
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final content = '''
/// Date de version / mise à jour affichée (À propos, barre). Généré par scripts/update_build_info.dart.
const String kVersionDate = '$date';
''';
  await outFile.writeAsString(content.trimLeft(), flush: true);
  print('build_info: kVersionDate = $date');
}

