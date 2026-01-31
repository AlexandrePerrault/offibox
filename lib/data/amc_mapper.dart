import '../models/search_result.dart';


SearchResult fromAmcRow(List<String> row) {
  final String nom = row.isNotEmpty ? row[0].trim() : '';
  final String codeAmc =
      row.length > 1 ? row[1].replaceAll(RegExp(r'\D'), '') : '';
  final String? phone =
      row.length > 2 && row[2].trim().isNotEmpty ? row[2].trim() : null;

  return SearchResult(
    // 🔎 label "propre" pour la recherche texte
    labelRaw: nom,
    label: nom,

    // 🔢 index numérique
    cip13: codeAmc.isEmpty ? null : codeAmc,
    cis: null,

    source: SourceType.amc,
    laboratory: '',

    nsfp: false,
    hospitalOnly: false,

    // AMC : pas de lien principal
    url: null,
    meddisparUrl: null,

    // 📞 info utile
    phone: phone,

    // badge informatif optionnel
    badge1Name: codeAmc.isNotEmpty
        ? 'Code AMC : $codeAmc'
        : null,
  );
}
