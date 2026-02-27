import 'package:flutter/services.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';

/// Une option de copie (libellé + valeur à copier).
class CopyOption {
  const CopyOption({required this.label, required this.value});
  final String label;
  final String value;
}

/// Retourne les options de copie pour un résultat (CIP, CIS, etc.).
List<CopyOption> getCopyOptions(SearchResult result) {
  final options = <CopyOption>[];
  final cip = result.cip13?.replaceAll(RegExp(r'\D'), '').trim();
  if (cip != null && cip.isNotEmpty) {
    final label = result.source == SourceType.bdm
        ? 'CIP'
        : result.source == SourceType.dm
            ? 'EAN'
            : result.source == SourceType.veto
                ? 'GTIN'
                : 'Code';
    options.add(CopyOption(label: label, value: cip));
  }
  if (result.cis != null && result.cis!.trim().isNotEmpty) {
    options.add(CopyOption(label: 'CIS', value: result.cis!.trim()));
  }
  return options;
}

/// Copie une chaîne dans le presse-papier.
void copyToClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
}
