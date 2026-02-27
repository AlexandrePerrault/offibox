import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

String getCol(List<String> row, int i) =>
    row.length > i ? row[i].trim() : '';


// ======================================================
// 🟦 AMC — Mutuelles
// ======================================================
SearchResult fromAmcRow(List<String> row) {
  final String nom     = normalizeText(getCol(row, 9));   // J
  final String codeAmc = getCol(row, 10).replaceAll(RegExp(r'\D'), ''); // K
  final String phone   = getCol(row, 11); // L
  final String fax     = getCol(row, 12); // M
  final String siteWeb = getCol(row, 13); // N
  final String address = normalizeAddressForStorage(getCol(row, 14)); // O
  final String email   = getCol(row, 15); // P

  // ⛔️ sécurité : pas de mutuelle sans nom
  if (nom.isEmpty) {
    throw StateError('Ligne sans AMC');
  }

  return SearchResult(
    source: SourceType.amc,

    label: nom,
    labelRaw: nom,
    laboratory: '',

    // 👉 code préfectoral mutuelle
    cip13: codeAmc.isNotEmpty ? codeAmc : null,

    phone: phone.isNotEmpty ? phone : null,
    fax: fax.isNotEmpty ? fax : null,
    url: siteWeb.isNotEmpty ? siteWeb : null,
    email: email.isNotEmpty ? email : null,

    groupLabel: address.isNotEmpty ? address : null,

    badge1Name:
        codeAmc.isNotEmpty ? 'Code préfectoral : $codeAmc' : null,
  );
}


// ======================================================
// 🟩 AMO — Organismes (CPAM, MSA, etc.)
// ======================================================
SearchResult fromAmoRow(List<String> row) {
  final String codeRegime = getCol(row, 0);                 // A
  final String nom        = normalizeText(getCol(row, 2)); // C
  final String address    = normalizeAddressForStorage(getCol(row, 3)); // D
  final String phone      = getCol(row, 4);                // E
  final String fax        = getCol(row, 5);                // F
  final String siteWeb    = getCol(row, 6);                // G
  final String comment = normalizeAddressForStorage(getCol(row, 7)); // H


  // ⛔️ pas d’AMO sans nom NI code
  if (nom.isEmpty && codeRegime.isEmpty) {
    throw StateError('Ligne sans AMO');
  }

  return SearchResult(
    source: SourceType.amo,

    label: nom.isNotEmpty ? nom : codeRegime,
    labelRaw: nom.isNotEmpty ? nom : codeRegime,
    laboratory: '',

    // 👉 code organisme AMO (colonne A)
    cip13: codeRegime.isNotEmpty ? codeRegime : null,

    phone: phone.isNotEmpty ? phone : null,
    fax: fax.isNotEmpty ? fax : null,
    url: siteWeb.isNotEmpty ? siteWeb : null,

    // ligne 2 : adresse prioritaire
    groupLabel: address.isNotEmpty ? address : comment,
    commentaire: comment.isNotEmpty ? comment : null,
    badge1Name:
        codeRegime.isNotEmpty ? 'Code organisme : $codeRegime' : null,
  );
}
