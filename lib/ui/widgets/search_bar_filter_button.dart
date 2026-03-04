import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/core/search_filter.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/search/mte_molecules.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/ui/widgets/offibox_tooltip.dart';

/// Bouton circulaire avec survol : couleur offibox light par défaut, teal au survol.
/// Pas d'animation pour éviter le lag.
class _HoverCircleButton extends StatefulWidget {
  const _HoverCircleButton({
    required this.defaultColor,
    required this.hoverColor,
    required this.defaultIconColor,
    required this.hoverIconColor,
    required this.child,
  });

  final Color defaultColor;
  final Color hoverColor;
  final Color defaultIconColor;
  final Color hoverIconColor;
  final Widget child;

  @override
  State<_HoverCircleButton> createState() => _HoverCircleButtonState();
}

class _HoverCircleButtonState extends State<_HoverCircleButton> {
  static const Color _offiboxTeal = Color(0xFF5A9094);
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovering ? widget.hoverColor : widget.defaultColor;
    final iconColor = _hovering ? widget.hoverIconColor : widget.defaultIconColor;
    const size = OffiboxWindowUI.menuButtonSize;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: _offiboxTeal, width: 1.2),
          ),
          child: Center(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton filtre à gauche de la loupe — même dimensions et liseré que le menu hamburger.
/// Si [menuMinTopY] est fourni, le panneau s'ouvre toujours sous la barre (position forcée).
class SearchBarFilterButton extends StatefulWidget {
  const SearchBarFilterButton({super.key, this.menuMinTopY});

  final double? menuMinTopY;

  @override
  State<SearchBarFilterButton> createState() => _SearchBarFilterButtonState();
}

class _SearchBarFilterButtonState extends State<SearchBarFilterButton> {
  static const Color _offiboxTeal = Color(0xFF5A9094);
  static const double _menuWidth = 260;

  Future<void> _openFilterUnderBar(BuildContext context) async {
    final size = MediaQuery.sizeOf(context);
    const topPadding = 8.0;
    final top = widget.menuMinTopY! + topPadding;
    final maxHeight = (size.height - top - 16).clamp(200.0, double.infinity);
    await showMenu<void>(
      context: context,
      positionBuilder: (_, __) => RelativeRect.fromLTRB(24, top, size.width - 24 - _menuWidth, 0),
      constraints: BoxConstraints(maxWidth: _menuWidth, maxHeight: maxHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
      ),
      color: Colors.white,
      elevation: 8,
      items: [
        const PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 260,
            child: _FilterPanel(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = _HoverCircleButton(
      defaultColor: OffiboxColors.tealLight,
      hoverColor: _offiboxTeal,
      defaultIconColor: _offiboxTeal,
      hoverIconColor: Colors.white,
      child: Image.asset(
        'assets/icons/filtre.png',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
      ),
    );
    if (widget.menuMinTopY != null) {
      return OffiboxTooltip(
        message: 'filtrer les résultats',
        child: GestureDetector(
          onTap: () => _openFilterUnderBar(context),
          child: button,
        ),
      );
    }
    return OffiboxTooltip(
      message: 'filtrer les résultats',
      child: PopupMenuButton<void>(
        offset: const Offset(-260, 8),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
        ),
        color: Colors.white,
        elevation: 8,
        padding: EdgeInsets.zero,
        child: button,
        itemBuilder: (context) => [
          const PopupMenuItem<void>(
            enabled: false,
            child: SizedBox(
              width: 260,
              child: _FilterPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de filtre avec survol offibox.
/// Clic sur la case → coche/décoche (sans fermer). Bouton "+" à droite → afficher la sélection (ferme et applique).
class _FilterListTile extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  /// Si non null, affiche un bouton "+" à droite avec tooltip "afficher la sélection".
  final VoidCallback? onShowSelection;
  /// Widget optionnel entre le titre et le bouton + (ex. chevron V).
  final Widget? trailing;

  const _FilterListTile({
    required this.value,
    required this.onChanged,
    required this.title,
    this.onShowSelection,
    this.trailing,
  });

  @override
  State<_FilterListTile> createState() => _FilterListTileState();
}

class _FilterListTileState extends State<_FilterListTile> {
  static const Color _offiboxTeal = Color(0xFF5A9094);
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovering ? _offiboxTeal : OffiboxColors.tealLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            children: [
              Checkbox(
                value: widget.value,
                onChanged: widget.onChanged,
                activeColor: OffiboxColors.primary,
                checkColor: Colors.white,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Spinnaker',
                        color: _hovering ? Colors.white : _offiboxTeal,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
              if (widget.onShowSelection != null)
                HoverPillButton(
                  icon: Icons.add,
                  label: '',
                  tooltip: 'Afficher la sélection',
                  onTap: widget.onShowSelection!,
                  height: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel();

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

/// Laboratoires génériques à afficher dans le sous-menu (ordre fixe).
const List<String> _genericLaboratoryNames = [
  'Arrow', 'Biogaran', 'Crister', 'EG', 'Evolugen', 'HCS', 'Sandoz', 'Teva', 'Viatris', 'Zydus', 'Zentiva',
];

class _FilterPanelState extends State<_FilterPanel> {
  bool _bdmExpanded = false;
  bool _generiquesLabExpanded = false;

  static const List<SourceType> _filterableSources = [
    SourceType.bdm,
    SourceType.lpp,
    SourceType.dm,
    SourceType.veto,
    SourceType.amc,
    SourceType.pharmacovigilance,
    SourceType.centresAntiPoison,
    SourceType.chu,
    SourceType.keyword,
    SourceType.siteWeb,
  ];

  /// Une ligne du panneau = soit une source, soit le groupe « Annuaires » (pharmacovigilance + centres anti poison + CHU).
  static List<({bool isAnnuaire, SourceType? source})> _displayRows() {
    const annuaire = SearchFilterNotifier.annuaireSources;
    final rows = <({bool isAnnuaire, SourceType? source})>[];
    var annuaireAdded = false;
    for (final s in _filterableSources) {
      if (annuaire.contains(s)) {
        if (!annuaireAdded) {
          rows.add((isAnnuaire: true, source: null));
          annuaireAdded = true;
        }
      } else {
        rows.add((isAnnuaire: false, source: s));
      }
    }
    return rows;
  }

  static const String _annuaireGroupLabel = 'Annuaires';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Libellé commun (common span) quand il existe, sinon null.
  static String? _sourceCommonSpanLabel(SourceType s) {
    switch (s) {
      case SourceType.lpp:
        return 'LPP';
      case SourceType.dm:
        return 'DM';
      case SourceType.veto:
        return 'VETO';
      case SourceType.amc:
        return 'MUT';
      case SourceType.amo:
        return 'AMO';
      case SourceType.keyword:
        return 'Outils métier';
      case SourceType.codesActes:
        return 'Codes actes';
      case SourceType.siteWeb:
        return 'site internet';
      case SourceType.pharmacovigilance:
        return 'annuaire';
      case SourceType.centresAntiPoison:
        return 'centres anti poison';
      case SourceType.chu:
        return 'CHU';
      default:
        return null;
    }
  }

  static String _sourceLabel(SourceType s) {
    final spanLabel = _sourceCommonSpanLabel(s);
    if (spanLabel != null) return spanLabel;
    switch (s) {
      case SourceType.bdm:
        return 'Médicaments (BDM)';
      case SourceType.lpp:
        return 'LPP';
      case SourceType.dm:
        return 'Dispositifs médicaux';
      case SourceType.veto:
        return 'Vétérinaire';
      case SourceType.amc:
        return 'Mutuelles';
      case SourceType.amo:
        return 'AMO';
      case SourceType.pharmacovigilance:
        return 'Annuaires';
      case SourceType.centresAntiPoison:
        return 'Centres anti poison';
      case SourceType.chu:
        return 'CHU';
      case SourceType.keyword:
        return 'Mots-clés';
      case SourceType.siteWeb:
        return 'Sites web';
      default:
        return s.name;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Compte les résultats par source et par sous-catégorie BDM (sans bdmOnlySubFilters).
  static Map<SourceType, int> _countBySource(List<SearchResult> baseFiltered) {
    final map = <SourceType, int>{};
    for (final s in _filterableSources) {
      map[s] = baseFiltered.where((r) => r.source == s).length;
    }
    return map;
  }

  static Map<BdmSubFilter, int> _countBdmSub(
    List<SearchResult> baseFiltered, {
    Set<String>? genericCipSet,
  }) {
    final bdm = baseFiltered.where((r) => r.source == SourceType.bdm).toList();
    bool isGeneric(SearchResult r) {
      if (genericCipSet != null && genericCipSet.isNotEmpty) {
        return r.cip13 != null && genericCipSet.contains(r.cip13);
      }
      return r.isGeneric == true;
    }
    return {
      BdmSubFilter.generiques: bdm.where(isGeneric).length,
      BdmSubFilter.stupefiants: bdm.where((r) => r.isStupefiant == true || r.liste1 == true || r.liste2 == true).length,
      BdmSubFilter.mds: bdm.where((r) => r.isMds == true).length,
      BdmSubFilter.mte: bdm.where((r) => isMteMolecule(r)).length,
      BdmSubFilter.biosimilaires: bdm.where((r) => r.biosimilaireOf != null && r.biosimilaireOf!.isNotEmpty).length,
      BdmSubFilter.otc: bdm.where((r) => r.isOtc == true).length,
    };
  }

  /// Génériques : compte par laboratoire (libellé contient le nom du labo). Liste fixe _genericLaboratoryNames.
  static Map<String, int> _countGeneriquesByLaboratory(
    List<SearchResult> baseFiltered, {
    Set<String>? genericCipSet,
  }) {
    bool isGeneric(SearchResult r) {
      if (genericCipSet != null && genericCipSet.isNotEmpty) {
        return r.source == SourceType.bdm && r.cip13 != null && genericCipSet.contains(r.cip13);
      }
      return r.source == SourceType.bdm && r.isGeneric == true;
    }
    final generics = baseFiltered.where(isGeneric).toList();
    final map = <String, int>{};
    for (final labName in _genericLaboratoryNames) {
      final labUpper = labName.toUpperCase();
      map[labName] = generics.where((r) {
        final label = r.labelRaw.toUpperCase();
        return label.contains(labUpper);
      }).length;
    }
    return map;
  }

  static String _bdmSubLabel(BdmSubFilter sub) {
    switch (sub) {
      case BdmSubFilter.generiques:
        return 'Génériques';
      case BdmSubFilter.stupefiants:
        return 'Stupéfiants et assimilés';
      case BdmSubFilter.mds:
        return 'Médicaments d\'exception MDS';
      case BdmSubFilter.mte:
        return 'Médicaments à marge thérapeutique étroite - MTE';
      case BdmSubFilter.biosimilaires:
        return 'Biosimilaires';
      case BdmSubFilter.otc:
        return 'OTC / autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final filter = ref.watch(searchFilterProvider);
        final filterNotifier = ref.read(searchFilterProvider.notifier);
        final controller = ref.read(offiboxControllerProvider);

        final genericCipSet = controller.genericCipSet;
        final baseFilter = filter.copyWith(bdmOnlySubFilters: const {}, genericLaboratory: null);
        final baseFiltered = baseFilter.applyTo(
          List<SearchResult>.from(controller.allResults),
          genericCipSet: genericCipSet,
          cisArretCommercialisation: controller.cisArretCommercialisation,
        );
        final countBySource = _countBySource(baseFiltered);
        final countBdmSub = _countBdmSub(baseFiltered, genericCipSet: genericCipSet);
        final countByLab = _countGeneriquesByLaboratory(baseFiltered, genericCipSet: genericCipSet);

        final allDisplayRows = _displayRows();
        final filteredDisplayRows = _searchQuery.isEmpty
            ? allDisplayRows
            : allDisplayRows.where((row) {
                final label = row.isAnnuaire
                    ? _annuaireGroupLabel
                    : _sourceLabel(row.source!);
                return label.toLowerCase().contains(_searchQuery);
              }).toList();

        void showSelection() {
          Navigator.of(context).pop();
          controller.applyFilter(ref.read(searchFilterProvider));
        }

        void showFullListForSource(SourceType source) {
          Navigator.of(context).pop();
          controller.showFullListForSource(source);
        }

        void showFullListForBdmSub(BdmSubFilter sub, {String? lab}) {
          Navigator.of(context).pop();
          final f = ref.read(searchFilterProvider);
          final tempFilter = SearchFilter(
            disabledSources: f.disabledSources,
            hideNsfp: f.hideNsfp,
            hideHospitalOnly: f.hideHospitalOnly,
            bdmOnlySubFilters: {sub},
            genericLaboratory: lab,
          );
          controller.showFullListForFilter(tempFilter);
        }

        void onReset() {
          filterNotifier.reset();
          Navigator.of(context).pop();
          final q = controller.currentQuery;
          if (q.startsWith('Liste :')) {
            controller.clearResults();
          } else {
            controller.applyFilter(const SearchFilter());
          }
        }

        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            checkboxTheme: theme.checkboxTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontFamily: 'Spinnaker',
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: OffiboxColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontFamily: 'Spinnaker',
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.clear_all, size: 18, color: OffiboxColors.primary),
                  label: const Text(
                    'Réinitialiser les filtres',
                    style: TextStyle(fontFamily: 'Spinnaker', color: OffiboxColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                ...filteredDisplayRows.map((row) {
                  if (row.isAnnuaire) {
                    final enabled = filterNotifier.isAnnuaireGroupEnabled;
                    final count = SearchFilterNotifier.annuaireSources
                        .fold<int>(0, (sum, s) => sum + (countBySource[s] ?? 0));
                    final title =
                        '$_annuaireGroupLabel ($count résultat${count != 1 ? 's' : ''})';
                    return _FilterListTile(
                      value: enabled,
                      onChanged: (_) => filterNotifier.toggleAnnuaireGroup(),
                      title: title,
                      onShowSelection: () {
                        Navigator.of(context).pop();
                        final onlyAnnuaire = SearchFilter(
                          disabledSources: Set<SourceType>.from(_filterableSources)
                            ..removeAll(SearchFilterNotifier.annuaireSources),
                        );
                        controller.showFullListForFilter(onlyAnnuaire);
                      },
                    );
                  }
                  final source = row.source!;
                  final enabled = filter.isSourceEnabled(source);
                  final count = countBySource[source] ?? 0;
                  final title = '${_sourceLabel(source)} ($count résultat${count != 1 ? 's' : ''})';
                  if (source != SourceType.bdm) {
                    return _FilterListTile(
                      value: enabled,
                      onChanged: (v) => filterNotifier.toggleSourceDisabled(source),
                      title: title,
                      onShowSelection: () => showFullListForSource(source),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MedicamentsFilterRow(
                        enabled: enabled,
                        title: title,
                        expanded: _bdmExpanded,
                        onExpandTap: () => setState(() => _bdmExpanded = !_bdmExpanded),
                        onChanged: (v) {
                          filterNotifier.toggleSourceDisabled(source);
                          if (!(v ?? true)) filterNotifier.clearBdmSubFilters();
                        },
                      ),
                      if (enabled && _bdmExpanded) ...[
                        const SizedBox(height: 3),
                        ...BdmSubFilter.values.map((sub) {
                          final selected = filter.bdmOnlySubFilters.contains(sub);
                          final n = countBdmSub[sub] ?? 0;
                          final isGeneriques = sub == BdmSubFilter.generiques;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BdmSubFilterTile(
                                label: '${_bdmSubLabel(sub)} ($n résultat${n != 1 ? 's' : ''})',
                                selected: selected,
                                onTap: () => filterNotifier.toggleBdmSubFilter(sub),
                                onShowSelection: isGeneriques ? null : () => showFullListForBdmSub(sub),
                                trailing: isGeneriques
                                    ? OffiboxTooltip(
                                        message: _generiquesLabExpanded ? 'Masquer laboratoires' : 'Afficher laboratoires',
                                        child: IconButton(
                                          onPressed: () => setState(() => _generiquesLabExpanded = !_generiquesLabExpanded),
                                          icon: Icon(_generiquesLabExpanded ? Icons.remove : Icons.add, size: 18),
                                          color: OffiboxColors.primary,
                                          style: IconButton.styleFrom(
                                            padding: const EdgeInsets.all(2),
                                            minimumSize: const Size(24, 24),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              if (isGeneriques && _generiquesLabExpanded) ...[
                                const SizedBox(height: 3),
                                Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: _genericLaboratoryNames.map((lab) {
                                      final n = countByLab[lab] ?? 0;
                                      final selected = filter.genericLaboratory == lab;
                                      return _BdmSubFilterTile(
                                        label: '$lab ($n résultat${n != 1 ? 's' : ''})',
                                        selected: selected,
                                        onTap: () => filterNotifier.setGenericLaboratory(selected ? null : lab),
                                        onShowSelection: () => showFullListForBdmSub(BdmSubFilter.generiques, lab: lab),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                        if (filter.bdmOnlySubFilters.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                controller.showFullListForFilter(ref.read(searchFilterProvider));
                              },
                              icon: const Icon(
                                Icons.list,
                                size: 18,
                                color: OffiboxColors.primary,
                              ),
                              label: const Text(
                                'Afficher la liste',
                                style: TextStyle(fontFamily: 'Spinnaker', color: OffiboxColors.primary),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                }),
                Divider(height: 16, color: Colors.grey.shade300),
                _FilterListTile(
                  value: filter.hideNsfp,
                  onChanged: (v) => filterNotifier.setHideNsfp(v ?? false),
                  title: 'Masquer NSFP',
                  onShowSelection: showSelection,
                ),
                _FilterListTile(
                  value: filter.hideHospitalOnly,
                  onChanged: (v) => filterNotifier.setHideHospitalOnly(v ?? false),
                  title: 'Masquer hospitalier seul',
                  onShowSelection: showSelection,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ligne Médicaments : clic sur "+" pour afficher le sous-menu (pas de badge "Afficher la sélection" sur cette ligne).
class _MedicamentsFilterRow extends StatelessWidget {
  const _MedicamentsFilterRow({
    required this.enabled,
    required this.title,
    required this.expanded,
    required this.onExpandTap,
    required this.onChanged,
  });

  final bool enabled;
  final String title;
  final bool expanded;
  final VoidCallback onExpandTap;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterListTile(
      value: enabled,
      onChanged: onChanged,
      title: title,
      trailing: OffiboxTooltip(
        message: expanded ? 'Masquer le sous-menu' : 'Afficher le sous-menu',
        child: InkWell(
          onTap: onExpandTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              expanded ? Icons.remove : Icons.add,
              size: 22,
              color: OffiboxColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de sous-filtre BDM (checkbox + optionnel "afficher la sélection" ou widget trailing).
class _BdmSubFilterTile extends StatelessWidget {
  const _BdmSubFilterTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onShowSelection,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onShowSelection;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: OffiboxColors.primary,
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Spinnaker',
                      color: selected ? OffiboxColors.primary : Colors.grey.shade800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && onShowSelection != null)
                  HoverPillButton(
                    icon: Icons.add,
                    label: '',
                    tooltip: 'Afficher la sélection',
                    onTap: onShowSelection!,
                    height: 26,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
