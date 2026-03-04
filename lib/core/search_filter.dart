import 'package:flutter/foundation.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/search/mte_molecules.dart';

/// Sous-filtre BDM (Médicaments) : une seule catégorie à la fois.
enum BdmSubFilter {
  generiques,
  stupefiants,
  mds,
  mte,
  biosimilaires,
  otc,
}

/// État des filtres de recherche (sources masquées, NSFP, hospitalier, sous-filtre BDM).
/// disabledSources vide = toutes les sources affichées.
/// Par défaut : masquer NSFP et CIP hospitaliers (source = col 6 du CSV stupéfiants+hopital 202026).
@immutable
class SearchFilter {
  const SearchFilter({
    this.disabledSources = const {},
    this.hideNsfp = true,
    this.hideHospitalOnly = true,
    this.bdmOnlySubFilters = const {},
    this.genericLaboratory,
  });

  /// Sources à exclure des résultats (cochées = masquées).
  final Set<SourceType> disabledSources;
  final bool hideNsfp;
  final bool hideHospitalOnly;

  /// Si non vide, n'afficher que les BDM appartenant à au moins une de ces catégories (plusieurs choix possibles).
  final Set<BdmSubFilter> bdmOnlySubFilters;

  /// Sous-filtre génériques : n'afficher que les génériques de ce laboratoire (ex. SANOFI).
  final String? genericLaboratory;

  bool get hasActiveFilters =>
      disabledSources.isNotEmpty ||
      hideNsfp ||
      hideHospitalOnly ||
      bdmOnlySubFilters.isNotEmpty ||
      genericLaboratory != null;

  SearchFilter copyWith({
    Set<SourceType>? disabledSources,
    bool? hideNsfp,
    bool? hideHospitalOnly,
    Set<BdmSubFilter>? bdmOnlySubFilters,
    String? genericLaboratory,
  }) {
    return SearchFilter(
      disabledSources: disabledSources ?? this.disabledSources,
      hideNsfp: hideNsfp ?? this.hideNsfp,
      hideHospitalOnly: hideHospitalOnly ?? this.hideHospitalOnly,
      bdmOnlySubFilters: bdmOnlySubFilters ?? this.bdmOnlySubFilters,
      genericLaboratory: genericLaboratory ?? this.genericLaboratory,
    );
  }

  /// Toggle une source (si déjà masquée on l'affiche, sinon on la masque).
  SearchFilter toggleSourceDisabled(SourceType source) {
    final next = Set<SourceType>.from(disabledSources);
    if (next.contains(source)) {
      next.remove(source);
    } else {
      next.add(source);
    }
    return copyWith(disabledSources: next);
  }

  bool isSourceEnabled(SourceType source) {
    return !disabledSources.contains(source);
  }

  static bool _bdmMatchesSubFilter(
    SearchResult r,
    BdmSubFilter sub, {
    Set<String>? genericCipSet,
  }) {
    switch (sub) {
      case BdmSubFilter.generiques:
        if (genericCipSet != null && genericCipSet.isNotEmpty) {
          return r.source == SourceType.bdm &&
              r.cip13 != null &&
              genericCipSet.contains(r.cip13);
        }
        return r.isGeneric == true;
      case BdmSubFilter.stupefiants:
        return r.isStupefiant == true || r.liste1 == true || r.liste2 == true;
      case BdmSubFilter.mds:
        return r.isMds == true;
      case BdmSubFilter.mte:
        return isMteMolecule(r);
      case BdmSubFilter.biosimilaires:
        return r.biosimilaireOf != null && r.biosimilaireOf!.isNotEmpty;
      case BdmSubFilter.otc:
        return r.isOtc == true;
    }
  }

  /// Applique ce filtre à une liste de résultats (sans modifier l'original).
  /// Si [genericCipSet] est fourni, le sous-filtre « Génériques » ne garde que les BDM dont le CIP13 est dans ce set (fichier generiques_ansm.csv).
  /// Si [cisArretCommercialisation] est fourni, les médicaments NSFP dont le CIS est dans ce set restent affichés (badge « arrêt de commercialisation »).
  List<SearchResult> applyTo(
    List<SearchResult> results, {
    Set<String>? genericCipSet,
    Set<String>? cisArretCommercialisation,
  }) {
    var out = results;
    if (disabledSources.isNotEmpty) {
      out = out.where((r) => !disabledSources.contains(r.source)).toList();
    }
    if (hideNsfp) {
      out = out.where((r) {
        if (!r.isNsfpEffective) return true;
        final cisKey = r.cis?.replaceAll(RegExp(r'\D'), '').trim();
        if (cisKey == null || cisKey.isEmpty) return false;
        return cisArretCommercialisation?.contains(cisKey) == true;
      }).toList();
    }
    if (hideHospitalOnly) {
      out = out.where((r) => r.hospitalOnly != true).toList();
    }
    if (bdmOnlySubFilters.isNotEmpty) {
      out = out.where((r) {
        if (r.source != SourceType.bdm) return true;
        for (final sub in bdmOnlySubFilters) {
          if (!_bdmMatchesSubFilter(r, sub, genericCipSet: genericCipSet)) continue;
          if (sub == BdmSubFilter.generiques && genericLaboratory != null && genericLaboratory!.isNotEmpty) {
            final lab = genericLaboratory!.trim().toUpperCase();
            final label = r.labelRaw.toUpperCase();
            if (!label.contains(lab)) continue;
          }
          return true;
        }
        return false;
      }).toList();
    }
    return out;
  }
}
