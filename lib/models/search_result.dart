// lib/models/search_result.dart

enum SourceType {
  bdm,
  dm,
  veto,
  lpp,
  amc,
  keyword,
  catalogue,
  cerp,
}

class SearchResult {
  // ─────────────────────────
  // 🔧 CHAMPS NORMALISÉS (PERF)
  // ─────────────────────────
  late final String labelNorm;
  late final String cipNorm;
  late final String labNorm;

  final String label;
  final String labelRaw;
  final String? cip13;
  final String? cis;
  final SourceType source;

  final bool isPdf;

  // ─────────────────────────
  // 🟢 NSFP
  // ─────────────────────────
  final bool nsfp;
  final String? nsfpDate;

  // ─────────────────────────
  // 🔗 LIENS
  // ─────────────────────────
  final String? url;
  final String? rcpVetoUrl;
  final String? meddisparUrl;
  final String? lppCode;

  // ─────────────────────────
  // 📦 STATUTS MÉTIER
  // ─────────────────────────
  final bool liste1;
  final bool liste2;
  final bool isStupefiant;
 final bool isException;

/// ✅ Vérité métier injectée UNIQUEMENT par le mapper
final bool hospitalOnly;

  // ─────────────────────────
  // 🧬 BIOSIMILAIRE / BIO-RÉFÉRENT
  // ─────────────────────────
  final String? biosimilaireOf;
  final bool isBioreferent;

  // ─────────────────────────
  // 💊 GÉNÉRIQUES
  // ─────────────────────────
  final bool? isGeneric;
  final String? princepsName;
  final String? genericName;

  // ─────────────────────────
  // 🏭 LABO / FOURNISSEUR
  // ─────────────────────────
  final String laboratory;
  final String? iconUrl;
  final String? phone;
  final String? fax;
  final String? email;
  final String? catalogueUrl;

  // ─────────────────────────
  // 🏷️ BADGES
  // ─────────────────────────
  final String? badge1Name;
  final String? badge1Url;
  final String? badge2Name;
  final String? badge2Url;
  final String? badge3Name;
  final String? badge3Url;

  // ─────────────────────────
  // 🟢🟠🔴 ANSM
  // ─────────────────────────
  final String? ansmStatut;
  final String? ansmDate;
  final String? ansmUrl;

  SearchResult({
    required this.label,
    required this.labelRaw,
    required this.source,
    required this.laboratory,

    this.cip13,
    this.cis,

    this.nsfp = false,
    this.nsfpDate,

    this.url,
    this.rcpVetoUrl,
    this.meddisparUrl,
    this.lppCode,

    this.liste1 = false,
    this.liste2 = false,
    this.isStupefiant = false,
    this.isException = false,
    this.hospitalOnly = false,

    this.biosimilaireOf,
    this.isBioreferent = false,

    this.isGeneric,
    this.princepsName,
    this.genericName,

    this.isPdf = false,
    this.iconUrl,
    this.phone,
    this.fax,
    this.email,
    this.catalogueUrl,

    this.badge1Name,
    this.badge1Url,
    this.badge2Name,
    this.badge2Url,
    this.badge3Name,
    this.badge3Url,

    this.ansmStatut,
    this.ansmDate,
    this.ansmUrl,
  })  : labelNorm = _normalize(labelRaw),
        cipNorm   = _normalize(cip13 ?? ''),
        labNorm   = _normalize(laboratory);

  // ─────────────────────────
  // 🔧 NORMALISATION INTERNE
  // ─────────────────────────
  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // ─────────────────────────
  // 🧠 RÈGLES MÉTIER
  // ─────────────────────────

  bool get isNsfpEffective =>
      nsfp && nsfpDate != null && nsfpDate!.trim().isNotEmpty;

  bool get isInactive =>
      source == SourceType.bdm && (isNsfpEffective || hospitalOnly);

  bool get hasMedispar =>
      source == SourceType.bdm &&
      meddisparUrl != null &&
      meddisparUrl!.isNotEmpty;

  bool get isGelule {
    final l = label.toLowerCase();
    return l.contains('gélule') || l.contains('gelule');
  }

  bool get isLaboratoire =>
      source == SourceType.keyword && iconUrl != null;

  // ─────────────────────────
  // 🏥 HELPERS CIP (INFORMATIFS)
  // ─────────────────────────

  /// CIP7 = 7 chiffres centraux du CIP13
  String? get cip7 =>
      cip13 != null && cip13!.length == 13
          ? cip13!.substring(5, 12)
          : null;

  /// ⚠️ Informatif uniquement (le mapper décide)
  bool get isHospitalierCip7 =>
      cip7 != null && cip7!.startsWith('5');

  // ─────────────────────────
  // 🔢 PRIORITÉ SOURCE
  // ─────────────────────────
  int get sourcePriority {
    switch (source) {
      case SourceType.bdm:
        return 0;
      case SourceType.keyword:
        return 1;
      case SourceType.dm:
        return 2;
      case SourceType.veto:
        return 3;
      case SourceType.lpp:
        return 4;
      case SourceType.amc:
        return 5;
      default:
        return 99;
    }
  }
}
