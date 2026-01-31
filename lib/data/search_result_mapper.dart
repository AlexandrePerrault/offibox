// lib/data/search_result_mapper.dart

import '../models/search_result.dart';
import '../models/pansement_item.dart';
import '../models/veto_item.dart';

// ─────────────────────────────────────────────
// 💊 BDM
// ─────────────────────────────────────────────

SearchResult fromBdm(
  Map<String, dynamic> row,
  Set<String> cipHosp, {
  Set<String>? hopCip7,
  Map<String, String>? biosimilaireByCip,
  required Map<String, String> generiquePrincepsByCip,
  required Map<String, String> princepsToGenericName,
}) {
  final rawLabel = (row['label'] ?? row['Libellé'] ?? '').toString();
  final cleanLabel =
      rawLabel.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  // ───── CIP
  final dynamic cipCandidate =
      row['cip13'] ??
      row['CIP13'] ??
      row['CIP 13'] ??
      row['cip'] ??
      row['Code CIP'];

  final cleanCip =
      (cipCandidate ?? '').toString().replaceAll(RegExp(r'\D'), '');

  final String? cip13 = cleanCip.length == 13 ? cleanCip : null;
  final String cip7 = cip13 != null ? cip13.substring(5, 12) : '';

  // =====================================================
  // 🧬 BIOSIMILAIRE (ligne CSV : col D → col B)
  // =====================================================
  final String? biosimilaireOf =
      (cip13 != null && biosimilaireByCip != null)
          ? biosimilaireByCip[cip13]
          : null;

  final bool isBiosimilaire = biosimilaireOf != null;

  // =====================================================
  // 💊 GÉNÉRIQUE (jamais biosimilaire)
  // =====================================================
  final bool isGeneric =
      !isBiosimilaire &&
      cip13 != null &&
      generiquePrincepsByCip.containsKey(cip13);

  final String? princepsName =
      isGeneric ? generiquePrincepsByCip[cip13] : null;

  // =====================================================
  // 🧬 PRINCEPS → GÉNÉRIQUE
  // =====================================================
  final String princepsKey =
      normalizePrincepsKey(cleanLabel);

  final String? genericName =
      (!isGeneric && !isBiosimilaire)
          ? princepsToGenericName[princepsKey]
          : null;

  // =====================================================
  // 🧬 BIORÉFÉRENT
  // = présent en colonne B du CSV biosimilaires
  // =====================================================
  final bool isBioreferent =
      biosimilaireByCip != null &&
      biosimilaireByCip.values.contains(princepsKey);


// ─────────────────────────
// 🏥 HOSPITALIER (SOURCE UNIQUE = CSV CIP hospitaliers)
// ─────────────────────────
final bool hospitalOnly =
    cip13 != null && cipHosp.contains(cip13);


  // =====================================================
  // ⚠️ AUTRES STATUTS
  // =====================================================
  final bool isException = row['isException'] == true;

  final String? meddisparUrl =
      row['meddisparUrl'] != null &&
              row['meddisparUrl'].toString().trim().isNotEmpty
          ? row['meddisparUrl'].toString()
          : null;

  return SearchResult(
  source: SourceType.bdm,
  labelRaw: rawLabel,
  label: cleanLabel,
  cip13: cip13,

  isGeneric: isGeneric,
  princepsName: princepsName,
  genericName: genericName,

  biosimilaireOf: biosimilaireOf,
  isException: isException,
  hospitalOnly: hospitalOnly,
  isStupefiant: row['isStup'] == true,

  nsfp: row['nsfp'] == true,
  nsfpDate: row['nsfpDate'] as String?,

  url: row['urlBdpm'],
  meddisparUrl: meddisparUrl,
  laboratory: '',
);


}
// ─────────────────────────────────────────────
// 📘 LPP
// ─────────────────────────────────────────────

SearchResult fromLppCode(String code, String url) {
  final raw = '(CODE LPP) $code';

  return SearchResult(
    source: SourceType.lpp,
    labelRaw: raw,
    label: raw,
    cip13: code,
    lppCode: code,
    url: url,
    nsfp: false,
    hospitalOnly: false,
    laboratory: '',
  );
}

String _normalizeKey(String s) {
  return s
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9/]'), '')
      .trim();
}
String normalizePrincepsKey(String label) {
  return label
      .toUpperCase()
      .split(',').first            // enlève ", comprimé..."
      .split(' - ').first          // enlève conditionnement
      .replaceAll(RegExp(r'\b\d+.*'), '') // enlève dosage
      .trim();
}

// ─────────────────────────────────────────────
// 🩹 PANSEMENTS / DM
// ─────────────────────────────────────────────
SearchResult fromPansement(PansementItem item) {
  return SearchResult(
    source: SourceType.dm,
    labelRaw: item.label,
    label: item.label,
    cip13: item.cip13,
    nsfp: false,
    hospitalOnly: false,
    laboratory: '',
    url: item.url,
  );
}

// ─────────────────────────────────────────────
// 🐾 VÉTÉRINAIRE
// ─────────────────────────────────────────────
SearchResult fromVeto(VetoItem item) {
  return SearchResult(
    source: SourceType.veto,
    labelRaw: item.label,
    label: item.label,
    cip13: item.cip13,
    nsfp: false,
    hospitalOnly: false,
    laboratory: '',
    url: item.url,
  );
}
