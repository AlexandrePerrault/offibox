// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) {
  return _SearchResult.fromJson(json);
}

/// @nodoc
mixin _$SearchResult {
// 🔤 IDENTITÉ
  String get label => throw _privateConstructorUsedError;
  String get labelRaw => throw _privateConstructorUsedError;
  SourceType get source => throw _privateConstructorUsedError;
  String get laboratory => throw _privateConstructorUsedError;
  String? get cip13 => throw _privateConstructorUsedError;
  String? get cis => throw _privateConstructorUsedError; // 🔥 AJOUTS
  String? get cip7 => throw _privateConstructorUsedError;
  String? get groupLabel => throw _privateConstructorUsedError;

  /// Département d'exercice (ex: "75", "33", "971") quand disponible.
  String? get departement => throw _privateConstructorUsedError; // 📄 CONTENU
  bool get isPdf => throw _privateConstructorUsedError; // 🟢 NSFP
  bool get nsfp => throw _privateConstructorUsedError;
  String? get nsfpDate => throw _privateConstructorUsedError; // 🔗 LIENS
  String? get url => throw _privateConstructorUsedError;
  String? get rcpVetoUrl => throw _privateConstructorUsedError;
  String? get meddisparUrl => throw _privateConstructorUsedError;
  String? get lppCode =>
      throw _privateConstructorUsedError; // 📘 LPP — libellé, tarif (dernier par date validité), prix unitaire, montant max
  String? get lppLibelle => throw _privateConstructorUsedError;
  double? get lppTarif => throw _privateConstructorUsedError;
  double? get lppPrixUnitaireReglemente => throw _privateConstructorUsedError;
  String? get lppMontantMaxRemboursement =>
      throw _privateConstructorUsedError; // ⚠️ STATUTS
  bool get liste1 => throw _privateConstructorUsedError;
  bool get liste2 => throw _privateConstructorUsedError;
  bool get isStupefiant => throw _privateConstructorUsedError;
  bool get isException => throw _privateConstructorUsedError;
  bool get isOtc => throw _privateConstructorUsedError;
  bool get hospitalOnly => throw _privateConstructorUsedError;
  bool get isPih => throw _privateConstructorUsedError;
  bool get isSurveillanceParticuliere =>
      throw _privateConstructorUsedError; // 🩸 MDS
  bool get isMds => throw _privateConstructorUsedError; // 🧬 BIOSIMILAIRE
  String? get biosimilaireOf => throw _privateConstructorUsedError;
  bool get isBioreferent => throw _privateConstructorUsedError; // 💊 GÉNÉRIQUE
  bool? get isGeneric => throw _privateConstructorUsedError;
  String? get princepsName => throw _privateConstructorUsedError;
  String? get genericName =>
      throw _privateConstructorUsedError; // 🏭 FOURNISSEUR
  String? get iconUrl => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get fax => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;

  /// BAL MSSanté personnelle (si trouvée via dataset Annuaire Santé).
  String? get mssanteEmail => throw _privateConstructorUsedError;
  String? get catalogueUrl => throw _privateConstructorUsedError;
  String? get commentaire => throw _privateConstructorUsedError; // 🆕 AMC
  String? get address => throw _privateConstructorUsedError;
  String? get website => throw _privateConstructorUsedError;

  /// Date d'apparition outil (outils métier, col C) — affiche "nouveau (date)" à droite du libellé.
  String? get keywordAppearanceDate =>
      throw _privateConstructorUsedError; // 🏷️ BADGES
  String? get badge1Name => throw _privateConstructorUsedError;
  String? get badge1Url => throw _privateConstructorUsedError;
  String? get badge2Name => throw _privateConstructorUsedError;
  String? get badge2Url => throw _privateConstructorUsedError;
  String? get badge3Name => throw _privateConstructorUsedError;
  String? get badge3Url => throw _privateConstructorUsedError;
  String? get badge4Name => throw _privateConstructorUsedError;
  String? get badge4Url => throw _privateConstructorUsedError; // 🟢🟠🔴 ANSM
  String? get ansmStatut => throw _privateConstructorUsedError;
  String? get ansmDate => throw _privateConstructorUsedError;
  String? get ansmUrl => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
          SearchResult value, $Res Function(SearchResult) then) =
      _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call(
      {String label,
      String labelRaw,
      SourceType source,
      String laboratory,
      String? cip13,
      String? cis,
      String? cip7,
      String? groupLabel,
      String? departement,
      bool isPdf,
      bool nsfp,
      String? nsfpDate,
      String? url,
      String? rcpVetoUrl,
      String? meddisparUrl,
      String? lppCode,
      String? lppLibelle,
      double? lppTarif,
      double? lppPrixUnitaireReglemente,
      String? lppMontantMaxRemboursement,
      bool liste1,
      bool liste2,
      bool isStupefiant,
      bool isException,
      bool isOtc,
      bool hospitalOnly,
      bool isPih,
      bool isSurveillanceParticuliere,
      bool isMds,
      String? biosimilaireOf,
      bool isBioreferent,
      bool? isGeneric,
      String? princepsName,
      String? genericName,
      String? iconUrl,
      String? phone,
      String? fax,
      String? email,
      String? mssanteEmail,
      String? catalogueUrl,
      String? commentaire,
      String? address,
      String? website,
      String? keywordAppearanceDate,
      String? badge1Name,
      String? badge1Url,
      String? badge2Name,
      String? badge2Url,
      String? badge3Name,
      String? badge3Url,
      String? badge4Name,
      String? badge4Url,
      String? ansmStatut,
      String? ansmDate,
      String? ansmUrl});
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? labelRaw = null,
    Object? source = null,
    Object? laboratory = null,
    Object? cip13 = freezed,
    Object? cis = freezed,
    Object? cip7 = freezed,
    Object? groupLabel = freezed,
    Object? departement = freezed,
    Object? isPdf = null,
    Object? nsfp = null,
    Object? nsfpDate = freezed,
    Object? url = freezed,
    Object? rcpVetoUrl = freezed,
    Object? meddisparUrl = freezed,
    Object? lppCode = freezed,
    Object? lppLibelle = freezed,
    Object? lppTarif = freezed,
    Object? lppPrixUnitaireReglemente = freezed,
    Object? lppMontantMaxRemboursement = freezed,
    Object? liste1 = null,
    Object? liste2 = null,
    Object? isStupefiant = null,
    Object? isException = null,
    Object? isOtc = null,
    Object? hospitalOnly = null,
    Object? isPih = null,
    Object? isSurveillanceParticuliere = null,
    Object? isMds = null,
    Object? biosimilaireOf = freezed,
    Object? isBioreferent = null,
    Object? isGeneric = freezed,
    Object? princepsName = freezed,
    Object? genericName = freezed,
    Object? iconUrl = freezed,
    Object? phone = freezed,
    Object? fax = freezed,
    Object? email = freezed,
    Object? mssanteEmail = freezed,
    Object? catalogueUrl = freezed,
    Object? commentaire = freezed,
    Object? address = freezed,
    Object? website = freezed,
    Object? keywordAppearanceDate = freezed,
    Object? badge1Name = freezed,
    Object? badge1Url = freezed,
    Object? badge2Name = freezed,
    Object? badge2Url = freezed,
    Object? badge3Name = freezed,
    Object? badge3Url = freezed,
    Object? badge4Name = freezed,
    Object? badge4Url = freezed,
    Object? ansmStatut = freezed,
    Object? ansmDate = freezed,
    Object? ansmUrl = freezed,
  }) {
    return _then(_value.copyWith(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      labelRaw: null == labelRaw
          ? _value.labelRaw
          : labelRaw // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as SourceType,
      laboratory: null == laboratory
          ? _value.laboratory
          : laboratory // ignore: cast_nullable_to_non_nullable
              as String,
      cip13: freezed == cip13
          ? _value.cip13
          : cip13 // ignore: cast_nullable_to_non_nullable
              as String?,
      cis: freezed == cis
          ? _value.cis
          : cis // ignore: cast_nullable_to_non_nullable
              as String?,
      cip7: freezed == cip7
          ? _value.cip7
          : cip7 // ignore: cast_nullable_to_non_nullable
              as String?,
      groupLabel: freezed == groupLabel
          ? _value.groupLabel
          : groupLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      departement: freezed == departement
          ? _value.departement
          : departement // ignore: cast_nullable_to_non_nullable
              as String?,
      isPdf: null == isPdf
          ? _value.isPdf
          : isPdf // ignore: cast_nullable_to_non_nullable
              as bool,
      nsfp: null == nsfp
          ? _value.nsfp
          : nsfp // ignore: cast_nullable_to_non_nullable
              as bool,
      nsfpDate: freezed == nsfpDate
          ? _value.nsfpDate
          : nsfpDate // ignore: cast_nullable_to_non_nullable
              as String?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
      rcpVetoUrl: freezed == rcpVetoUrl
          ? _value.rcpVetoUrl
          : rcpVetoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      meddisparUrl: freezed == meddisparUrl
          ? _value.meddisparUrl
          : meddisparUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      lppCode: freezed == lppCode
          ? _value.lppCode
          : lppCode // ignore: cast_nullable_to_non_nullable
              as String?,
      lppLibelle: freezed == lppLibelle
          ? _value.lppLibelle
          : lppLibelle // ignore: cast_nullable_to_non_nullable
              as String?,
      lppTarif: freezed == lppTarif
          ? _value.lppTarif
          : lppTarif // ignore: cast_nullable_to_non_nullable
              as double?,
      lppPrixUnitaireReglemente: freezed == lppPrixUnitaireReglemente
          ? _value.lppPrixUnitaireReglemente
          : lppPrixUnitaireReglemente // ignore: cast_nullable_to_non_nullable
              as double?,
      lppMontantMaxRemboursement: freezed == lppMontantMaxRemboursement
          ? _value.lppMontantMaxRemboursement
          : lppMontantMaxRemboursement // ignore: cast_nullable_to_non_nullable
              as String?,
      liste1: null == liste1
          ? _value.liste1
          : liste1 // ignore: cast_nullable_to_non_nullable
              as bool,
      liste2: null == liste2
          ? _value.liste2
          : liste2 // ignore: cast_nullable_to_non_nullable
              as bool,
      isStupefiant: null == isStupefiant
          ? _value.isStupefiant
          : isStupefiant // ignore: cast_nullable_to_non_nullable
              as bool,
      isException: null == isException
          ? _value.isException
          : isException // ignore: cast_nullable_to_non_nullable
              as bool,
      isOtc: null == isOtc
          ? _value.isOtc
          : isOtc // ignore: cast_nullable_to_non_nullable
              as bool,
      hospitalOnly: null == hospitalOnly
          ? _value.hospitalOnly
          : hospitalOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      isPih: null == isPih
          ? _value.isPih
          : isPih // ignore: cast_nullable_to_non_nullable
              as bool,
      isSurveillanceParticuliere: null == isSurveillanceParticuliere
          ? _value.isSurveillanceParticuliere
          : isSurveillanceParticuliere // ignore: cast_nullable_to_non_nullable
              as bool,
      isMds: null == isMds
          ? _value.isMds
          : isMds // ignore: cast_nullable_to_non_nullable
              as bool,
      biosimilaireOf: freezed == biosimilaireOf
          ? _value.biosimilaireOf
          : biosimilaireOf // ignore: cast_nullable_to_non_nullable
              as String?,
      isBioreferent: null == isBioreferent
          ? _value.isBioreferent
          : isBioreferent // ignore: cast_nullable_to_non_nullable
              as bool,
      isGeneric: freezed == isGeneric
          ? _value.isGeneric
          : isGeneric // ignore: cast_nullable_to_non_nullable
              as bool?,
      princepsName: freezed == princepsName
          ? _value.princepsName
          : princepsName // ignore: cast_nullable_to_non_nullable
              as String?,
      genericName: freezed == genericName
          ? _value.genericName
          : genericName // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _value.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      fax: freezed == fax
          ? _value.fax
          : fax // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      mssanteEmail: freezed == mssanteEmail
          ? _value.mssanteEmail
          : mssanteEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      catalogueUrl: freezed == catalogueUrl
          ? _value.catalogueUrl
          : catalogueUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentaire: freezed == commentaire
          ? _value.commentaire
          : commentaire // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      keywordAppearanceDate: freezed == keywordAppearanceDate
          ? _value.keywordAppearanceDate
          : keywordAppearanceDate // ignore: cast_nullable_to_non_nullable
              as String?,
      badge1Name: freezed == badge1Name
          ? _value.badge1Name
          : badge1Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge1Url: freezed == badge1Url
          ? _value.badge1Url
          : badge1Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge2Name: freezed == badge2Name
          ? _value.badge2Name
          : badge2Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge2Url: freezed == badge2Url
          ? _value.badge2Url
          : badge2Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge3Name: freezed == badge3Name
          ? _value.badge3Name
          : badge3Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge3Url: freezed == badge3Url
          ? _value.badge3Url
          : badge3Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge4Name: freezed == badge4Name
          ? _value.badge4Name
          : badge4Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge4Url: freezed == badge4Url
          ? _value.badge4Url
          : badge4Url // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmStatut: freezed == ansmStatut
          ? _value.ansmStatut
          : ansmStatut // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmDate: freezed == ansmDate
          ? _value.ansmDate
          : ansmDate // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmUrl: freezed == ansmUrl
          ? _value.ansmUrl
          : ansmUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
          _$SearchResultImpl value, $Res Function(_$SearchResultImpl) then) =
      __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String label,
      String labelRaw,
      SourceType source,
      String laboratory,
      String? cip13,
      String? cis,
      String? cip7,
      String? groupLabel,
      String? departement,
      bool isPdf,
      bool nsfp,
      String? nsfpDate,
      String? url,
      String? rcpVetoUrl,
      String? meddisparUrl,
      String? lppCode,
      String? lppLibelle,
      double? lppTarif,
      double? lppPrixUnitaireReglemente,
      String? lppMontantMaxRemboursement,
      bool liste1,
      bool liste2,
      bool isStupefiant,
      bool isException,
      bool isOtc,
      bool hospitalOnly,
      bool isPih,
      bool isSurveillanceParticuliere,
      bool isMds,
      String? biosimilaireOf,
      bool isBioreferent,
      bool? isGeneric,
      String? princepsName,
      String? genericName,
      String? iconUrl,
      String? phone,
      String? fax,
      String? email,
      String? mssanteEmail,
      String? catalogueUrl,
      String? commentaire,
      String? address,
      String? website,
      String? keywordAppearanceDate,
      String? badge1Name,
      String? badge1Url,
      String? badge2Name,
      String? badge2Url,
      String? badge3Name,
      String? badge3Url,
      String? badge4Name,
      String? badge4Url,
      String? ansmStatut,
      String? ansmDate,
      String? ansmUrl});
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
      _$SearchResultImpl _value, $Res Function(_$SearchResultImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? labelRaw = null,
    Object? source = null,
    Object? laboratory = null,
    Object? cip13 = freezed,
    Object? cis = freezed,
    Object? cip7 = freezed,
    Object? groupLabel = freezed,
    Object? departement = freezed,
    Object? isPdf = null,
    Object? nsfp = null,
    Object? nsfpDate = freezed,
    Object? url = freezed,
    Object? rcpVetoUrl = freezed,
    Object? meddisparUrl = freezed,
    Object? lppCode = freezed,
    Object? lppLibelle = freezed,
    Object? lppTarif = freezed,
    Object? lppPrixUnitaireReglemente = freezed,
    Object? lppMontantMaxRemboursement = freezed,
    Object? liste1 = null,
    Object? liste2 = null,
    Object? isStupefiant = null,
    Object? isException = null,
    Object? isOtc = null,
    Object? hospitalOnly = null,
    Object? isPih = null,
    Object? isSurveillanceParticuliere = null,
    Object? isMds = null,
    Object? biosimilaireOf = freezed,
    Object? isBioreferent = null,
    Object? isGeneric = freezed,
    Object? princepsName = freezed,
    Object? genericName = freezed,
    Object? iconUrl = freezed,
    Object? phone = freezed,
    Object? fax = freezed,
    Object? email = freezed,
    Object? mssanteEmail = freezed,
    Object? catalogueUrl = freezed,
    Object? commentaire = freezed,
    Object? address = freezed,
    Object? website = freezed,
    Object? keywordAppearanceDate = freezed,
    Object? badge1Name = freezed,
    Object? badge1Url = freezed,
    Object? badge2Name = freezed,
    Object? badge2Url = freezed,
    Object? badge3Name = freezed,
    Object? badge3Url = freezed,
    Object? badge4Name = freezed,
    Object? badge4Url = freezed,
    Object? ansmStatut = freezed,
    Object? ansmDate = freezed,
    Object? ansmUrl = freezed,
  }) {
    return _then(_$SearchResultImpl(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      labelRaw: null == labelRaw
          ? _value.labelRaw
          : labelRaw // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as SourceType,
      laboratory: null == laboratory
          ? _value.laboratory
          : laboratory // ignore: cast_nullable_to_non_nullable
              as String,
      cip13: freezed == cip13
          ? _value.cip13
          : cip13 // ignore: cast_nullable_to_non_nullable
              as String?,
      cis: freezed == cis
          ? _value.cis
          : cis // ignore: cast_nullable_to_non_nullable
              as String?,
      cip7: freezed == cip7
          ? _value.cip7
          : cip7 // ignore: cast_nullable_to_non_nullable
              as String?,
      groupLabel: freezed == groupLabel
          ? _value.groupLabel
          : groupLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      departement: freezed == departement
          ? _value.departement
          : departement // ignore: cast_nullable_to_non_nullable
              as String?,
      isPdf: null == isPdf
          ? _value.isPdf
          : isPdf // ignore: cast_nullable_to_non_nullable
              as bool,
      nsfp: null == nsfp
          ? _value.nsfp
          : nsfp // ignore: cast_nullable_to_non_nullable
              as bool,
      nsfpDate: freezed == nsfpDate
          ? _value.nsfpDate
          : nsfpDate // ignore: cast_nullable_to_non_nullable
              as String?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
      rcpVetoUrl: freezed == rcpVetoUrl
          ? _value.rcpVetoUrl
          : rcpVetoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      meddisparUrl: freezed == meddisparUrl
          ? _value.meddisparUrl
          : meddisparUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      lppCode: freezed == lppCode
          ? _value.lppCode
          : lppCode // ignore: cast_nullable_to_non_nullable
              as String?,
      lppLibelle: freezed == lppLibelle
          ? _value.lppLibelle
          : lppLibelle // ignore: cast_nullable_to_non_nullable
              as String?,
      lppTarif: freezed == lppTarif
          ? _value.lppTarif
          : lppTarif // ignore: cast_nullable_to_non_nullable
              as double?,
      lppPrixUnitaireReglemente: freezed == lppPrixUnitaireReglemente
          ? _value.lppPrixUnitaireReglemente
          : lppPrixUnitaireReglemente // ignore: cast_nullable_to_non_nullable
              as double?,
      lppMontantMaxRemboursement: freezed == lppMontantMaxRemboursement
          ? _value.lppMontantMaxRemboursement
          : lppMontantMaxRemboursement // ignore: cast_nullable_to_non_nullable
              as String?,
      liste1: null == liste1
          ? _value.liste1
          : liste1 // ignore: cast_nullable_to_non_nullable
              as bool,
      liste2: null == liste2
          ? _value.liste2
          : liste2 // ignore: cast_nullable_to_non_nullable
              as bool,
      isStupefiant: null == isStupefiant
          ? _value.isStupefiant
          : isStupefiant // ignore: cast_nullable_to_non_nullable
              as bool,
      isException: null == isException
          ? _value.isException
          : isException // ignore: cast_nullable_to_non_nullable
              as bool,
      isOtc: null == isOtc
          ? _value.isOtc
          : isOtc // ignore: cast_nullable_to_non_nullable
              as bool,
      hospitalOnly: null == hospitalOnly
          ? _value.hospitalOnly
          : hospitalOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      isPih: null == isPih
          ? _value.isPih
          : isPih // ignore: cast_nullable_to_non_nullable
              as bool,
      isSurveillanceParticuliere: null == isSurveillanceParticuliere
          ? _value.isSurveillanceParticuliere
          : isSurveillanceParticuliere // ignore: cast_nullable_to_non_nullable
              as bool,
      isMds: null == isMds
          ? _value.isMds
          : isMds // ignore: cast_nullable_to_non_nullable
              as bool,
      biosimilaireOf: freezed == biosimilaireOf
          ? _value.biosimilaireOf
          : biosimilaireOf // ignore: cast_nullable_to_non_nullable
              as String?,
      isBioreferent: null == isBioreferent
          ? _value.isBioreferent
          : isBioreferent // ignore: cast_nullable_to_non_nullable
              as bool,
      isGeneric: freezed == isGeneric
          ? _value.isGeneric
          : isGeneric // ignore: cast_nullable_to_non_nullable
              as bool?,
      princepsName: freezed == princepsName
          ? _value.princepsName
          : princepsName // ignore: cast_nullable_to_non_nullable
              as String?,
      genericName: freezed == genericName
          ? _value.genericName
          : genericName // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _value.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      phone: freezed == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String?,
      fax: freezed == fax
          ? _value.fax
          : fax // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      mssanteEmail: freezed == mssanteEmail
          ? _value.mssanteEmail
          : mssanteEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      catalogueUrl: freezed == catalogueUrl
          ? _value.catalogueUrl
          : catalogueUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentaire: freezed == commentaire
          ? _value.commentaire
          : commentaire // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      keywordAppearanceDate: freezed == keywordAppearanceDate
          ? _value.keywordAppearanceDate
          : keywordAppearanceDate // ignore: cast_nullable_to_non_nullable
              as String?,
      badge1Name: freezed == badge1Name
          ? _value.badge1Name
          : badge1Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge1Url: freezed == badge1Url
          ? _value.badge1Url
          : badge1Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge2Name: freezed == badge2Name
          ? _value.badge2Name
          : badge2Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge2Url: freezed == badge2Url
          ? _value.badge2Url
          : badge2Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge3Name: freezed == badge3Name
          ? _value.badge3Name
          : badge3Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge3Url: freezed == badge3Url
          ? _value.badge3Url
          : badge3Url // ignore: cast_nullable_to_non_nullable
              as String?,
      badge4Name: freezed == badge4Name
          ? _value.badge4Name
          : badge4Name // ignore: cast_nullable_to_non_nullable
              as String?,
      badge4Url: freezed == badge4Url
          ? _value.badge4Url
          : badge4Url // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmStatut: freezed == ansmStatut
          ? _value.ansmStatut
          : ansmStatut // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmDate: freezed == ansmDate
          ? _value.ansmDate
          : ansmDate // ignore: cast_nullable_to_non_nullable
              as String?,
      ansmUrl: freezed == ansmUrl
          ? _value.ansmUrl
          : ansmUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchResultImpl extends _SearchResult {
  const _$SearchResultImpl(
      {required this.label,
      required this.labelRaw,
      required this.source,
      required this.laboratory,
      this.cip13,
      this.cis,
      this.cip7,
      this.groupLabel,
      this.departement,
      this.isPdf = false,
      this.nsfp = false,
      this.nsfpDate,
      this.url,
      this.rcpVetoUrl,
      this.meddisparUrl,
      this.lppCode,
      this.lppLibelle,
      this.lppTarif,
      this.lppPrixUnitaireReglemente,
      this.lppMontantMaxRemboursement,
      this.liste1 = false,
      this.liste2 = false,
      this.isStupefiant = false,
      this.isException = false,
      this.isOtc = false,
      this.hospitalOnly = false,
      this.isPih = false,
      this.isSurveillanceParticuliere = false,
      this.isMds = false,
      this.biosimilaireOf,
      this.isBioreferent = false,
      this.isGeneric,
      this.princepsName,
      this.genericName,
      this.iconUrl,
      this.phone,
      this.fax,
      this.email,
      this.mssanteEmail,
      this.catalogueUrl,
      this.commentaire,
      this.address,
      this.website,
      this.keywordAppearanceDate,
      this.badge1Name,
      this.badge1Url,
      this.badge2Name,
      this.badge2Url,
      this.badge3Name,
      this.badge3Url,
      this.badge4Name,
      this.badge4Url,
      this.ansmStatut,
      this.ansmDate,
      this.ansmUrl})
      : super._();

  factory _$SearchResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResultImplFromJson(json);

// 🔤 IDENTITÉ
  @override
  final String label;
  @override
  final String labelRaw;
  @override
  final SourceType source;
  @override
  final String laboratory;
  @override
  final String? cip13;
  @override
  final String? cis;
// 🔥 AJOUTS
  @override
  final String? cip7;
  @override
  final String? groupLabel;

  /// Département d'exercice (ex: "75", "33", "971") quand disponible.
  @override
  final String? departement;
// 📄 CONTENU
  @override
  @JsonKey()
  final bool isPdf;
// 🟢 NSFP
  @override
  @JsonKey()
  final bool nsfp;
  @override
  final String? nsfpDate;
// 🔗 LIENS
  @override
  final String? url;
  @override
  final String? rcpVetoUrl;
  @override
  final String? meddisparUrl;
  @override
  final String? lppCode;
// 📘 LPP — libellé, tarif (dernier par date validité), prix unitaire, montant max
  @override
  final String? lppLibelle;
  @override
  final double? lppTarif;
  @override
  final double? lppPrixUnitaireReglemente;
  @override
  final String? lppMontantMaxRemboursement;
// ⚠️ STATUTS
  @override
  @JsonKey()
  final bool liste1;
  @override
  @JsonKey()
  final bool liste2;
  @override
  @JsonKey()
  final bool isStupefiant;
  @override
  @JsonKey()
  final bool isException;
  @override
  @JsonKey()
  final bool isOtc;
  @override
  @JsonKey()
  final bool hospitalOnly;
  @override
  @JsonKey()
  final bool isPih;
  @override
  @JsonKey()
  final bool isSurveillanceParticuliere;
// 🩸 MDS
  @override
  @JsonKey()
  final bool isMds;
// 🧬 BIOSIMILAIRE
  @override
  final String? biosimilaireOf;
  @override
  @JsonKey()
  final bool isBioreferent;
// 💊 GÉNÉRIQUE
  @override
  final bool? isGeneric;
  @override
  final String? princepsName;
  @override
  final String? genericName;
// 🏭 FOURNISSEUR
  @override
  final String? iconUrl;
  @override
  final String? phone;
  @override
  final String? fax;
  @override
  final String? email;

  /// BAL MSSanté personnelle (si trouvée via dataset Annuaire Santé).
  @override
  final String? mssanteEmail;
  @override
  final String? catalogueUrl;
  @override
  final String? commentaire;
// 🆕 AMC
  @override
  final String? address;
  @override
  final String? website;

  /// Date d'apparition outil (outils métier, col C) — affiche "nouveau (date)" à droite du libellé.
  @override
  final String? keywordAppearanceDate;
// 🏷️ BADGES
  @override
  final String? badge1Name;
  @override
  final String? badge1Url;
  @override
  final String? badge2Name;
  @override
  final String? badge2Url;
  @override
  final String? badge3Name;
  @override
  final String? badge3Url;
  @override
  final String? badge4Name;
  @override
  final String? badge4Url;
// 🟢🟠🔴 ANSM
  @override
  final String? ansmStatut;
  @override
  final String? ansmDate;
  @override
  final String? ansmUrl;

  @override
  String toString() {
    return 'SearchResult(label: $label, labelRaw: $labelRaw, source: $source, laboratory: $laboratory, cip13: $cip13, cis: $cis, cip7: $cip7, groupLabel: $groupLabel, departement: $departement, isPdf: $isPdf, nsfp: $nsfp, nsfpDate: $nsfpDate, url: $url, rcpVetoUrl: $rcpVetoUrl, meddisparUrl: $meddisparUrl, lppCode: $lppCode, lppLibelle: $lppLibelle, lppTarif: $lppTarif, lppPrixUnitaireReglemente: $lppPrixUnitaireReglemente, lppMontantMaxRemboursement: $lppMontantMaxRemboursement, liste1: $liste1, liste2: $liste2, isStupefiant: $isStupefiant, isException: $isException, isOtc: $isOtc, hospitalOnly: $hospitalOnly, isPih: $isPih, isSurveillanceParticuliere: $isSurveillanceParticuliere, isMds: $isMds, biosimilaireOf: $biosimilaireOf, isBioreferent: $isBioreferent, isGeneric: $isGeneric, princepsName: $princepsName, genericName: $genericName, iconUrl: $iconUrl, phone: $phone, fax: $fax, email: $email, mssanteEmail: $mssanteEmail, catalogueUrl: $catalogueUrl, commentaire: $commentaire, address: $address, website: $website, keywordAppearanceDate: $keywordAppearanceDate, badge1Name: $badge1Name, badge1Url: $badge1Url, badge2Name: $badge2Name, badge2Url: $badge2Url, badge3Name: $badge3Name, badge3Url: $badge3Url, badge4Name: $badge4Name, badge4Url: $badge4Url, ansmStatut: $ansmStatut, ansmDate: $ansmDate, ansmUrl: $ansmUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.labelRaw, labelRaw) ||
                other.labelRaw == labelRaw) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.laboratory, laboratory) ||
                other.laboratory == laboratory) &&
            (identical(other.cip13, cip13) || other.cip13 == cip13) &&
            (identical(other.cis, cis) || other.cis == cis) &&
            (identical(other.cip7, cip7) || other.cip7 == cip7) &&
            (identical(other.groupLabel, groupLabel) ||
                other.groupLabel == groupLabel) &&
            (identical(other.departement, departement) ||
                other.departement == departement) &&
            (identical(other.isPdf, isPdf) || other.isPdf == isPdf) &&
            (identical(other.nsfp, nsfp) || other.nsfp == nsfp) &&
            (identical(other.nsfpDate, nsfpDate) ||
                other.nsfpDate == nsfpDate) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.rcpVetoUrl, rcpVetoUrl) ||
                other.rcpVetoUrl == rcpVetoUrl) &&
            (identical(other.meddisparUrl, meddisparUrl) ||
                other.meddisparUrl == meddisparUrl) &&
            (identical(other.lppCode, lppCode) || other.lppCode == lppCode) &&
            (identical(other.lppLibelle, lppLibelle) ||
                other.lppLibelle == lppLibelle) &&
            (identical(other.lppTarif, lppTarif) ||
                other.lppTarif == lppTarif) &&
            (identical(other.lppPrixUnitaireReglemente, lppPrixUnitaireReglemente) ||
                other.lppPrixUnitaireReglemente == lppPrixUnitaireReglemente) &&
            (identical(other.lppMontantMaxRemboursement, lppMontantMaxRemboursement) ||
                other.lppMontantMaxRemboursement ==
                    lppMontantMaxRemboursement) &&
            (identical(other.liste1, liste1) || other.liste1 == liste1) &&
            (identical(other.liste2, liste2) || other.liste2 == liste2) &&
            (identical(other.isStupefiant, isStupefiant) ||
                other.isStupefiant == isStupefiant) &&
            (identical(other.isException, isException) ||
                other.isException == isException) &&
            (identical(other.isOtc, isOtc) || other.isOtc == isOtc) &&
            (identical(other.hospitalOnly, hospitalOnly) ||
                other.hospitalOnly == hospitalOnly) &&
            (identical(other.isPih, isPih) || other.isPih == isPih) &&
            (identical(other.isSurveillanceParticuliere, isSurveillanceParticuliere) ||
                other.isSurveillanceParticuliere ==
                    isSurveillanceParticuliere) &&
            (identical(other.isMds, isMds) || other.isMds == isMds) &&
            (identical(other.biosimilaireOf, biosimilaireOf) ||
                other.biosimilaireOf == biosimilaireOf) &&
            (identical(other.isBioreferent, isBioreferent) ||
                other.isBioreferent == isBioreferent) &&
            (identical(other.isGeneric, isGeneric) ||
                other.isGeneric == isGeneric) &&
            (identical(other.princepsName, princepsName) ||
                other.princepsName == princepsName) &&
            (identical(other.genericName, genericName) ||
                other.genericName == genericName) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.fax, fax) || other.fax == fax) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.mssanteEmail, mssanteEmail) ||
                other.mssanteEmail == mssanteEmail) &&
            (identical(other.catalogueUrl, catalogueUrl) ||
                other.catalogueUrl == catalogueUrl) &&
            (identical(other.commentaire, commentaire) ||
                other.commentaire == commentaire) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.keywordAppearanceDate, keywordAppearanceDate) ||
                other.keywordAppearanceDate == keywordAppearanceDate) &&
            (identical(other.badge1Name, badge1Name) ||
                other.badge1Name == badge1Name) &&
            (identical(other.badge1Url, badge1Url) ||
                other.badge1Url == badge1Url) &&
            (identical(other.badge2Name, badge2Name) ||
                other.badge2Name == badge2Name) &&
            (identical(other.badge2Url, badge2Url) ||
                other.badge2Url == badge2Url) &&
            (identical(other.badge3Name, badge3Name) ||
                other.badge3Name == badge3Name) &&
            (identical(other.badge3Url, badge3Url) || other.badge3Url == badge3Url) &&
            (identical(other.badge4Name, badge4Name) || other.badge4Name == badge4Name) &&
            (identical(other.badge4Url, badge4Url) || other.badge4Url == badge4Url) &&
            (identical(other.ansmStatut, ansmStatut) || other.ansmStatut == ansmStatut) &&
            (identical(other.ansmDate, ansmDate) || other.ansmDate == ansmDate) &&
            (identical(other.ansmUrl, ansmUrl) || other.ansmUrl == ansmUrl));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        label,
        labelRaw,
        source,
        laboratory,
        cip13,
        cis,
        cip7,
        groupLabel,
        departement,
        isPdf,
        nsfp,
        nsfpDate,
        url,
        rcpVetoUrl,
        meddisparUrl,
        lppCode,
        lppLibelle,
        lppTarif,
        lppPrixUnitaireReglemente,
        lppMontantMaxRemboursement,
        liste1,
        liste2,
        isStupefiant,
        isException,
        isOtc,
        hospitalOnly,
        isPih,
        isSurveillanceParticuliere,
        isMds,
        biosimilaireOf,
        isBioreferent,
        isGeneric,
        princepsName,
        genericName,
        iconUrl,
        phone,
        fax,
        email,
        mssanteEmail,
        catalogueUrl,
        commentaire,
        address,
        website,
        keywordAppearanceDate,
        badge1Name,
        badge1Url,
        badge2Name,
        badge2Url,
        badge3Name,
        badge3Url,
        badge4Name,
        badge4Url,
        ansmStatut,
        ansmDate,
        ansmUrl
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResultImplToJson(
      this,
    );
  }
}

abstract class _SearchResult extends SearchResult {
  const factory _SearchResult(
      {required final String label,
      required final String labelRaw,
      required final SourceType source,
      required final String laboratory,
      final String? cip13,
      final String? cis,
      final String? cip7,
      final String? groupLabel,
      final String? departement,
      final bool isPdf,
      final bool nsfp,
      final String? nsfpDate,
      final String? url,
      final String? rcpVetoUrl,
      final String? meddisparUrl,
      final String? lppCode,
      final String? lppLibelle,
      final double? lppTarif,
      final double? lppPrixUnitaireReglemente,
      final String? lppMontantMaxRemboursement,
      final bool liste1,
      final bool liste2,
      final bool isStupefiant,
      final bool isException,
      final bool isOtc,
      final bool hospitalOnly,
      final bool isPih,
      final bool isSurveillanceParticuliere,
      final bool isMds,
      final String? biosimilaireOf,
      final bool isBioreferent,
      final bool? isGeneric,
      final String? princepsName,
      final String? genericName,
      final String? iconUrl,
      final String? phone,
      final String? fax,
      final String? email,
      final String? mssanteEmail,
      final String? catalogueUrl,
      final String? commentaire,
      final String? address,
      final String? website,
      final String? keywordAppearanceDate,
      final String? badge1Name,
      final String? badge1Url,
      final String? badge2Name,
      final String? badge2Url,
      final String? badge3Name,
      final String? badge3Url,
      final String? badge4Name,
      final String? badge4Url,
      final String? ansmStatut,
      final String? ansmDate,
      final String? ansmUrl}) = _$SearchResultImpl;
  const _SearchResult._() : super._();

  factory _SearchResult.fromJson(Map<String, dynamic> json) =
      _$SearchResultImpl.fromJson;

  @override // 🔤 IDENTITÉ
  String get label;
  @override
  String get labelRaw;
  @override
  SourceType get source;
  @override
  String get laboratory;
  @override
  String? get cip13;
  @override
  String? get cis;
  @override // 🔥 AJOUTS
  String? get cip7;
  @override
  String? get groupLabel;
  @override

  /// Département d'exercice (ex: "75", "33", "971") quand disponible.
  String? get departement;
  @override // 📄 CONTENU
  bool get isPdf;
  @override // 🟢 NSFP
  bool get nsfp;
  @override
  String? get nsfpDate;
  @override // 🔗 LIENS
  String? get url;
  @override
  String? get rcpVetoUrl;
  @override
  String? get meddisparUrl;
  @override
  String? get lppCode;
  @override // 📘 LPP — libellé, tarif (dernier par date validité), prix unitaire, montant max
  String? get lppLibelle;
  @override
  double? get lppTarif;
  @override
  double? get lppPrixUnitaireReglemente;
  @override
  String? get lppMontantMaxRemboursement;
  @override // ⚠️ STATUTS
  bool get liste1;
  @override
  bool get liste2;
  @override
  bool get isStupefiant;
  @override
  bool get isException;
  @override
  bool get isOtc;
  @override
  bool get hospitalOnly;
  @override
  bool get isPih;
  @override
  bool get isSurveillanceParticuliere;
  @override // 🩸 MDS
  bool get isMds;
  @override // 🧬 BIOSIMILAIRE
  String? get biosimilaireOf;
  @override
  bool get isBioreferent;
  @override // 💊 GÉNÉRIQUE
  bool? get isGeneric;
  @override
  String? get princepsName;
  @override
  String? get genericName;
  @override // 🏭 FOURNISSEUR
  String? get iconUrl;
  @override
  String? get phone;
  @override
  String? get fax;
  @override
  String? get email;
  @override

  /// BAL MSSanté personnelle (si trouvée via dataset Annuaire Santé).
  String? get mssanteEmail;
  @override
  String? get catalogueUrl;
  @override
  String? get commentaire;
  @override // 🆕 AMC
  String? get address;
  @override
  String? get website;
  @override

  /// Date d'apparition outil (outils métier, col C) — affiche "nouveau (date)" à droite du libellé.
  String? get keywordAppearanceDate;
  @override // 🏷️ BADGES
  String? get badge1Name;
  @override
  String? get badge1Url;
  @override
  String? get badge2Name;
  @override
  String? get badge2Url;
  @override
  String? get badge3Name;
  @override
  String? get badge3Url;
  @override
  String? get badge4Name;
  @override
  String? get badge4Url;
  @override // 🟢🟠🔴 ANSM
  String? get ansmStatut;
  @override
  String? get ansmDate;
  @override
  String? get ansmUrl;
  @override
  @JsonKey(ignore: true)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
