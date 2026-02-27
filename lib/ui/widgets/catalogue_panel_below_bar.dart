import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:offibox/ui/widgets/hover_pill_button.dart';

/// Fenêtre sous la barre quand un laboratoire avec catalogue (col. G) est sélectionné.
/// Deux choix en HoverPill : Télécharger PDF | Rechercher sur le catalogue (+15 % hauteur).
class CataloguePanelBelowBar extends StatelessWidget {
  const CataloguePanelBelowBar({
    super.key,
    required this.cataloguePdfUrl,
    required this.labName,
    required this.onDownloadPdf,
    required this.onSearchInCatalogue,
  });

  final String cataloguePdfUrl;
  final String labName;
  final VoidCallback onDownloadPdf;
  final VoidCallback onSearchInCatalogue;

  /// Hauteur des pills : 28 * 1.15 * 1.10 ≈ 35
  static const double _pillHeight = 35.2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12, right: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: HoverPillButton(
              expand: true,
              height: _pillHeight,
              label: 'Télécharger le catalogue',
              iconWidget: SvgPicture.asset(
                'assets/icons/pdf_red.svg',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              tooltip: 'Télécharger le catalogue (ouvre le PDF dans le navigateur)',
              onTap: onDownloadPdf,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HoverPillButton(
              expand: true,
              height: _pillHeight,
              maxLabelWidth: 220,
              label: 'Rechercher sur le catalogue',
              icon: Icons.search,
              tooltip: 'Ouvrir le catalogue et rechercher',
              onTap: onSearchInCatalogue,
            ),
          ),
        ],
      ),
    );
  }
}
