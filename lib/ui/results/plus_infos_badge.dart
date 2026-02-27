import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/utils/normalize.dart';

/// Affiche la composition : "Composition :" puis à la ligne chaque composant (substance, dosage).
/// Déduplique les lignes quand une substance est contenue dans une autre (ex. DARIDOREXANT vs CHLORHYDRATE DE DARIDOREXANT).
/// Format affiché : "SUBSTANCE, X mg pour un comprimé".
class CompositionLinesForPlusInfos extends StatelessWidget {
  const CompositionLinesForPlusInfos({super.key, required this.compositionLine});

  final String compositionLine;

  static const TextStyle _style = TextStyle(
    fontSize: 13,
    fontFamily: 'Spinnaker',
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Retourne la substance (col D) : texte avant le premier " : ".
  static String _substanceOf(String part) {
    final idx = part.indexOf(' : ');
    if (idx <= 0) return part.trim();
    return part.substring(0, idx).trim();
  }

  /// True si [substanceShort] est une forme courte contenue dans [substanceLong] (même mot en fin ou mot entier).
  static bool _substanceContainedIn(String substanceShort, String substanceLong) {
    if (substanceShort.isEmpty || substanceLong.isEmpty) return false;
    if (substanceShort.length >= substanceLong.length) return false;
    final short = substanceShort.trim().toUpperCase();
    final long = substanceLong.trim().toUpperCase();
    if (short == long) return false;
    return long.contains(short) &&
        (long.endsWith(short) || long.contains(' $short ') || long.startsWith('$short '));
  }

  /// Enlève les doublons : garde la ligne dont la substance est la plus complète (ex. CHLORHYDRATE DE DARIDOREXANT), supprime la forme courte (DARIDOREXANT).
  static List<String> _deduplicateParts(List<String> parts) {
    if (parts.length <= 1) return parts;
    final kept = <String>[];
    for (final p in parts) {
      final substance = _substanceOf(p);
      final isRedundant = parts.any((other) {
        if (other == p) return false;
        final otherSub = _substanceOf(other);
        return _substanceContainedIn(substance, otherSub);
      });
      if (!isRedundant) kept.add(p);
    }
    return kept;
  }

  /// Reformate une partie "SUBSTANCE : DOSAGE : pour F" en "SUBSTANCE, DOSAGE" (sans "pour un comprimé" si affiché une fois en bas).
  static String _formatPart(String part, {bool stripPourUnComprime = false}) {
    String s = part.trim();
    if (stripPourUnComprime) {
      s = s.replaceFirst(RegExp(r'\s+pour un comprimé\s*$', caseSensitive: false), '').trim();
    }
    final idx = s.indexOf(' : ');
    if (idx <= 0) return s;
    final substance = s.substring(0, idx).trim();
    String rest = s.substring(idx + 3).replaceAll(RegExp(r'\s*:\s*$'), '').trim();
    if (rest.isEmpty) return substance;
    return '$substance, $rest';
  }

  @override
  Widget build(BuildContext context) {
    final rawParts = compositionLine.split(RegExp(r'\s*;\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (rawParts.isEmpty) return const SizedBox.shrink();
    final parts = _deduplicateParts(rawParts);
    if (parts.isEmpty) return const SizedBox.shrink();
    const String pourUnComprime = 'pour un comprimé';
    final bool allHavePourUnComprime = parts.every((p) => p.toLowerCase().contains(pourUnComprime));
    final displayParts = parts.map((p) => _formatPart(p, stripPourUnComprime: allHavePourUnComprime)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: _style.copyWith(color: Colors.black),
            children: [
              const TextSpan(text: '• '),
              TextSpan(
                text: 'Composition :',
                style: _style.copyWith(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
        ...displayParts.map((p) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('– $p', style: _style),
        )),
        if (allHavePourUnComprime && displayParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(pourUnComprime, style: _style),
          ),
      ],
    );
  }
}

/// Badge "plus d'infos" : au clic ouvre une fenêtre avec composition (ligne 1), listes (ligne 2), taux (ligne 3), puis statuts CIS.
/// Utilisé en ligne 1 (sources autres que BDM) et en ligne 2 (BDM uniquement, après les autres badges).
class PlusInfosBadge extends StatelessWidget {
  const PlusInfosBadge({
    super.key,
    required this.statuts,
    this.tauxRemboursement,
    this.compositionLine,
    this.listes = const [],
    required this.isDisabled,
  });

  final List<String> statuts;
  final String? tauxRemboursement;
  final String? compositionLine;
  final List<String> listes;
  final bool isDisabled;

  static const Color _teal = Color(0xFF5A9094);

  void _showStatutsDialog(BuildContext context) {
    if (isDisabled) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius)),
        title: const Text(
          'Plus d\'infos',
          style: TextStyle(fontFamily: 'Spinnaker', fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compositionLine != null && compositionLine!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CompositionLinesForPlusInfos(compositionLine: compositionLine!.trim()),
                ),
              if (listes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    listes.join(', '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Spinnaker',
                      height: 1.35,
                    ),
                  ),
                ),
              // Taux de remboursement (CIS_CIP_bdpm.txt colonne I) : affiché uniquement si la cellule a une valeur.
              if (tauxRemboursement != null && tauxRemboursement!.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Spinnaker',
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: '• '),
                        TextSpan(
                          text: 'Taux de remboursement :',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Spinnaker',
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.black,
                          ),
                        ),
                        TextSpan(text: ' ${tauxRemboursement!.trim()}'),
                      ],
                    ),
                  ),
                ),
              ],
              if (statuts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Spinnaker',
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: '• '),
                        TextSpan(
                          text: 'Statut :',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Spinnaker',
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...statuts.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '– ${normalizeText(s)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Spinnaker',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStatutsDialog(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _teal.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 11, color: _teal),
              const SizedBox(width: 5),
              Text(
                'plus d\'infos',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Spinnaker',
                  fontWeight: FontWeight.w700,
                  color: isDisabled ? Colors.grey : _teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
