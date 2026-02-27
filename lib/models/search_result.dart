// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

part 'search_result.freezed.dart';
part 'search_result.g.dart';

@Freezed(fromJson: true, toJson: true)
class SearchResult with _$SearchResult {
  const SearchResult._();

  const factory SearchResult({
    // 🔤 IDENTITÉ
    required String label,
    required String labelRaw,
    required SourceType source,
    required String laboratory,

    String? cip13,
    String? cis,

    // 🔥 AJOUTS
    String? cip7,
    String? groupLabel,

    // 📄 CONTENU
    @Default(false) bool isPdf,

    // 🟢 NSFP
    @Default(false) bool nsfp,
    String? nsfpDate,

    // 🔗 LIENS
    String? url,
    String? rcpVetoUrl,
    String? meddisparUrl,
    String? lppCode,

    // 📘 LPP — libellé, tarif (dernier par date validité), prix unitaire, montant max
    String? lppLibelle,
    double? lppTarif,
    double? lppPrixUnitaireReglemente,
    String? lppMontantMaxRemboursement,

    // ⚠️ STATUTS
    @Default(false) bool liste1,
    @Default(false) bool liste2,
    @Default(false) bool isStupefiant,
    @Default(false) bool isException,
    @Default(false) bool isOtc,
    @Default(false) bool hospitalOnly,

    @Default(false) bool isPih,
    @Default(false) bool isSurveillanceParticuliere,

    // 🩸 MDS
    @Default(false) bool isMds,

    // 🧬 BIOSIMILAIRE
    String? biosimilaireOf,
    @Default(false) bool isBioreferent,

    // 💊 GÉNÉRIQUE
    bool? isGeneric,
    String? princepsName,
    String? genericName,

    // 🏭 FOURNISSEUR
    String? iconUrl,
    String? phone,
    String? fax,
    String? email,
    String? catalogueUrl,
    String? commentaire,

    // 🆕 AMC
    String? address,
    String? website,

    // 🏷️ BADGES
    String? badge1Name,
    String? badge1Url,
    String? badge2Name,
    String? badge2Url,
    String? badge3Name,
    String? badge3Url,
    String? badge4Name,
    String? badge4Url,

    // 🟢🟠🔴 ANSM
    String? ansmStatut,
    String? ansmDate,
    String? ansmUrl,
  }) = _SearchResult;

  // 🔁 JSON avec normalisation
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final normalized = json.map((key, value) {
      if (value is String) {
        return MapEntry(key, normalizeText(value));
      }
      return MapEntry(key, value);
    });

    return _$SearchResultFromJson(normalized);
  }

  // ─────────────────────────────
  // 🔥 GETTERS MANQUANTS (STABILITÉ PROJET)
  // ─────────────────────────────

  /// NSFP actif
  bool get isNsfpEffective => nsfp == true;

  /// Organisme AMC
  bool get isOrganisme => source == SourceType.amc;

  /// Produit inactif
  bool get isInactive => false; // à adapter si besoin réel

  /// Label normalisé recherche
  String get labelNorm => _normalize(label);

  /// CIP normalisé recherche
  String get cipNorm => cip13 != null ? _normalize(cip13!) : '';

  // ⚡ NORMALISATION
  String get normalizedLabel => _normalize(label);

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâ]'), 'a')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ô]'), 'o')
        .replaceAll(RegExp('[ùû]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
