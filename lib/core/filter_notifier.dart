import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offibox/core/search_filter.dart';
import 'package:offibox/models/source_type.dart';

final searchFilterProvider =
    StateNotifierProvider<SearchFilterNotifier, SearchFilter>((ref) {
  return SearchFilterNotifier();
});

class SearchFilterNotifier extends StateNotifier<SearchFilter> {
  SearchFilterNotifier() : super(const SearchFilter());

  void toggleSourceDisabled(SourceType source) {
    state = state.toggleSourceDisabled(source);
  }

  /// Réactive une source (enlève du set des masquées). Utilisé pour "rebrancher" les médicaments.
  void enableSource(SourceType source) {
    if (!state.disabledSources.contains(source)) return;
    state = state.toggleSourceDisabled(source);
  }

  void setHideNsfp(bool value) {
    state = state.copyWith(hideNsfp: value);
  }

  void setHideHospitalOnly(bool value) {
    state = state.copyWith(hideHospitalOnly: value);
  }

  /// Réinitialise les sous-filtres BDM (ex. quand on désactive la source BDM).
  void clearBdmSubFilters() {
    state = state.copyWith(bdmOnlySubFilters: const {}, genericLaboratory: null);
  }

  /// Ajoute ou retire une catégorie BDM (plusieurs sélections possibles).
  void toggleBdmSubFilter(BdmSubFilter sub) {
    final next = Set<BdmSubFilter>.from(state.bdmOnlySubFilters);
    if (next.contains(sub)) {
      next.remove(sub);
    } else {
      next.add(sub);
    }
    state = state.copyWith(
      bdmOnlySubFilters: next,
      genericLaboratory: next.contains(BdmSubFilter.generiques) ? state.genericLaboratory : null,
    );
  }

  /// Sous-filtre génériques par laboratoire (affiche uniquement les génériques de ce labo).
  /// Passer null pour afficher tous les génériques.
  void setGenericLaboratory(String? lab) {
    if (lab != null) {
      final next = Set<BdmSubFilter>.from(state.bdmOnlySubFilters)..add(BdmSubFilter.generiques);
      state = state.copyWith(
        genericLaboratory: lab,
        bdmOnlySubFilters: next,
      );
    } else {
      state = SearchFilter(
        disabledSources: state.disabledSources,
        hideNsfp: state.hideNsfp,
        hideHospitalOnly: state.hideHospitalOnly,
        bdmOnlySubFilters: state.bdmOnlySubFilters,
        genericLaboratory: null,
      );
    }
  }

  /// Réinitialise : toutes les sources activées, masquer NSFP et hopital coché, sous-filtres vidés.
  void reset() {
    state = const SearchFilter();
  }
}
