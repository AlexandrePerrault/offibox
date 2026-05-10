import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/core/filter_notifier.dart';
import 'package:offibox/core/annuaire_vaccination_controls.dart';
import 'package:offibox/core/medicaments_search_controls.dart';
import 'package:offibox/core/medicaments_filter_sources.dart';
import 'package:offibox/core/search_quick_category.dart';
import 'package:offibox/core/search_scope.dart';
import 'package:offibox/data/weleda_cip_resolver.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/providers/offibox_providers.dart';
import 'package:offibox/ui/results/result_tile.dart';
import 'package:offibox/ui/widgets/hover_pill_button.dart';
import 'package:offibox/services/medipim_api_client.dart';
import 'package:offibox/utils/normalize.dart';
import 'package:offibox/utils/open_url.dart';

/// Onglets sous la barre : libellés avec casse d’origine (majuscule initiale conservée),
/// hoverpill (bordure teal, remplissage au survol), onglet actif (ou tout sélectionné)
/// en teal marque [OffiboxColors.searchQuickTabSelected].
class SearchQuickTabsBar extends ConsumerWidget {
  const SearchQuickTabsBar({
    super.key,
    required this.barWidth,
    this.onOpenRecos,
    this.onOpenLaboratoiresPanel,
    this.onOpenOutilsMetierHub,
    this.onMedicamentsRetap,
  });

  final double barWidth;

  /// Ouvre le hub Recos (RecoMédicales + HAS).
  final VoidCallback? onOpenRecos;

  /// Panneau laboratoires (liste CSV, coordonnées).
  final VoidCallback? onOpenLaboratoiresPanel;

  /// Ouvre le panneau de recherche dédié Outils métier.
  final VoidCallback? onOpenOutilsMetierHub;

  /// Quand l’onglet Médicaments est déjà actif : permettre de ré-ouvrir
  /// le panneau de sous-badges (ex. si l’utilisateur l’a fermé).
  final VoidCallback? onMedicamentsRetap;

  static const List<
      ({
        SearchQuickCategory cat,
        String label,
        String tooltip,
      })> _tabs = [
    (
      cat: SearchQuickCategory.outilsEtFiches,
      label: 'Outils métier',
      tooltip:
          'Outils métier, codes actes, Vidal, Recomedicales, analyses biologiques, Weleda',
    ),
    (
      cat: SearchQuickCategory.medicaments,
      label: 'Médicaments',
      tooltip: 'Médicaments humains (BDM)',
    ),
    (
      cat: SearchQuickCategory.parapharmacie,
      label: 'Parapharmacie',
      tooltip:
          'Produits parapharmacie (Medipim uniquement). Taper la marque et le produit (ex. « Avène Hydrance ») puis cliquer sur « Rechercher ». Recherche approximative autorisée.',
    ),
    (
      cat: SearchQuickCategory.dm,
      label: 'DM',
      tooltip:
          'Pansements (données locales) ; après choix d’un produit, fiche Medipim (remboursement, photo)',
    ),
    (
      cat: SearchQuickCategory.lpp,
      label: 'Codes',
      tooltip: 'Codes de liste des produits et prestations (LPP)',
    ),
    (
      cat: SearchQuickCategory.annuaire,
      label: 'Annuaires',
      tooltip:
          'Annuaires locaux pendant la saisie ; API FHIR officines + RPPS après Espace ou Entrée',
    ),
  ];

  static IconData _iconFor(SearchQuickCategory c) {
    switch (c) {
      case SearchQuickCategory.medicaments:
        return Icons.medication_outlined;
      case SearchQuickCategory.parapharmacie:
        return Icons.spa_outlined;
      case SearchQuickCategory.dm:
        return Icons.healing_outlined;
      case SearchQuickCategory.lpp:
        return Icons.receipt_long_outlined;
      case SearchQuickCategory.outilsEtFiches:
        return Icons.build_outlined;
      case SearchQuickCategory.sitesWeb:
        return Icons.language;
      case SearchQuickCategory.organismes:
        return Icons.account_balance_outlined;
      case SearchQuickCategory.annuaire:
        return Icons.contact_phone_outlined;
    }
  }

  static const double _pillHeight = 28;
  static const double _pillHPad = 7;
  static const double _labelFont = 10.5;
  static const double _subLabelFont = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final selectedSingle = searchQuickCategoryMatchingFilter(filter);
    final wideOpen = searchFilterIsWideOpen(filter);
    final allSourcesDisabled =
        filter.disabledSources.length == SourceType.values.length;
    // Dépendances : déclencher un rebuild quand les sous-filtres Médicaments changent.
    ref.watch(medicamentsSearchByProvider);
    ref.watch(medicamentsTypeFilterProvider);
    ref.watch(medicamentsLaboratoryProvider);
    ref.watch(medicamentsGalenicShapeProvider);
    final annuaireList = ref.watch(annuaireQuickListProvider);
    final vaccBy = ref.watch(centresVaccinationSearchByProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : barWidth;
        return SizedBox(
          width: w,
          height: OffiboxWindowUI.searchQuickTabsRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final t in _tabs) ...[
                    HoverPillButton(
                      label: t.label,
                      icon: _iconFor(t.cat),
                      tooltip: t.tooltip,
                      height: _pillHeight,
                      horizontalPadding: _pillHPad,
                      labelFontSize: _labelFont,
                      searchQuickTabBarStyle: true,
                      quickTabSelected: wideOpen ||
                          selectedSingle == t.cat ||
                          (allSourcesDisabled &&
                              t.cat == SearchQuickCategory.outilsEtFiches) ||
                          (t.cat == SearchQuickCategory.annuaire &&
                              annuaireList ==
                                  AnnuaireQuickList.centresVaccination),
                      searchQuickTabLowercaseLabel: false,
                      maxLabelWidth: 200,
                      onTap: () {
                        if (t.cat != SearchQuickCategory.annuaire &&
                            annuaireList != null) {
                          ref.read(annuaireQuickListProvider.notifier).state =
                              null;
                        }
                        if (t.cat == SearchQuickCategory.outilsEtFiches) {
                          // Ouvrir immédiatement le panneau dédié au 1er clic.
                          onOpenOutilsMetierHub?.call();
                        }
                        if (t.cat == SearchQuickCategory.medicaments &&
                            selectedSingle == SearchQuickCategory.medicaments) {
                          onMedicamentsRetap?.call();
                        }
                        ref
                            .read(searchFilterProvider.notifier)
                            .applyQuickCategory(t.cat);
                        final sf = ref.read(searchFilterProvider);
                        ref.read(offiboxControllerProvider).setSearchScope(
                              searchScopeMatchingQuickCategory(t.cat),
                              searchFilter: sf,
                              skipAnnuaireApis:
                                  t.cat != SearchQuickCategory.annuaire,
                              refilterEvenIfUnchanged: true,
                            );
                      },
                    ),
                    if (t.cat == SearchQuickCategory.medicaments &&
                        selectedSingle == SearchQuickCategory.medicaments) ...[],
                    if (t.cat == SearchQuickCategory.annuaire &&
                        selectedSingle == SearchQuickCategory.annuaire) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Listes',
                        style: TextStyle(
                          fontFamily: 'Spinnaker',
                          fontSize: _subLabelFont,
                          color: const Color(0xFF3F4346)
                              .withValues(alpha: 0.78),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      HoverPillButton(
                        label: 'Centres de vaccination',
                        icon: Icons.vaccines_outlined,
                        tooltip: '',
                        height: _pillHeight,
                        horizontalPadding: _pillHPad,
                        labelFontSize: _subLabelFont,
                        searchQuickTabBarStyle: true,
                        quickTabSelected:
                            annuaireList == AnnuaireQuickList.centresVaccination,
                        searchQuickTabLowercaseLabel: false,
                        maxLabelWidth: 220,
                        onTap: () {
                          final selecting = annuaireList !=
                              AnnuaireQuickList.centresVaccination;
                          ref
                              .read(annuaireQuickListProvider.notifier)
                              .state = selecting
                                  ? AnnuaireQuickList.centresVaccination
                                  : null;
                          if (selecting) {
                            ref
                                .read(searchFilterProvider.notifier)
                                .enableOnlySources(
                                  {SourceType.centresVaccinations},
                                );
                            final sf = ref.read(searchFilterProvider);
                            ref.read(offiboxControllerProvider).setSearchScope(
                                  SearchScope.annuaires,
                                  searchFilter: sf,
                                  skipAnnuaireApis: true,
                                  refilterEvenIfUnchanged: true,
                                );
                            // Afficher la liste immédiatement (sans saisir).
                            ref
                                .read(offiboxControllerProvider)
                                .showFullListForCentresVaccinations();
                          } else {
                            ref
                                .read(searchFilterProvider.notifier)
                                .applyQuickCategory(SearchQuickCategory.annuaire);
                            final sf = ref.read(searchFilterProvider);
                            ref.read(offiboxControllerProvider).setSearchScope(
                                  SearchScope.annuaires,
                                  searchFilter: sf,
                                  skipAnnuaireApis: false,
                                  refilterEvenIfUnchanged: true,
                                );
                          }
                        },
                      ),
                      if (annuaireList ==
                          AnnuaireQuickList.centresVaccination) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Recherche par',
                          style: TextStyle(
                            fontFamily: 'Spinnaker',
                            fontSize: _subLabelFont,
                            color: const Color(0xFF3F4346)
                                .withValues(alpha: 0.78),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 6),
                        HoverPillButton(
                          label: 'Département',
                          icon: Icons.map_outlined,
                          tooltip:
                              'Taper le numéro de département (ex. 06, 971).',
                          height: _pillHeight,
                          horizontalPadding: _pillHPad,
                          labelFontSize: _subLabelFont,
                          searchQuickTabBarStyle: true,
                          quickTabSelected:
                              vaccBy == CentresVaccinationSearchBy.departement,
                          searchQuickTabLowercaseLabel: false,
                          maxLabelWidth: 130,
                          onTap: () {
                            ref
                                .read(centresVaccinationSearchByProvider.notifier)
                                .state = CentresVaccinationSearchBy.departement;
                          },
                        ),
                        const SizedBox(width: 4),
                        HoverPillButton(
                          label: 'Ville',
                          icon: Icons.location_city_outlined,
                          tooltip: 'Taper une ville (ex. Nice).',
                          height: _pillHeight,
                          horizontalPadding: _pillHPad,
                          labelFontSize: _subLabelFont,
                          searchQuickTabBarStyle: true,
                          quickTabSelected:
                              vaccBy == CentresVaccinationSearchBy.ville,
                          searchQuickTabLowercaseLabel: false,
                          maxLabelWidth: 90,
                          onTap: () {
                            ref
                                .read(centresVaccinationSearchByProvider.notifier)
                                .state = CentresVaccinationSearchBy.ville;
                          },
                        ),
                      ],
                    ],
                    const SizedBox(width: 4),
                  ],
                  HoverPillButton(
                    label: 'Laboratoires',
                    icon: Icons.science_outlined,
                    tooltip:
                        'Catalogues laboratoires (même filtre que Parapharmacie) — ouvrir la liste et les coordonnées (CSV)',
                    height: _pillHeight,
                    horizontalPadding: _pillHPad,
                    labelFontSize: _labelFont,
                    searchQuickTabBarStyle: true,
                    // Ne pas surligner en teal en même temps que « Parapharmacie » : uniquement si tout est sélectionné.
                    quickTabSelected: wideOpen,
                    searchQuickTabLowercaseLabel: false,
                    maxLabelWidth: 200,
                    onTap: () {
                      ref
                          .read(searchFilterProvider.notifier)
                          .applyQuickCategory(SearchQuickCategory.parapharmacie);
                      final sf = ref.read(searchFilterProvider);
                      ref.read(offiboxControllerProvider).setSearchScope(
                            searchScopeMatchingQuickCategory(
                              SearchQuickCategory.parapharmacie,
                            ),
                            searchFilter: sf,
                            skipAnnuaireApis: false,
                            refilterEvenIfUnchanged: true,
                          );
                      // Ouvrir le panneau après la bascule de filtre/scope :
                      // sinon le 1er clic pouvait se "perdre" pendant le rebuild.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onOpenLaboratoiresPanel?.call();
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  if (onOpenRecos != null) ...[
                    HoverPillButton(
                      label: 'RECOS',
                      icon: Icons.menu_book_outlined,
                      tooltip:
                          'Recommandations (RecoMédicales + HAS)',
                      height: _pillHeight,
                      horizontalPadding: _pillHPad,
                      labelFontSize: _labelFont,
                      searchQuickTabBarStyle: true,
                      quickTabSelected: wideOpen,
                      searchQuickTabLowercaseLabel: false,
                      maxLabelWidth: 120,
                      onTap: onOpenRecos!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  HoverPillButton(
                    label: wideOpen
                        ? 'Tout désélectionner'
                        : 'Tout sélectionner',
                    icon: wideOpen ? Icons.done_all : Icons.select_all,
                    tooltip: wideOpen
                        ? 'Revenir aux filtres « Outils métier »'
                        : 'Activer toutes les sources (même périmètre que tout l’historique de l’app)',
                    height: _pillHeight,
                    horizontalPadding: _pillHPad,
                    labelFontSize: _labelFont,
                    searchQuickTabBarStyle: true,
                    quickTabSelected: wideOpen,
                    searchQuickTabLowercaseLabel: false,
                    maxLabelWidth: 220,
                    onTap: () {
                      if (wideOpen) {
                        ref
                            .read(searchFilterProvider.notifier)
                            .applyQuickCategory(
                              SearchQuickCategory.outilsEtFiches,
                            );
                        final sf = ref.read(searchFilterProvider);
                        ref.read(offiboxControllerProvider).setSearchScope(
                              searchScopeMatchingQuickCategory(
                                SearchQuickCategory.outilsEtFiches,
                              ),
                              searchFilter: sf,
                              skipAnnuaireApis: false,
                              refilterEvenIfUnchanged: true,
                            );
                      } else {
                        ref.read(searchFilterProvider.notifier).reset();
                        final sf = ref.read(searchFilterProvider);
                        ref.read(offiboxControllerProvider).setSearchScope(
                              SearchScope.touteApp,
                              searchFilter: sf,
                              skipAnnuaireApis: false,
                              refilterEvenIfUnchanged: true,
                            );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sous-badges « Médicaments » dans la fenêtre inférieure (sous la barre),
/// comme les sous-badges « Annuaires » : "Rechercher par" + modes + dropdowns + bouton Rechercher.
class MedicamentsLowerSubBadgesBar extends ConsumerStatefulWidget {
  const MedicamentsLowerSubBadgesBar({
    super.key,
    required this.barWidth,
    required this.searchController,
    required this.onSearchSubmit,
  });

  final double barWidth;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchSubmit;

  // +20% vs ancien 28 → 33.6 (arrondi) pour meilleure lisibilité.
  static const double _pillHeight = 34;
  static const double _pillHPad = 7;
  static const double _subLabelFont = 10;

  @override
  ConsumerState<MedicamentsLowerSubBadgesBar> createState() =>
      _MedicamentsLowerSubBadgesBarState();
}

class _MedicamentsLowerSubBadgesBarState
    extends ConsumerState<MedicamentsLowerSubBadgesBar> {
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _dciCtrl = TextEditingController();
  final TextEditingController _labCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _nomFocus = FocusNode();
  final FocusNode _dciFocus = FocusNode();
  final FocusNode _labFocus = FocusNode();

  bool _syncing = false;
  MedicamentsSearchBy _lastBy = MedicamentsSearchBy.nom;

  Timer? _autoDebounce;
  int _autoSeq = 0;
  bool _autoSearching = false;
  String _autoQuery = '';
  MedicamentsSearchBy? _autoBy;
  List<SearchResult> _autoHits = const <SearchResult>[];

  String? _selectedWeledaFormuleLabel;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_syncFromMainIfNeeded);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_syncFromMainIfNeeded);
    _autoDebounce?.cancel();
    _codeCtrl.dispose();
    _nomCtrl.dispose();
    _dciCtrl.dispose();
    _labCtrl.dispose();
    _codeFocus.dispose();
    _nomFocus.dispose();
    _dciFocus.dispose();
    _labFocus.dispose();
    super.dispose();
  }

  void _syncFromMainIfNeeded() {
    if (_syncing) return;
    // Si la barre principale est vidée (gomme / fermeture menu), on vide aussi les champs.
    final t = widget.searchController.text.trim();
    if (t.isEmpty &&
        (_codeCtrl.text.isNotEmpty ||
            _nomCtrl.text.isNotEmpty ||
            _dciCtrl.text.isNotEmpty ||
            _labCtrl.text.isNotEmpty)) {
      _syncing = true;
      _codeCtrl.clear();
      _nomCtrl.clear();
      _dciCtrl.clear();
      _labCtrl.clear();
      _autoDebounce?.cancel();
      _autoSearching = false;
      _autoQuery = '';
      _autoBy = null;
      _autoHits = const <SearchResult>[];
      _syncing = false;
      if (mounted) setState(() {});
    }
  }

  void _activateBy(MedicamentsSearchBy by) {
    _lastBy = by;
    ref.read(medicamentsSearchByProvider.notifier).state = by;
    // Les badges statut / fournisseur tombent quand on passe sur un autre mode de saisie.
    // Conserver [medicamentsLaboratoryProvider] si le mode actif reste « laboratoire »
    // (badge Medipim + Rechercher sans effacer la sélection).
    if (by != MedicamentsSearchBy.laboratoire) {
      ref.read(medicamentsLaboratoryProvider.notifier).state = null;
    }
    ref.read(medicamentsTypeFilterProvider.notifier).state = null;
  }

  void _clearMedicamentsSearch() {
    _autoDebounce?.cancel();
    _autoSeq++;
    _syncing = true;
    _codeCtrl.clear();
    _nomCtrl.clear();
    _dciCtrl.clear();
    _labCtrl.clear();
    widget.searchController.clear();
    _syncing = false;

    ref.read(medicamentsTypeFilterProvider.notifier).state = null;
    ref.read(medicamentsLaboratoryProvider.notifier).state = null;
    ref.read(medicamentsGalenicShapeProvider.notifier).state = null;
    ref.read(medicamentsSearchByProvider.notifier).state = MedicamentsSearchBy.nom;
    final controller = ref.read(offiboxControllerProvider);
    controller.clearResults();
    controller.clearSelection();

    if (!mounted) return;
    setState(() {
      _lastBy = MedicamentsSearchBy.nom;
      _selectedWeledaFormuleLabel = null;
      _autoSearching = false;
      _autoBy = null;
      _autoQuery = '';
      _autoHits = const <SearchResult>[];
    });
  }

  static String _normalizeCodeQuery(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // QR / GS1 : on essaye d'abord un GTIN médicament français (34009 + 8 chiffres).
    final mFr = RegExp(r'(34009\d{8})').firstMatch(digits);
    if (mFr != null) return mFr.group(1) ?? '';

    // GTIN14 souvent préfixé par "0" (→ CIP13).
    if (digits.length == 14 && digits.startsWith('0')) {
      return digits.substring(1);
    }

    // Premier groupe CIP13.
    final m13 = RegExp(r'(\d{13})').firstMatch(digits);
    if (m13 != null) return m13.group(1) ?? '';

    // Premier groupe CIP7.
    final m7 = RegExp(r'(\d{7})').firstMatch(digits);
    if (m7 != null) return m7.group(1) ?? '';

    return digits;
  }

  bool _galenicExpansionAllowed(MedicamentsSearchBy by, String query) {
    switch (by) {
      case MedicamentsSearchBy.code:
        return query.length >= 7;
      case MedicamentsSearchBy.nom:
      case MedicamentsSearchBy.dci:
      case MedicamentsSearchBy.laboratoire:
        return query.length >= 3;
    }
  }

  void _runLocalSearchNow({
    required MedicamentsSearchBy by,
    required String rawQuery,
    bool expandGalenicOnCommit = false,
  }) {
    final query = by == MedicamentsSearchBy.code
        ? _normalizeCodeQuery(rawQuery)
        : rawQuery.trim();

    // Nom / DCI : auto dès 3 lettres (comme Annuaire Santé).
    if ((by == MedicamentsSearchBy.nom || by == MedicamentsSearchBy.dci) &&
        query.length < 3) {
      setState(() {
        _autoDebounce?.cancel();
        _autoSearching = false;
        _autoBy = by;
        _autoQuery = query;
        _autoHits = const <SearchResult>[];
      });
      return;
    }

    // Laboratoire : auto dès 3 lettres (Medipim + BDM).
    if (by == MedicamentsSearchBy.laboratoire && query.length < 3) {
      setState(() {
        _autoDebounce?.cancel();
        _autoSearching = false;
        _autoBy = by;
        _autoQuery = query;
        _autoHits = const <SearchResult>[];
      });
      return;
    }

    // Code : accepte CIP7 / CIP13 / QR (via extraction). Lance dès 7 chiffres.
    if (by == MedicamentsSearchBy.code && query.length < 7) {
      setState(() {
        _autoDebounce?.cancel();
        _autoSearching = false;
        _autoBy = by;
        _autoQuery = query;
        _autoHits = const <SearchResult>[];
      });
      return;
    }

    final seq = ++_autoSeq;
    setState(() {
      _autoSearching = true;
      _autoBy = by;
      _autoQuery = query;
      _autoHits = const <SearchResult>[];
    });

    if (by == MedicamentsSearchBy.laboratoire) {
      unawaited(
        _runLaboratorySearch(
          seq: seq,
          query: query,
          expandGalenicOnCommit: expandGalenicOnCommit,
        ),
      );
      return;
    }

    final sf = ref.read(searchFilterProvider);
    ref.read(offiboxControllerProvider).filterImmediate(
          query,
          searchFilter: sf,
          suppressNetwork: true,
          skipAnnuaireApis: true,
        );

    // Résultats produits au prochain frame (filterImmediate utilise addPostFrameCallback).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (seq != _autoSeq) return;
      final controller = ref.read(offiboxControllerProvider);

      if (expandGalenicOnCommit) {
        final gal = ref.read(medicamentsGalenicShapeProvider);
        if (gal != null && _galenicExpansionAllowed(by, query)) {
          final labR = ref.read(medicamentsLaboratoryProvider)?.trim();
          await controller.showFullListForMedicamentsGalenicShape(
            galenicShapeId: gal.id,
            galenicShapeLabel: gal.label,
            restrictToManufacturerName:
                labR != null && labR.isNotEmpty ? labR : null,
          );
          if (!mounted || seq != _autoSeq) return;
          setState(() {
            _autoSearching = false;
            _autoHits = const <SearchResult>[];
          });
          return;
        }
      }

      if (by == MedicamentsSearchBy.nom && query.length >= 2) {
        controller.prioritizeMedicamentsCommercialNameStartsWith(query);
      }
      final results = controller.filteredResults;

      final base = results.where((r) => r.source == SourceType.bdm);

      // Composition/DCI : inclure aussi Weleda (formules W) même si l’onglet Médicaments
      // ne l’active pas dans le filtre global.
      final weledaMatches = <SearchResult>[];
      if (by == MedicamentsSearchBy.dci && query.length >= 3) {
        final qNorm = normalizeLooseKeepSpaces(query);
        final tokens = qNorm
            .split(' ')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
        for (final r in controller.allResults) {
          if (r.source != SourceType.weleda) continue;
          final hay = normalizeLooseKeepSpaces('${r.labelRaw} ${r.groupLabel ?? ''}');
          var ok = true;
          for (final t in tokens) {
            if (!hay.contains(t)) {
              ok = false;
              break;
            }
          }
          if (ok) weledaMatches.add(r);
          if (weledaMatches.length >= 20) break;
        }
      }

      final seen = <String>{};
      final merged = <SearchResult>[];
      for (final r in [...base, ...weledaMatches]) {
        final k = '${r.source.name}_${r.cip13 ?? ''}_${r.cis ?? ''}_${r.labelRaw}';
        if (seen.add(k)) merged.add(r);
        if (merged.length >= 30) break;
      }
      final out = merged.toList(growable: false);
      if (!mounted) return;
      if (seq != _autoSeq) return;
      setState(() {
        _autoSearching = false;
        _autoHits = out;
      });
      if (out.length == 1) {
        ref.read(offiboxControllerProvider).selectResult(out.first);
      }
    });
  }

  void _onTypeInField(MedicamentsSearchBy by, String raw) {
    if (_syncing) return;
    _activateBy(by);
    final t = raw.trim();

    // Un seul champ texte actif à la fois (comme Annuaire Santé).
    _syncing = true;
    if (by != MedicamentsSearchBy.code && _codeCtrl.text.isNotEmpty) {
      _codeCtrl.clear();
    }
    if (by != MedicamentsSearchBy.nom && _nomCtrl.text.isNotEmpty) {
      _nomCtrl.clear();
    }
    if (by != MedicamentsSearchBy.dci && _dciCtrl.text.isNotEmpty) {
      _dciCtrl.clear();
    }
    if (by != MedicamentsSearchBy.laboratoire && _labCtrl.text.isNotEmpty) {
      _labCtrl.clear();
    }
    _syncing = false;

    // Recherche auto : Nom / Composition / Laboratoire.
    if (by == MedicamentsSearchBy.nom ||
        by == MedicamentsSearchBy.dci ||
        by == MedicamentsSearchBy.laboratoire) {
      _autoDebounce?.cancel();
      _autoDebounce = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        _runLocalSearchNow(by: by, rawQuery: t);
      });
    } else {
      // Pour les autres champs, on ne déclenche pas automatiquement.
      _autoDebounce?.cancel();
      if (_autoHits.isNotEmpty || _autoSearching) {
        setState(() {
          _autoSearching = false;
          _autoBy = by;
          _autoQuery = t;
          _autoHits = const <SearchResult>[];
        });
      } else {
        if (mounted) setState(() {});
      }
    }
  }

  void _submitFromTextField(MedicamentsSearchBy by) {
    final vRaw = switch (by) {
      MedicamentsSearchBy.code => _codeCtrl.text.trim(),
      MedicamentsSearchBy.nom => _nomCtrl.text.trim(),
      MedicamentsSearchBy.dci => _dciCtrl.text.trim(),
      MedicamentsSearchBy.laboratoire => _labCtrl.text.trim(),
    };
    _activateBy(by);
    final normQuery = by == MedicamentsSearchBy.code
        ? _normalizeCodeQuery(vRaw)
        : vRaw.trim();
    final expandGalenic = ref.read(medicamentsGalenicShapeProvider) != null &&
        _galenicExpansionAllowed(by, normQuery);
    _runLocalSearchNow(
      by: by,
      rawQuery: vRaw,
      expandGalenicOnCommit: expandGalenic,
    );
  }

  Future<void> _runLaboratorySearch({
    required int seq,
    required String query,
    bool expandGalenicOnCommit = false,
  }) async {
    final q = query.trim();
    if (q.length < 3) return;
    final controller = ref.read(offiboxControllerProvider);

    if (expandGalenicOnCommit) {
      final gal = ref.read(medicamentsGalenicShapeProvider);
      if (gal != null && q.length >= 3) {
        final labR = ref.read(medicamentsLaboratoryProvider)?.trim();
        await controller.showFullListForMedicamentsGalenicShape(
          galenicShapeId: gal.id,
          galenicShapeLabel: gal.label,
          restrictToManufacturerName:
              (labR != null && labR.isNotEmpty) ? labR : q,
        );
        if (!mounted || seq != _autoSeq) return;
        setState(() {
          _autoSearching = false;
          _autoBy = MedicamentsSearchBy.laboratoire;
          _autoQuery = q;
          _autoHits = List<SearchResult>.from(controller.filteredResults);
        });
        return;
      }
    }

    // Même fusion BDM + Medipim que le badge fournisseur / « Rechercher ».
    await controller.showFullListForMedicamentsManufacturer(q);
    if (!mounted || seq != _autoSeq) return;
    setState(() {
      _autoSearching = false;
      _autoBy = MedicamentsSearchBy.laboratoire;
      _autoQuery = q;
      _autoHits = List<SearchResult>.from(controller.filteredResults);
    });
  }

  Future<void> _openUrlFromMedicamentsHit(String url) async {
    final clean = url
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();
    if (!clean.startsWith('http') && !clean.startsWith('tel:')) return;
    await openUrl(clean);
  }

  Widget _buildMedicamentsLocalHitsBlock() {
    final by = _autoBy;
    final q = _autoQuery.trim();
    if (by == null) return const SizedBox.shrink();
    if (q.isEmpty) return const SizedBox.shrink();

    final shouldShow = (by == MedicamentsSearchBy.nom || by == MedicamentsSearchBy.dci)
        ? q.length >= 3
        : by == MedicamentsSearchBy.code
            ? q.length >= 7
            : by == MedicamentsSearchBy.laboratoire
                ? q.length >= 3
                : false;
    if (!shouldShow) return const SizedBox.shrink();

    if (_autoSearching) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const SizedBox(width: 6),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: OffiboxColors.primary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recherche…',
              style: TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_autoHits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, left: 6),
        child: Text(
          'Aucun médicament trouvé.',
          style: TextStyle(
            fontFamily: 'Spinnaker',
            fontSize: 12,
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final controller = ref.read(offiboxControllerProvider);
    final results = _autoHits;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final item = results[i];
                final label = ResultLabelHelper.displayLabel(item);
                final hasNsfpDate = (item.nsfpDate ?? '').trim().isNotEmpty;
                return ResultTile(
                  item: item,
                  label: label,
                  query: q,
                  hasNsfpDate: hasNsfpDate,
                  isSingleResult: false,
                  animationIndex: i,
                  onOpen: () {
                    ref.read(offiboxControllerProvider).selectResult(item);
                    setState(() {
                      _autoDebounce?.cancel();
                      _autoSearching = false;
                      _autoHits = const <SearchResult>[];
                    });
                  },
                  onOpenUrl: (url) => _openUrlFromMedicamentsHit(url),
                  statutsForCis: item.cis != null
                      ? controller.statutsByCis[item.cis!.replaceAll(RegExp(r'\D'), '').trim()]
                      : null,
                  tauxRemboursement: item.cis != null
                      ? controller.tauxRemboursementByCis[
                          item.cis!.replaceAll(RegExp(r'\D'), '').trim()
                        ]
                      : null,
                  ansmStatutsByCis: controller.ansmStatutsByCis,
                  generiques2026ByCis: controller.generiques2026ByCis,
                  generiques2026PrincepsKeyToGenericName:
                      controller.generiques2026PrincepsKeyToGenericName,
                  generiques2026DciToGenericName:
                      controller.generiques2026DciToGenericName,
                  generiques2026CisSet: controller.generiques2026CisSet,
                  biosimilairesInfoByCip: controller.biosimilairesInfoByCip,
                  compositionByCis: controller.compositionByCis,
                  compositionBdpmByCis: controller.compositionBdpmByCis,
                  hospitalCip13Set: controller.hospitalCip13Set,
                  recalledProductNames: controller.recalledProductNames,
                  videosByCip13: controller.videosByCip13,
                  cisArretCommercialisation: controller.cisArretCommercialisation,
                  arretCommercialisationByCis:
                      controller.arretCommercialisationByCis,
                  cip13ToFic03Status: controller.cip13ToFic03Status,
                  ansmHybridesCip13: controller.ansmHybridesCip13,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _pillFieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      prefixIcon: Icon(icon, size: 16, color: OffiboxColors.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
        borderSide: const BorderSide(color: OffiboxColors.primary, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
        borderSide: const BorderSide(color: OffiboxColors.primary, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
        borderSide: const BorderSide(color: OffiboxColors.primary, width: 1.4),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Spinnaker',
        fontSize: 12,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _textPillField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required MedicamentsSearchBy by,
    String? tooltip,
  }) {
    final field = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: MedicamentsLowerSubBadgesBar._pillHeight,
        maxHeight: MedicamentsLowerSubBadgesBar._pillHeight,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontFamily: 'Spinnaker', fontSize: 12.5),
        decoration: _pillFieldDecoration(hint: hint, icon: icon),
        onChanged: (v) => _onTypeInField(by, v),
        onSubmitted: (_) => _submitFromTextField(by),
      ),
    );
    final tip = tooltip?.trim();
    if (tip == null || tip.isEmpty) return field;
    return Tooltip(message: tip, child: field);
  }

  Widget _clearSearchPill() {
    const color = Color(0xFFD97706);
    return SizedBox(
      height: MedicamentsLowerSubBadgesBar._pillHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
        child: InkWell(
          onTap: _clearMedicamentsSearch,
          borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(MedicamentsLowerSubBadgesBar._pillHeight / 2),
              border: Border.all(color: color),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cleaning_services_outlined, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Effacer la recherche',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Spinnaker',
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterProvider);
    final selectedSingle = searchQuickCategoryMatchingFilter(filter);
    if (selectedSingle != SearchQuickCategory.medicaments) {
      return const SizedBox.shrink();
    }

    final medsBy = ref.watch(medicamentsSearchByProvider);
    final medsType = ref.watch(medicamentsTypeFilterProvider);
    final medsGalenic = ref.watch(medicamentsGalenicShapeProvider);

    return SizedBox(
      width: widget.barWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rechercher par',
            style: TextStyle(
              fontFamily: 'Spinnaker',
              fontSize: MedicamentsLowerSubBadgesBar._subLabelFont,
              color: const Color(0xFF3F4346).withValues(alpha: 0.78),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const double gap = 10;
              final w = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : widget.barWidth;
              final colW = ((w - gap * 2) / 3).clamp(160.0, w);
              Widget cell(Widget child) => SizedBox(width: colW, child: child);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  cell(
                    _textPillField(
                      controller: _codeCtrl,
                      focusNode: _codeFocus,
                      hint: 'Code (CIP7 / CIP13 / QR-code)…',
                      icon: Icons.qr_code_2,
                      by: MedicamentsSearchBy.code,
                    ),
                  ),
                  cell(
                    _textPillField(
                      controller: _nomCtrl,
                      focusNode: _nomFocus,
                      hint: 'Nom commercial…',
                      icon: Icons.medication_outlined,
                      by: MedicamentsSearchBy.nom,
                    ),
                  ),
                  cell(
                    _textPillField(
                      controller: _dciCtrl,
                      focusNode: _dciFocus,
                      hint: 'Composition (DCI, plusieurs molécules…)…',
                      icon: Icons.biotech_outlined,
                      by: MedicamentsSearchBy.dci,
                      tooltip:
                          'Recherche inversée par composition (CSV composition-bdm). '
                          'Plusieurs molécules : tapez chaque substance (ex. paracetamol codeine) '
                          'pour intersecter les CIS.',
                    ),
                  ),
                  cell(
                    _MedicamentsManufacturerDropdownPill(
                      selected: ref.watch(medicamentsLaboratoryProvider),
                      height: MedicamentsLowerSubBadgesBar._pillHeight,
                      horizontalPadding: MedicamentsLowerSubBadgesBar._pillHPad,
                      labelFontSize: MedicamentsLowerSubBadgesBar._subLabelFont,
                    ),
                  ),
                  cell(
                    _WeledaFormuleDropdownPill(
                      selectedLabel: _selectedWeledaFormuleLabel,
                      height: MedicamentsLowerSubBadgesBar._pillHeight,
                      horizontalPadding: MedicamentsLowerSubBadgesBar._pillHPad,
                      labelFontSize: MedicamentsLowerSubBadgesBar._subLabelFont,
                      onSelected: (pickedLabel, pickedItem) async {
                        setState(() {
                          _selectedWeledaFormuleLabel = pickedLabel;
                          _autoDebounce?.cancel();
                          _autoSearching = false;
                          _autoHits = const <SearchResult>[];
                        });
                        final c = ref.read(offiboxControllerProvider);
                        c.selectResult(pickedItem);
                        final enriched =
                            await WeledaCipResolver.enrichFromMedicamentsApi(
                          pickedItem,
                        );
                        if (!mounted) return;
                        final sel = c.selectedResult;
                        final stillSame = sel != null &&
                            sel.source == SourceType.weleda &&
                            sel.label == pickedItem.label &&
                            sel.weledaEhRegistration ==
                                pickedItem.weledaEhRegistration;
                        if (stillSame) {
                          c.selectResult(enriched);
                        }
                      },
                    ),
                  ),
                  cell(
                    _MedicamentsGalenicDropdownPill(
                      selected: medsGalenic,
                      height: MedicamentsLowerSubBadgesBar._pillHeight,
                      horizontalPadding: MedicamentsLowerSubBadgesBar._pillHPad,
                      labelFontSize: MedicamentsLowerSubBadgesBar._subLabelFont,
                    ),
                  ),
                  cell(
                    _MedicamentsTypeDropdownPill(
                      selected: medsType,
                      height: MedicamentsLowerSubBadgesBar._pillHeight,
                      horizontalPadding: MedicamentsLowerSubBadgesBar._pillHPad,
                      labelFontSize: MedicamentsLowerSubBadgesBar._subLabelFont,
                    ),
                  ),
                  cell(
                    HoverPillButton(
                      label: 'Rechercher',
                      icon: Icons.search,
                      tooltip: 'Lancer la recherche (clic ou Entrée)',
                      height: MedicamentsLowerSubBadgesBar._pillHeight,
                      horizontalPadding: 12,
                      labelFontSize: 11,
                      // ✅ Bouton vert Offibox (rempli).
                      quickTabSelected: true,
                      quickTabSelectedFilled: true,
                      searchQuickTabBarStyle: true,
                      searchQuickTabLowercaseLabel: false,
                      maxLabelWidth: 140,
                      onTap: () async {
                        final typeSel =
                            ref.read(medicamentsTypeFilterProvider);
                        final labSel =
                            ref.read(medicamentsLaboratoryProvider)?.trim();
                        final c = ref.read(offiboxControllerProvider);
                        if (typeSel != null) {
                          c.showFullListForMedicamentsType(typeSel);
                          return;
                        }
                        final by = medsBy;
                        final candidate = switch (by) {
                          MedicamentsSearchBy.code => _codeCtrl.text.trim(),
                          MedicamentsSearchBy.nom => _nomCtrl.text.trim(),
                          MedicamentsSearchBy.dci => _dciCtrl.text.trim(),
                          MedicamentsSearchBy.laboratoire =>
                            _labCtrl.text.trim(),
                        };
                        _activateBy(by);
                        final normQuery = by == MedicamentsSearchBy.code
                            ? _normalizeCodeQuery(candidate)
                            : candidate.trim();
                        final hasMedicamentQuery =
                            _galenicExpansionAllowed(by, normQuery);

                        if (hasMedicamentQuery) {
                          _runLocalSearchNow(
                            by: by,
                            rawQuery: candidate,
                            expandGalenicOnCommit: true,
                          );
                          return;
                        }

                        if (labSel != null && labSel.isNotEmpty) {
                          await c.showFullListForMedicamentsManufacturer(
                            labSel,
                          );
                          if (!mounted) return;
                          setState(() {
                            _autoSearching = false;
                            _autoBy = MedicamentsSearchBy.laboratoire;
                            _autoQuery = labSel;
                            _autoHits =
                                List<SearchResult>.from(c.filteredResults);
                          });
                          return;
                        }
                      },
                    ),
                  ),
                  cell(_clearSearchPill()),
                ],
              );
            },
          ),
          _buildMedicamentsLocalHitsBlock(),
        ],
      ),
    );
  }
}

class _WeledaFormuleDropdownPill extends ConsumerStatefulWidget {
  const _WeledaFormuleDropdownPill({
    required this.selectedLabel,
    required this.height,
    required this.horizontalPadding,
    required this.labelFontSize,
    required this.onSelected,
  });

  final String? selectedLabel;
  final double height;
  final double horizontalPadding;
  final double labelFontSize;
  final Future<void> Function(String pickedLabel, SearchResult pickedItem)
      onSelected;

  static int _wNumber(String label) {
    final m = RegExp(r'^W(\d+)').firstMatch(label.trim().toUpperCase());
    if (m == null) return 1 << 30;
    return int.tryParse(m.group(1) ?? '') ?? (1 << 30);
  }

  static String _pillLabel(String? selectedLabel) {
    return 'Formule Weleda';
  }

  /// Libellé liste : pas de code EH ; CIP BDPM seulement si déjà résolu (13 chiffres 34009…).
  static String _dialogLabel(SearchResult item) {
    final label = item.label.trim();
    final digits = (item.cip13 ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('34009')) {
      final cip7 = digits.substring(5, 12);
      return '$label — CIP7 $cip7 — CIP13 $digits';
    }
    return label;
  }

  @override
  ConsumerState<_WeledaFormuleDropdownPill> createState() =>
      _WeledaFormuleDropdownPillState();
}

class _WeledaFormuleDropdownPillState
    extends ConsumerState<_WeledaFormuleDropdownPill> {
  Future<void> _openDialog() async {
    final controller = ref.read(offiboxControllerProvider);
    final all = controller.allResults;
    if (all.isEmpty) return;

    final weledaFormules = all
        .where((r) => r.source == SourceType.weleda)
        .where((r) => r.label.trim().toUpperCase().startsWith('W'))
        .toList(growable: false);
    if (weledaFormules.isEmpty) return;

    weledaFormules.sort((a, b) {
      final na = _WeledaFormuleDropdownPill._wNumber(a.label);
      final nb = _WeledaFormuleDropdownPill._wNumber(b.label);
      if (na != nb) return na.compareTo(nb);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    final pick = await showDialog<SearchResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _WeledaFormulesPickDialog(
        items: weledaFormules,
        initialNameQuery: widget.selectedLabel ?? '',
      ),
    );
    if (!mounted) return;
    final chosenItem = pick;
    if (chosenItem == null) return;

    final chosenLabel = chosenItem.label.trim();
    await widget.onSelected(chosenLabel, chosenItem);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.selectedLabel;
    return HoverPillButton(
      label: _WeledaFormuleDropdownPill._pillLabel(selectedLabel),
      icon: Icons.spa_outlined,
      tooltip:
          'Formules Weleda (W) : liste, recherche par composants, CIP13 BDPM.',
      height: widget.height,
      horizontalPadding: widget.horizontalPadding,
      labelFontSize: widget.labelFontSize,
      searchQuickTabBarStyle: true,
      quickTabSelected: selectedLabel != null && selectedLabel.trim().isNotEmpty,
      quickTabSelectedFilled: false,
      searchQuickTabLowercaseLabel: false,
      maxLabelWidth: 150,
      onTap: _openDialog,
    );
  }
}

/// Choix d’une formule W : recherche par nom **et** par composants (CSV Weleda).
class _WeledaFormulesPickDialog extends StatefulWidget {
  const _WeledaFormulesPickDialog({
    required this.items,
    this.initialNameQuery = '',
  });

  final List<SearchResult> items;
  final String initialNameQuery;

  @override
  State<_WeledaFormulesPickDialog> createState() =>
      _WeledaFormulesPickDialogState();
}

class _WeledaFormulesPickDialogState extends State<_WeledaFormulesPickDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _compCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  List<SearchResult> _filtered = const [];
  SearchResult? _selected;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialNameQuery;
    _nameCtrl.addListener(_apply);
    _compCtrl.addListener(_apply);
    _apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_apply);
    _compCtrl.removeListener(_apply);
    _nameCtrl.dispose();
    _compCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _apply() {
    final nq = _nameCtrl.text.trim().toLowerCase();
    final cq = _compCtrl.text.trim();
    setState(() {
      _filtered = widget.items.where((r) {
        final rowLabel = r.label.trim().toLowerCase();
        final rawHay = normalizeLooseKeepSpaces(r.labelRaw).toLowerCase();
        final nameOk =
            nq.isEmpty || rowLabel.contains(nq) || rawHay.contains(nq);
        final hay = WeledaCipResolver.compositionHaystack(r);
        final compOk = WeledaCipResolver.compositionMatchesTokens(hay, cq);
        return nameOk && compOk;
      }).toList();
      _selected = _filtered.isNotEmpty ? _filtered.first : null;
    });
  }

  void _submit() {
    final pick = _selected;
    if (pick == null) return;
    Navigator.of(context).pop(pick);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final panelW = (w - 40).clamp(320.0, 560.0);
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: panelW,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Formules Weleda (W)',
                style: TextStyle(
                  fontFamily: 'Spinnaker',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Filtrer par formule (ex. W306, granules…)…',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                style: const TextStyle(fontFamily: 'Spinnaker', fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _compCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText:
                      'Composition (plantes, plusieurs mots, ET logique)…',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.biotech_outlined,
                      size: 18, color: OffiboxColors.primary),
                ),
                style: const TextStyle(fontFamily: 'Spinnaker', fontSize: 13),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: _filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'Aucune formule ne correspond.',
                          style: TextStyle(
                            fontFamily: 'Spinnaker',
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final r = _filtered[i];
                          final selected = r == _selected;
                          final comp = (r.groupLabel ?? '').trim();
                          final cipDigits =
                              r.cip13?.replaceAll(RegExp(r'\D'), '').trim() ??
                                  '';
                          final showCip = cipDigits.length == 13 &&
                              cipDigits.startsWith('34009');
                          return Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              hoverColor: OffiboxColors.primary
                                  .withValues(alpha: 0.08),
                              onTap: () {
                                setState(() => _selected = r);
                                _submit();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE8F5F4)
                                          .withValues(alpha: 0.55)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? OffiboxColors.primary
                                            .withValues(alpha: 0.35)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.label.trim(),
                                      style: const TextStyle(
                                        fontFamily: 'Spinnaker',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (comp.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          comp,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Spinnaker',
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    if (showCip)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'CIP13 $cipDigits',
                                          style: TextStyle(
                                            fontFamily: 'Spinnaker',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: OffiboxColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontFamily: 'Spinnaker'),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _submit,
                    child: const Text(
                      'Valider',
                      style: TextStyle(fontFamily: 'Spinnaker'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _medipimGalenicShapesProvider =
    FutureProvider<List<MedipimGalenicShape>>((ref) async {
  final api = MedipimApiClient();
  final list = await api.listGalenicShapes(maxPages: 18, pageSize: 250);
  // Ne conserver que les items avec un libellé FR (fallback = id).
  return list
      .map((e) => (id: e.id, label: e.label))
      .where((e) => e.id.trim().isNotEmpty && e.label.trim().isNotEmpty)
      .toList(growable: false);
});

final _medipimManufacturersProvider = FutureProvider<List<String>>((ref) async {
  String body;
  try {
    body = await rootBundle.loadString('assets/medipim_fabricants_list.csv');
  } catch (_) {
    body = await rootBundle.loadString('assets/medipim_fabricants.csv');
  }
  final out = <String>{};
  for (final rawLine in body.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.toLowerCase() == 'nom') continue;
    final value = line.split(',').first.replaceAll('"', '').trim();
    if (value.isNotEmpty) out.add(value);
  }
  final list = out.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
});

const List<String> _medicamentsGalenicQuickLabels = [
  'Comprimé',
  'Gélule',
  'Capsule',
  'Poudre',
  'Granulés',
  'Sachet-dose',
  'Solution buvable',
  'Suspension buvable',
  'Sirop',
  'Émulsion',
  'Gouttes buvables',
  'Comprimé sublingual',
  'Comprimé buccal',
  'Pastille à sucer',
  'Spray buccal',
  'Bain de bouche',
  'Gel buccal',
  'Solution injectable',
  'Suspension injectable',
  'Poudre pour solution injectable',
  'Perfusion',
  'Seringue préremplie',
  'Implant injectable',
  'Suppositoire',
  'Capsule rectale',
  'Solution rectale',
  'Lavement',
  'Ovule',
  'Capsule vaginale',
  'Comprimé vaginal',
  'Crème vaginale',
  'Gel vaginal',
  'Solution vaginale',
  'Crème',
  'Pommade',
  'Gel',
  'Lotion',
  'Solution cutanée',
  'Emulsion cutanée',
  'Mousse',
  'Spray cutané',
  'Patch transdermique',
  'Vernis médicamenteux',
  'Collyre',
  'Gel ophtalmique',
  'Pommade ophtalmique',
  'Insert ophtalmique',
  'Gouttes auriculaires',
  'Spray auriculaire',
  'Pommade auriculaire',
  'Spray nasal',
  'Gouttes nasales',
  'Gel nasal',
  'Poudre nasale',
  'Aérosol-doseur',
  'Poudre pour inhalation',
  'Solution pour inhalation',
  'Nébulisation',
  'Implant',
  'Dispositif intra-utérin médicamenteux',
  'Système thérapeutique transdermique',
];

class _MedicamentsGalenicDropdownPill extends ConsumerStatefulWidget {
  const _MedicamentsGalenicDropdownPill({
    required this.selected,
    required this.height,
    required this.horizontalPadding,
    required this.labelFontSize,
  });

  final MedipimGalenicShape? selected;
  final double height;
  final double horizontalPadding;
  final double labelFontSize;

  @override
  ConsumerState<_MedicamentsGalenicDropdownPill> createState() =>
      _MedicamentsGalenicDropdownPillState();
}

class _MedicamentsGalenicDropdownPillState
    extends ConsumerState<_MedicamentsGalenicDropdownPill> {
  MedipimGalenicShape? _matchMedipimShape(
    List<MedipimGalenicShape> shapes,
    String label,
  ) {
    final wanted = normalizeLooseKeepSpaces(label);
    if (wanted.isEmpty) return null;

    for (final shape in shapes) {
      if (normalizeLooseKeepSpaces(shape.label) == wanted) return shape;
    }

    final wantedTokens = wanted
        .split(' ')
        .map((s) => s.trim())
        .where((s) => s.length > 1)
        .toList(growable: false);
    if (wantedTokens.isEmpty) return null;

    final candidates = shapes.where((shape) {
      final hay = normalizeLooseKeepSpaces(shape.label);
      return wantedTokens.every(hay.contains);
    }).toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final na = normalizeLooseKeepSpaces(a.label);
      final nb = normalizeLooseKeepSpaces(b.label);
      final da = (na.length - wanted.length).abs();
      final db = (nb.length - wanted.length).abs();
      if (da != db) return da.compareTo(db);
      return na.compareTo(nb);
    });
    return candidates.first;
  }

  Future<void> _openDialog() async {
    final pick = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _SearchablePickDialog(
        title: 'Forme galénique',
        hintText: 'Rechercher une forme…',
        items: _medicamentsGalenicQuickLabels,
        initialQuery: widget.selected?.label ?? '',
        itemTooltip: (s) =>
            '« $s » — taxonomie Medipim (forme galénique). '
            'Badge seul : aucune liste ; avec recherche médicament + Rechercher : '
            'tous les produits de cette forme.',
      ),
    );
    if (!mounted) return;
    final chosenLabel = pick?.trim();
    if (chosenLabel == null || chosenLabel.isEmpty) return;

    final shapes = await ref.read(_medipimGalenicShapesProvider.future);
    if (!mounted) return;
    final matched = _matchMedipimShape(shapes, chosenLabel);
    if (matched == null || matched.id.trim().isEmpty) return;
    final chosen = (id: matched.id, label: chosenLabel);

    ref.read(medicamentsGalenicShapeProvider.notifier).state = chosen;
    ref.read(medicamentsTypeFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(medicamentsGalenicShapeProvider);
    final label = selected == null ? 'Forme galénique' : selected.label;
    return HoverPillButton(
      label: label,
      icon: Icons.category_outlined,
      tooltip:
          'Forme galénique : affichée en badge seule. Lancez une recherche '
          '(code, nom, composition…) puis tous les médicaments de cette forme '
          's’affichent via Medipim.',
      height: widget.height,
      horizontalPadding: widget.horizontalPadding,
      labelFontSize: widget.labelFontSize,
      searchQuickTabBarStyle: true,
      quickTabSelected: selected != null,
      quickTabSelectedFilled: false,
      searchQuickTabLowercaseLabel: false,
      maxLabelWidth: 150,
      onTap: _openDialog,
    );
  }
}

class _MedicamentsTypeDropdownPill extends ConsumerStatefulWidget {
  const _MedicamentsTypeDropdownPill({
    required this.selected,
    required this.height,
    required this.horizontalPadding,
    required this.labelFontSize,
  });

  final MedicamentsTypeFilter? selected;
  final double height;
  final double horizontalPadding;
  final double labelFontSize;

  @override
  ConsumerState<_MedicamentsTypeDropdownPill> createState() =>
      _MedicamentsTypeDropdownPillState();
}

class _MedicamentsTypeDropdownPillState
    extends ConsumerState<_MedicamentsTypeDropdownPill> {
  static String _menuLabel(MedicamentsTypeFilter t) {
    switch (t) {
      case MedicamentsTypeFilter.medicamentsException:
        return 'Médicaments d\'exception';
      case MedicamentsTypeFilter.hypnotiques:
        return 'Hypnotiques';
      case MedicamentsTypeFilter.anxiolytiques:
        return 'Anxiolytiques';
      case MedicamentsTypeFilter.derivesDuSangMds:
        return 'Médicaments dérivés du sang';
      case MedicamentsTypeFilter.biosimilaires:
        return 'Biosimilaires';
      case MedicamentsTypeFilter.bioreferents:
        return 'Bioréférents';
      case MedicamentsTypeFilter.stupefiantsAssimiles:
        return 'Médicaments stupéfiants & assimilés';
      case MedicamentsTypeFilter.liste1:
        return 'Médicaments liste 1';
      case MedicamentsTypeFilter.liste2:
        return 'Médicaments liste 2';
      case MedicamentsTypeFilter.hospitaliers:
        return 'Médicaments hospitaliers';
      case MedicamentsTypeFilter.surveillanceParticuliere:
        return 'Médicaments nécessitant une surveillance particulière';
      case MedicamentsTypeFilter.prescriptionInitialeHospitaliere:
        return 'Médicaments à prescription initiale hospitalière';
      case MedicamentsTypeFilter.libreAccesOtc:
        return 'Médicament en Libre accès';
      case MedicamentsTypeFilter.princeps:
        return 'Médicaments princeps';
      case MedicamentsTypeFilter.generiques:
        return 'Médicaments génériques';
      case MedicamentsTypeFilter.usageProfessionnel:
        return 'Médicaments à usage professionnel';
    }
  }

  static String _pillLabel(MedicamentsTypeFilter? t) {
    if (t == null) return 'Statut';
    switch (t) {
      case MedicamentsTypeFilter.medicamentsException:
        return 'Exception';
      case MedicamentsTypeFilter.hypnotiques:
        return 'Hypnotiques';
      case MedicamentsTypeFilter.anxiolytiques:
        return 'Anxiolytiques';
      case MedicamentsTypeFilter.derivesDuSangMds:
        return 'Dérivés du sang';
      case MedicamentsTypeFilter.biosimilaires:
        return 'Biosimilaires';
      case MedicamentsTypeFilter.bioreferents:
        return 'Bioréférents';
      case MedicamentsTypeFilter.stupefiantsAssimiles:
        return 'Stupéfiants';
      case MedicamentsTypeFilter.liste1:
        return 'Liste 1';
      case MedicamentsTypeFilter.liste2:
        return 'Liste 2';
      case MedicamentsTypeFilter.hospitaliers:
        return 'Hospitaliers';
      case MedicamentsTypeFilter.surveillanceParticuliere:
        return 'Surveillance';
      case MedicamentsTypeFilter.prescriptionInitialeHospitaliere:
        return 'PIH';
      case MedicamentsTypeFilter.libreAccesOtc:
        return 'Libre accès';
      case MedicamentsTypeFilter.princeps:
        return 'Princeps';
      case MedicamentsTypeFilter.generiques:
        return 'Génériques';
      case MedicamentsTypeFilter.usageProfessionnel:
        return 'Usage pro';
    }
  }

  Future<void> _openMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight =
        box.localToGlobal(Offset(box.size.width, box.size.height));
    final pos = RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy,
      bottomRight.dx,
      topLeft.dy,
    );
    final orderedTypes = MedicamentsTypeFilter.values.toList()
      ..sort(
        (a, b) => normalizeLoose(_menuLabel(a)).compareTo(
          normalizeLoose(_menuLabel(b)),
        ),
      );
    final picked = await showMenu<MedicamentsTypeFilter>(
      context: context,
      position: pos,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        for (final t in orderedTypes)
          PopupMenuItem(
            value: t,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Tooltip(
              message:
                  '${_menuLabel(t)}\n\n${MedicamentsStatutSources.tooltip(t)}',
              preferBelow: false,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OffiboxColors.primary.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textStyle: const TextStyle(
                fontFamily: 'Spinnaker',
                fontSize: 11,
                color: OffiboxColors.primary,
                fontWeight: FontWeight.w600,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: OffiboxColors.primary.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  _menuLabel(t),
                  style: const TextStyle(
                    fontFamily: 'Spinnaker',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OffiboxColors.primary,
                    height: 1.12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (!mounted) return;
    if (picked == null) return;
    ref.read(medicamentsTypeFilterProvider.notifier).state = picked;
    ref.read(medicamentsSearchByProvider.notifier).state =
        MedicamentsSearchBy.nom;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(medicamentsTypeFilterProvider);
    return HoverPillButton(
      label: _pillLabel(selected),
      icon: Icons.tune,
      tooltip: selected == null
          ? 'Famille / statut réglementaire — choisissez puis appuyez sur Rechercher.'
          : '${MedicamentsStatutSources.tooltip(selected)}\n\n'
              'Appuyez sur Rechercher pour lister tous les produits de cette famille '
              '(tri alphabétique, données BDM).',
      height: widget.height,
      horizontalPadding: widget.horizontalPadding,
      labelFontSize: widget.labelFontSize,
      searchQuickTabBarStyle: true,
      quickTabSelected: selected != null,
      quickTabSelectedFilled: false,
      searchQuickTabLowercaseLabel: false,
      maxLabelWidth: 150,
      onTap: _openMenu,
    );
  }
}

class _MedicamentsLaboratoryDropdownPill extends ConsumerStatefulWidget {
  const _MedicamentsLaboratoryDropdownPill({
    required this.selected,
    required this.height,
    required this.horizontalPadding,
    required this.labelFontSize,
  });

  final String? selected;
  final double height;
  final double horizontalPadding;
  final double labelFontSize;

  @override
  ConsumerState<_MedicamentsLaboratoryDropdownPill> createState() =>
      _MedicamentsLaboratoryDropdownPillState();
}

class _MedicamentsLaboratoryDropdownPillState
    extends ConsumerState<_MedicamentsLaboratoryDropdownPill> {
  Future<void> _openDialog() async {
    final controller = ref.read(offiboxControllerProvider);
    final labs = controller.allResults
        .where((r) => r.source == SourceType.bdm)
        .map((r) => r.laboratory.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (labs.isEmpty) return;

    final pick = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _SearchablePickDialog(
        title: 'Fournisseur / laboratoire',
        hintText: 'Rechercher un fournisseur…',
        items: labs,
        initialQuery: widget.selected ?? '',
        itemTooltip: (s) =>
            '« $s » — libellé laboratoire tel que présent dans les données BDM locales. '
            'Rechercher sans autre critère : liste via le badge ou ce dialogue.',
      ),
    );
    if (!mounted) return;
    final chosen = pick?.trim();
    if (chosen == null || chosen.isEmpty) return;
    ref.read(medicamentsLaboratoryProvider.notifier).state = chosen;
    ref.read(medicamentsSearchByProvider.notifier).state =
        MedicamentsSearchBy.laboratoire;
    ref.read(medicamentsTypeFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(medicamentsLaboratoryProvider);
    final label = (selected == null || selected.trim().isEmpty)
        ? 'Laboratoires'
        : selected;
    return HoverPillButton(
      label: label,
      icon: Icons.science_outlined,
      tooltip:
          'Par laboratoire (liste)',
      height: widget.height,
      horizontalPadding: widget.horizontalPadding,
      labelFontSize: widget.labelFontSize,
      searchQuickTabBarStyle: true,
      quickTabSelected: selected != null,
      quickTabSelectedFilled: false,
      searchQuickTabLowercaseLabel: false,
      maxLabelWidth: 170,
      onTap: _openDialog,
    );
  }
}

class _MedicamentsManufacturerDropdownPill extends ConsumerStatefulWidget {
  const _MedicamentsManufacturerDropdownPill({
    required this.selected,
    required this.height,
    required this.horizontalPadding,
    required this.labelFontSize,
  });

  final String? selected;
  final double height;
  final double horizontalPadding;
  final double labelFontSize;

  @override
  ConsumerState<_MedicamentsManufacturerDropdownPill> createState() =>
      _MedicamentsManufacturerDropdownPillState();
}

class _MedicamentsManufacturerDropdownPillState
    extends ConsumerState<_MedicamentsManufacturerDropdownPill> {
  Future<void> _openDialog() async {
    final manufacturers = await ref.read(_medipimManufacturersProvider.future);
    if (!mounted || manufacturers.isEmpty) return;

    final pick = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _SearchablePickDialog(
        title: 'Laboratoires',
        hintText: 'Rechercher un laboratoire…',
        items: manufacturers,
        initialQuery: widget.selected ?? '',
        itemTooltip: (s) =>
            '« $s » — fournisseur issu du jeu Medipim (CSV médicaments du projet). '
            'Appuyez sur Rechercher pour lister tous les médicaments associés.',
      ),
    );
    if (!mounted) return;
    final chosen = pick?.trim();
    if (chosen == null || chosen.isEmpty) return;

    ref.read(medicamentsLaboratoryProvider.notifier).state = chosen;
    ref.read(medicamentsSearchByProvider.notifier).state =
        MedicamentsSearchBy.laboratoire;
    ref.read(medicamentsTypeFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(medicamentsLaboratoryProvider);
    final label = (selected == null || selected.trim().isEmpty)
        ? 'Laboratoires'
        : selected;
    return HoverPillButton(
      label: label,
      icon: Icons.factory_outlined,
      tooltip:
          'Laboratoires Medipim (CSV médicaments du projet). '
          'Choisissez un fournisseur puis appuyez sur Rechercher pour lister '
          'tous les médicaments (BDM local + Medipim si configuré).',
      height: widget.height,
      horizontalPadding: widget.horizontalPadding,
      labelFontSize: widget.labelFontSize,
      searchQuickTabBarStyle: true,
      quickTabSelected: selected != null,
      quickTabSelectedFilled: false,
      searchQuickTabLowercaseLabel: false,
      maxLabelWidth: 180,
      onTap: _openDialog,
    );
  }
}

class _SearchablePickDialog extends StatefulWidget {
  const _SearchablePickDialog({
    required this.title,
    required this.hintText,
    required this.items,
    this.initialQuery = '',
    this.itemTooltip,
  });

  final String title;
  final String hintText;
  final List<String> items;
  final String initialQuery;

  /// Infobulle style menu Statut (pill Offibox), une entrée par ligne.
  final String Function(String item)? itemTooltip;

  @override
  State<_SearchablePickDialog> createState() => _SearchablePickDialogState();
}

class _SearchablePickDialogState extends State<_SearchablePickDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<String> _filtered = const [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialQuery;
    _apply();
    _ctrl.addListener(_apply);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_apply);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply() {
    final q = _ctrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((s) => s.toLowerCase().contains(q))
            .toList();
      }
      if (_filtered.isNotEmpty) {
        _selected = _filtered.first;
      }
    });
  }

  void _submit() {
    final pick = _selected?.trim();
    if (pick == null || pick.isEmpty) return;
    Navigator.of(context).pop(pick);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final panelW = (w - 40).clamp(320.0, 520.0);
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: panelW,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'Spinnaker',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                style: const TextStyle(fontFamily: 'Spinnaker', fontSize: 13),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Aucun résultat',
                          style: TextStyle(fontFamily: 'Spinnaker'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final s = _filtered[i];
                          final selected = s == _selected;
                          final tip = widget.itemTooltip?.call(s);
                          final row = Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              hoverColor:
                                  OffiboxColors.primary.withValues(alpha: 0.08),
                              onTap: () {
                                setState(() => _selected = s);
                                _submit();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE8F5F4)
                                          .withValues(alpha: 0.55)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? OffiboxColors.primary
                                            .withValues(alpha: 0.35)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontFamily: 'Spinnaker',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (tip == null || tip.isEmpty) return row;
                          return Tooltip(
                            message: tip,
                            preferBelow: false,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    OffiboxColors.primary.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Spinnaker',
                              fontSize: 11,
                              color: OffiboxColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            child: row,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontFamily: 'Spinnaker'),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _submit,
                    child: const Text(
                      'Afficher',
                      style: TextStyle(fontFamily: 'Spinnaker'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
