import 'package:flutter/material.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/utils/open_url.dart';

/// Page plein écran pour un document (PDF, Word, XLS, vidéo) avec fondu et croix pour fermer.
class FullscreenDocumentPage extends StatefulWidget {
  const FullscreenDocumentPage({
    super.key,
    required this.child,
    required this.onClose,
  });

  final Widget child;
  final VoidCallback onClose;

  @override
  State<FullscreenDocumentPage> createState() => _FullscreenDocumentPageState();
}

class _FullscreenDocumentPageState extends State<FullscreenDocumentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _opacity,
            child: widget.child,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 28, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Réduit une URL pour affichage (domaine + dernier segment ou chemin tronqué).
String shortUrlForDisplay(String url, {int maxLength = 50}) {
  if (url.isEmpty) return '';
  try {
    final uri = Uri.parse(url);
    final host = uri.host;
    final path = uri.path;
    if (path.isEmpty || path == '/') return host;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final last = segments.isEmpty ? '' : segments.last;
    if (last.isEmpty) return host;
    final s = '$host/${segments.length > 1 ? '…/' : ''}$last';
    return s.length <= maxLength ? s : '${s.substring(0, maxLength - 1)}…';
  } catch (_) {
    return url.length <= maxLength ? url : '${url.substring(0, maxLength - 1)}…';
  }
}

/// Chip "Source : [label]" pour la barre document. Si [url] est fourni, clic ouvre l'URL.
/// [textColor] : si la barre a un fond blanc, passer Colors.black87 pour la lisibilité.
Widget documentViewerSourceLabel({
  required String label,
  String? url,
  Color? textColor,
}) {
  final text = 'Source : $label';
  final style = TextStyle(
    color: textColor ?? Colors.white70,
    fontSize: 12,
    fontFamily: 'Spinnaker',
    fontStyle: FontStyle.italic,
  );
  final child = Text(text, style: style, overflow: TextOverflow.ellipsis, maxLines: 1);
  if (url != null && url.isNotEmpty) {
    return Tooltip(
      message: url,
      child: InkWell(
        onTap: () => openUrl(url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: child,
        ),
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: child,
  );
}

/// Couleur de fond par défaut de la barre document (teal).
const Color _defaultToolbarBackground = Color(0xFF5A9094);

/// Barre d'outils commune pour les panneaux PDF, Word, XLS, Web.
/// Éléments : Imprimer, Télécharger, Élargir la fenêtre, Rechercher (loupe), Source, fermer.
class DocumentViewerToolbar extends StatelessWidget {
  const DocumentViewerToolbar({
    super.key,
    this.onDownload,
    required this.onExpandFullscreen,
    required this.onClose,
    this.onPrint,
    this.onSearchTap,
    this.searchExpanded = false,
    this.searchBarContent,
    this.searchResultWidget,
    this.sourceWidget,
    this.trailingActionWidget,
    this.barHeight = 52,
    this.downloadLabel = 'Télécharger ce fichier',
    this.downloadTooltip = 'Télécharger ce fichier',
    this.downloadIcon = Icons.download,
    this.backgroundColor,
  });

  /// Si non null, affiche le pill d'action "Télécharger..." (ou custom via [downloadLabel]).
  final VoidCallback? onDownload;
  final VoidCallback onExpandFullscreen;
  final VoidCallback onClose;

  /// Si non null, affiche le pill "Imprimer".
  final VoidCallback? onPrint;
  /// Si non null, affiche le pill "Rechercher..." ; au clic appelle [onSearchTap].
  final VoidCallback? onSearchTap;
  /// Quand true, la zone [searchBarContent] est affichée (élargie jusqu'à la droite) avec fondu.
  final bool searchExpanded;
  /// Contenu de la barre de recherche (champ + bouton) affiché quand [searchExpanded] est true.
  final Widget? searchBarContent;
  /// Widget optionnel après la barre de recherche (ex. Résultat X/Y, prev/next pour PDF).
  final Widget? searchResultWidget;
  /// Widget optionnel à droite de la barre de recherche (ex. "Source : ..." pour PDF/Word/XLS).
  final Widget? sourceWidget;
  /// Widget optionnel avant le bouton fermer (ex. icône panier pour catalogues CERP).
  final Widget? trailingActionWidget;

  final double barHeight;
  final String downloadLabel;
  final String downloadTooltip;
  final IconData downloadIcon;
  /// Fond de la barre ; par défaut teal. Passer Colors.white pour un panneau tout blanc.
  final Color? backgroundColor;

  Color get _barColor => backgroundColor ?? _defaultToolbarBackground;
  bool get _isLightBar => _barColor.computeLuminance() > 0.5;

  @override
  Widget build(BuildContext context) {
    final hasSearch = onSearchTap != null;
    final hasDownload = onDownload != null;

    return Material(
      color: _barColor,
      child: SizedBox(
        height: barHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            if (onPrint != null) ...[
              HoverPillButton(
                icon: Icons.print,
                label: 'Imprimer',
                tooltip: 'Imprimer',
                onTap: onPrint!,
                height: 34,
              ),
              const SizedBox(width: 10),
            ],
            if (hasDownload) ...[
              HoverPillButton(
                icon: downloadIcon,
                label: downloadLabel,
                tooltip: downloadTooltip,
                onTap: onDownload!,
                height: 34,
              ),
              const SizedBox(width: 10),
            ],
            HoverPillButton(
              icon: Icons.open_in_full,
              label: 'Élargir la fenêtre',
              tooltip: 'Élargir la fenêtre',
              onTap: onExpandFullscreen,
              height: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSearch) ...[
                    HoverPillButton(
                      icon: Icons.search,
                      label: 'Rechercher...',
                      tooltip: 'Rechercher dans ce fichier',
                      onTap: onSearchTap!,
                      height: 34,
                    ),
                    const SizedBox(width: 12),
                    if (searchExpanded && searchBarContent != null)
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: searchBarContent,
                        ),
                      ),
                    if (searchExpanded && searchResultWidget != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: searchResultWidget!,
                        ),
                      ),
                    ],
                  ],
                  if (sourceWidget != null) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: sourceWidget!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingActionWidget != null) ...[
              trailingActionWidget!,
              const SizedBox(width: 8),
            ],
            Material(
              color: _isLightBar ? _defaultToolbarBackground : _defaultToolbarBackground,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 22, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
