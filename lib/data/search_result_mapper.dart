import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import '../models/pansement_item.dart';
import '../models/veto_item.dart';

const _emptyLab = '';

/// CIP7 = 7 premiers chiffres du CIP13 (si CIP13 valide)
String? cip7FromCip13(String? cip13) {
  if (cip13 == null) return null;
  final c = cip13.replaceAll(RegExp(r'\D'), '');
  if (c.length != 13) return null;
  return c.substring(0, 7);
}

SearchResult _base({
  required String label,
  required SourceType source,
  required String? cip13,
  String? laboratory,
  String? labelRaw,
  String? cip7,
}) {
  return SearchResult(
    source: source,
    label: label,
    labelRaw: labelRaw ?? label,
    laboratory: laboratory ?? _emptyLab,
    cip13: cip13,
    cip7: cip7,
  );
}

/// ─────────────────────────────────────────────
/// 💊 BDM
/// ─────────────────────────────────────────────
SearchResult fromBdm(
  Map<String, dynamic> row,
  Set<String> stupCips,
  Set<String> cipHospitaliers,
  Set<String> pihCips,
  Set<String> surveillanceCips,
  Set<String> exceptionCips,
  Set<String> otcCips, {
  required Map<String, String> biosimilaireByCip,
  required Map<String, String> generiquePrincepsByCip,
  required Map<String, String> princepsToGenericName,
}) {
  final rawLabel = (row['label'] ?? row['labelRaw'] ?? '').toString();
  final label = rawLabel.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  // ─────────────────────────
  // CIP13
  // ─────────────────────────
  final cipCandidate =
      row['cip13'] ?? row['CIP13'] ?? row['CIP 13'] ?? row['cip'];

  final cleanCip =
      (cipCandidate ?? '').toString().replaceAll(RegExp(r'\D'), '');

  final String? cip13 = cleanCip.length == 13 ? cleanCip : null;

  // ─────────────────────────
  // CIP7
  // ─────────────────────────
  final rowCip7 =
      (row['cip7'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

  final String? cip7 =
      rowCip7.length == 7 ? rowCip7 : cip7FromCip13(cip13);

  // ─────────────────────────
  // 🟧 PIH
  // ─────────────────────────
  final bool isPih =
      cip13 != null && pihCips.contains(cip13);

  // ─────────────────────────
  // 🟪 SURVEILLANCE PARTICULIÈRE
  // ─────────────────────────
  final bool isSurveillanceParticuliere =
      cip13 != null && surveillanceCips.contains(cip13);

  // ─────────────────────────
  // 🩸 MDS
  // ─────────────────────────
  final bool isMds = row['isMds'] == true;

  // ─────────────────────────
  // BIOSIMILAIRE / GÉNÉRIQUE (fichier biosimilaires + colonne BDM 10)
  // ─────────────────────────
  final String? biosimilaireFromFile = cip13 != null ? biosimilaireByCip[cip13] : null;
  final biosimilaireRaw = row['biosimilaire']?.toString().trim();
  final String? biosimilaireFromRow = (biosimilaireRaw != null && biosimilaireRaw.isNotEmpty) ? biosimilaireRaw : null;
  final String? biosimilaireOf = biosimilaireFromFile ?? biosimilaireFromRow;

  final bool isBiosimilaire = biosimilaireOf != null;

  final bool isGeneric =
      !isBiosimilaire &&
      cip13 != null &&
      generiquePrincepsByCip.containsKey(cip13);

  final String? princepsName =
      isGeneric ? generiquePrincepsByCip[cip13] : null;

  final String princepsKey = normalizePrincepsKey(label);

  final String? genericName =
      (!isGeneric && !isBiosimilaire)
          ? princepsToGenericName[princepsKey]
          : null;

  final bool isBioreferent =
      biosimilaireByCip.values.contains(princepsKey);

  // ─────────────────────────
  // 🏥 HOP
  // ─────────────────────────
  final bool hospitalOnly =
      cip7 != null &&
      cip7.startsWith('5') &&
      cipHospitaliers.contains(cip7);

  // ─────────────────────────
  // CIS (lien avec composition-bdm)
  // ─────────────────────────
  final String? cis = (row['cis']?.toString() ?? '').trim().isNotEmpty
      ? row['cis']?.toString().trim()
      : null;

  // ─────────────────────────
  // 🏭 LABORATOIRE (dernier mot du libellé BDM, ex. "… SANOFI")
  // ─────────────────────────
  final parts = label.trim().split(RegExp(r'\s+'));
  final String laboratory = parts.isNotEmpty && parts.last.length > 1
      ? parts.last.toUpperCase().trim()
      : '';

  // ─────────────────────────
  // BUILD SearchResult
  // ─────────────────────────
  return _base(
    label: label,
    source: SourceType.bdm,
    cip13: cip13,
    labelRaw: rawLabel,
    cip7: cip7,
    laboratory: laboratory.isEmpty ? _emptyLab : laboratory,
  ).copyWith(
    cis: cis,
    // ───── STATUTS
    isPih: isPih,
    isSurveillanceParticuliere: isSurveillanceParticuliere,
    hospitalOnly: hospitalOnly,
    isMds: isMds,

    // ───── AUTRES FLAGS (stupéfiants = CIP13 dans stupéfiants+hopital col 0 ; exception/OTC = BDM ou exception_otc_2026.csv)
    isStupefiant: cip13 != null && stupCips.contains(cip13),
    isException: row['isException'] == true || (cip13 != null && exceptionCips.contains(cip13)),
    isOtc: row['isOtc'] == true || (cip13 != null && otcCips.contains(cip13)),
    nsfp: row['nsfp'] == true,
    nsfpDate: row['nsfpDate']?.toString(),

    // ───── GÉNÉRIQUES
    isGeneric: isGeneric,
    princepsName: princepsName,
    genericName: genericName,
    biosimilaireOf: biosimilaireOf,
    isBioreferent: isBioreferent,

    // ───── LIENS
    url: row['urlBdpm']?.toString(),
    meddisparUrl: row['meddisparUrl']?.toString(),

    // ───── ALERTES ANSM (ligne 2 médicaments)
    ansmStatut: row['ansmStatut']?.toString().trim(),
    ansmDate: row['ansmDate']?.toString().trim(),
    ansmUrl: row['ansmUrl']?.toString().trim(),
  );
}

/// ─────────────────────────────────────────────
/// 📘 LPP — code, url, et optionnellement libellé, tarif (dernier par date validité), prix unitaire, montant max
/// ─────────────────────────────────────────────
SearchResult fromLppCode(
  String code,
  String url, {
  String? libelle,
  double? tarif,
  double? prixUnitaireReglemente,
  String? montantMaxRemboursement,
}) {
  final displayLabel = libelle?.trim().isNotEmpty == true ? libelle! : 'Code LPP $code';
  return SearchResult(
    label: displayLabel,
    labelRaw: displayLabel,
    cip13: code,
    lppCode: code,
    laboratory: 'LPP',
    source: SourceType.lpp,
    url: url,
    lppLibelle: libelle?.trim().isNotEmpty == true ? libelle : null,
    lppTarif: tarif,
    lppPrixUnitaireReglemente: prixUnitaireReglemente,
    lppMontantMaxRemboursement: montantMaxRemboursement?.trim().isNotEmpty == true ? montantMaxRemboursement : null,
  );
}


/// ─────────────────────────────────────────────
/// 🩹 DM
/// ─────────────────────────────────────────────
SearchResult fromPansement(PansementItem item) {
  return _base(
    label: item.label,
    source: SourceType.dm,
    cip13: item.cip13,
  ).copyWith(url: item.url);
}

/// ─────────────────────────────────────────────
/// 🐾 VÉTÉRINAIRE
/// ─────────────────────────────────────────────
SearchResult fromVeto(VetoItem item) {
  return _base(
    label: item.label,
    source: SourceType.veto,
    cip13: item.cip13,
  ).copyWith(url: item.url);
}

/// ─────────────────────────────────────────────
/// 🧼 NORMALISATION PRINCEPS
/// ─────────────────────────────────────────────
String normalizePrincepsKey(String label) {
  return label
      .toUpperCase()
      .split(',').first
      .split(' - ').first
      .replaceAll(RegExp(r'\b\d+.*'), '')
      .replaceAll(RegExp(r'[^A-Z0-9/]'), '')
      .trim();
}
