import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/data/search_result_mapper.dart' as mapper;

/// 🧠 Moteur de recherche Offibox
/// ➜ PUR, SYNCHRONE, SANS UI
class SearchEngine {
  SearchEngine(
    this.allResults, {
    Map<String, String>? genericNameToPrinceps,
    Map<String, List<String>>? dciToCis,
    Set<String>? genericCipSet,
  })  : _genericNameToPrinceps = genericNameToPrinceps ?? {},
        _dciToCis = dciToCis ?? {},
        _genericCipSet = genericCipSet ?? {} {
    _buildIndexes();
  }

  List<SearchResult> allResults;
  Map<String, String> _genericNameToPrinceps = {};
  final Map<String, List<String>> _dciToCis;
  final Set<String> _genericCipSet;

  void setGenericNameToPrinceps(Map<String, String>? map) {
    _genericNameToPrinceps = map ?? {};
  }

  /// Met à jour DCI → CIS (recherche par molécule). Appelé après chargement différé de composition.
  void setDciToCis(Map<String, List<String>>? map) {
    if (map == null) return;
    _dciToCis.clear();
    _dciToCis.addAll(map);
  }

  static const int _maxCacheEntries = 350;
  final Map<String, List<SearchResult>> _queryCache =
      <String, List<SearchResult>>{};

  final Map<String, Set<SearchResult>> _indexByFirst3 = {};
  final Map<String, Set<SearchResult>> _indexByCip3 = {};
  /// CIS (chiffres seulement) → résultats BDM (recherche inversée par molécule).
  final Map<String, List<SearchResult>> _cisToBdmResults = {};

  String _lastQuery = '';
  List<SearchResult> _lastResults = const [];

  // =========================================================
  // 🔁 INDEXATION
  // =========================================================
  void _buildIndexes() {
    _indexByFirst3.clear();
    _indexByCip3.clear();
    _cisToBdmResults.clear();

    for (final r in allResults) {
      final label = r.labelNorm;
      final cip = r.cipNorm;

      if (r.source == SourceType.bdm) {
        final cisKey = r.cis?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
        if (cisKey.isNotEmpty) {
          _cisToBdmResults.putIfAbsent(cisKey, () => []).add(r);
        }
      }

      if (label.isNotEmpty) {
        final key = label.length >= 3 ? label.substring(0, 3) : label;
        _indexByFirst3.putIfAbsent(key, () => {}).add(r);
      }

      // Indexation par les 3 premières lettres de chaque mot (pour BDM, LPP, DM, VETO, Keyword, SiteWeb, etc.)
      final words = r.label.split(RegExp(r'[\s,;]+'));
      for (final w in words) {
        final n = _normalize(w);
        if (n.length >= 3) {
          final wordKey = n.substring(0, 3);
          _indexByFirst3.putIfAbsent(wordKey, () => {}).add(r);
        }
      }

if (r.source == SourceType.lpp) {
  final lpp = r.labelNorm.replaceAll(RegExp(r'[^0-9]'), '');
  if (lpp.length >= 3) {
    final key = lpp.substring(0,3);
    _indexByCip3.putIfAbsent(key, () => {}).add(r);
  }
}

      if (cip.length >= 3) {
        final key = cip.substring(0, 3);
        _indexByCip3.putIfAbsent(key, () => {}).add(r);
      }
    }
  }

void updateResults(List<SearchResult> results) {
  allResults = results;
  _queryCache.clear();
  _lastResults = [];
  _lastQuery = '';
  _buildIndexes();
}


  // =========================================================
  // 🔍 API PUBLIQUE
  // =========================================================
  List<SearchResult> search(String rawQuery, {int limit = 45}) {
  final query = rawQuery.trim().toLowerCase();
  if (query.length < 2) return [];

  // 🔁 Cache Google-like
 final cached = _queryCache.remove(query);
if (cached != null) {
  // 🔁 marque comme récemment utilisé
  _queryCache[query] = cached;
  return cached;
}


  final tokens = query
      .split(RegExp(r'\s+'))
      .map(_normalize)
      .where((t) => t.length >= 2)
      .toList();

  if (tokens.isEmpty) return [];

  final first = tokens.first;
  final isNumeric = RegExp(r'^\d+$').hasMatch(first);
  final key = first.length >= 3 ? first.substring(0, 3) : first;

  List<SearchResult> candidates;

  // ⚡ Incrémental : si on prolonge la requête précédente
  if (_lastQuery.isNotEmpty && query.startsWith(_lastQuery)) {
    candidates = _lastResults;
  } else {
  // 🔢 Code LPP (7 chiffres) ou CIP → recherche large dès 4 chiffres
  if (isNumeric && query.length >= 4) {
    candidates = allResults;
  } else if (isNumeric && _indexByCip3.isNotEmpty) {
    final set = _indexByCip3[key];
    candidates = set != null ? set.toList() : allResults;
  } else if (_indexByFirst3.isNotEmpty) {
    final set = _indexByFirst3[key];
    candidates = set != null ? set.toList() : allResults;
  } else {
    candidates = allResults;
  }
}
  // Recherche inversée par DCI : dès 3 caractères (molécule tapée → princeps affichés)
  final queryNorm = _normalize(query.replaceAll(RegExp(r'\s+'), ''));
  if (queryNorm.length >= 3 && _dciToCis.isNotEmpty) {
    final seen = <String>{};
    for (final r in candidates) {
      seen.add('${r.cis ?? ""}_${r.cip13 ?? ""}');
    }
    final toAdd = <SearchResult>[];
    for (final entry in _dciToCis.entries) {
      if (!entry.key.startsWith(queryNorm) && entry.key != queryNorm) continue;
      for (final cis in entry.value) {
        final list = _cisToBdmResults[cis];
        if (list == null) continue;
        for (final r in list) {
          if (r.isGeneric == true) continue;
          final cip = r.cip13?.replaceAll(RegExp(r'\D'), '') ?? '';
          if (_genericCipSet.isNotEmpty &&
              cip.isNotEmpty &&
              _genericCipSet.contains(cip)) {
            continue;
          }
          if (seen.add('${r.cis ?? ""}_${r.cip13 ?? ""}')) {
            toAdd.add(r);
          }
        }
      }
    }
    if (toAdd.isNotEmpty) {
      candidates = [...candidates, ...toAdd];
    }
  }
  // 1) Prioriser les résultats qui matchent en startsWith (début de mot/label)
  var results = candidates
      .where((r) => _matchItem(r: r, tokens: tokens, queryNorm: queryNorm, requireStartsWith: true))
      .toList();

  // 2) Si aucun résultat en startsWith, accepter contains
  if (results.isEmpty) {
    results = candidates
        .where((r) => _matchItem(r: r, tokens: tokens, queryNorm: queryNorm, requireStartsWith: false))
        .toList();
  }

  // fallback large si trop restrictif
  if (results.isEmpty && candidates.length != allResults.length) {
    results = allResults
        .where((r) => _matchItem(r: r, tokens: tokens, queryNorm: queryNorm, requireStartsWith: false))
        .toList();
  }

  // Quand la requête correspond à un DCI (molécule), exclure les génériques : ce sont des DCI, pas d'intérêt
  if (queryNorm.isNotEmpty && _genericNameToPrinceps.containsKey(queryNorm)) {
    results = results
        .where((r) => r.source != SourceType.bdm || r.isGeneric != true)
        .toList();
  }

  results.sort(_compareResults);

  // 🛑 limite comme Google
  if (results.length > limit) {
    results = results.take(limit).toList();
  }

  // 🔐 mise à jour cache
  _lastQuery = query;
  _lastResults = results;
 _queryCache[query] = results;

// 🧹 eviction LRU
if (_queryCache.length > _maxCacheEntries) {
  _queryCache.remove(_queryCache.keys.first);
}

  return results;
}


Iterable<SearchResult> searchStream(String rawQuery) sync* {
  final query = rawQuery.trim().toLowerCase();
  if (query.length < 2) return;

  _lastQuery = query;

  final tokens = query
      .split(RegExp(r'\s+'))
      .map(_normalize)
      .where((t) => t.length >= 2)
      .toList();

  if (tokens.isEmpty) return;

  final queryNorm = _normalize(query.replaceAll(RegExp(r'\s+'), ''));
  final first = tokens.first;
  final isNumeric = RegExp(r'^\d+$').hasMatch(first);
  final key = first.length >= 3 ? first.substring(0, 3) : first;

  List<SearchResult> candidates;

  if (isNumeric && query.length >= 4) {
    candidates = allResults;
  } else if (isNumeric && _indexByCip3.isNotEmpty) {
    final set = _indexByCip3[key];
    candidates = set != null ? set.toList() : allResults;
  } else if (_indexByFirst3.isNotEmpty) {
    final set = _indexByFirst3[key];
    candidates = set != null ? set.toList() : allResults;
  } else {
    candidates = allResults;
  }

  // Recherche par DCI : dès 3 caractères (préfixe → princeps)
  if (queryNorm.length >= 3 && _dciToCis.isNotEmpty) {
    final seen = <String>{};
    for (final r in candidates) {
      seen.add('${r.cis ?? ""}_${r.cip13 ?? ""}');
    }
    final toAdd = <SearchResult>[];
    for (final entry in _dciToCis.entries) {
      if (!entry.key.startsWith(queryNorm) && entry.key != queryNorm) continue;
      for (final cis in entry.value) {
        final list = _cisToBdmResults[cis];
        if (list == null) continue;
        for (final r in list) {
          if (r.isGeneric == true) continue;
          final cip = r.cip13?.replaceAll(RegExp(r'\D'), '') ?? '';
          if (_genericCipSet.isNotEmpty &&
              cip.isNotEmpty &&
              _genericCipSet.contains(cip)) {
            continue;
          }
          if (seen.add('${r.cis ?? ""}_${r.cip13 ?? ""}')) {
            toAdd.add(r);
          }
        }
      }
    }
    if (toAdd.isNotEmpty) {
      candidates = [...candidates, ...toAdd];
    }
  }

  for (final r in candidates) {
    if (_matchItem(r: r, tokens: tokens, queryNorm: queryNorm)) {
      yield r;
    }
  }
}


  // =========================================================
  // 🎯 MATCHING
  // =========================================================

  /// True si un mot (normalisé) de [label] ou [cip] commence par [first].
  bool _labelOrCipHasWordStartingWith(String label, String cip, String first) {
    final combined = '$label $cip'.split(RegExp(r'[\s,;]+'));
    for (final w in combined) {
      final n = _normalize(w);
      if (n.isNotEmpty && n.startsWith(first)) return true;
    }
    return false;
  }

  bool _matchItem({
  required SearchResult r,
  required List<String> tokens,
  String? queryNorm,
  bool requireStartsWith = false,
}) {
  final label = r.labelNorm;
  final cip = r.cipNorm;

  // 💊 Recherche inversée par DCI (dès 3 car.) : si la requête est un préfixe de DCI et ce BDM a ce CIS, accepter (princeps affiché)
  if (queryNorm != null &&
      queryNorm.length >= 3 &&
      r.source == SourceType.bdm) {
    final cisKey = r.cis?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
    if (cisKey.isNotEmpty) {
      for (final entry in _dciToCis.entries) {
        if ((entry.key.startsWith(queryNorm) || entry.key == queryNorm) &&
            entry.value.any((c) => c == cisKey)) {
          return true;
        }
      }
    }
  }

  // ✅ Priorité startsWith : premier token doit matcher en début (label/cip ou mot) ; sinon on accepte contains si requireStartsWith == false
  final first = tokens.first;
  final isNumericFirst = RegExp(r'^\d+$').hasMatch(first);
  if (first.length >= 3 && !isNumericFirst) {
    final startsWithOk = label.startsWith(first) || cip.startsWith(first) ||
        _labelOrCipHasWordStartingWith(label, cip, first);
    final containsOk = label.contains(first) || cip.contains(first);
    if (requireStartsWith) {
      if (!startsWithOk) return false;
    } else {
      if (!startsWithOk && !containsOk) return false;
    }
  }

  // ✅ RÈGLE LPP (PRIORITAIRE) — recherche par code 7 chiffres branchée
  if (r.source == SourceType.lpp) {
    // Match explicite par code LPP (7 chiffres)
    if (tokens.length == 1 &&
        tokens.first.length == 7 &&
        RegExp(r'^\d{7}$').hasMatch(tokens.first)) {
      final code = tokens.first;
      if (r.lppCode == code || (r.cip13 != null && r.cip13!.replaceAll(RegExp(r'\D'), '') == code)) {
        return true;
      }
      return false;
    }
    final full = _normalize(label + cip);
    for (final t in tokens) {
      if (!full.contains(t)) return false;
    }
    return true;
  }

  // =================================================
  // 🧪 BDM
  // =================================================
  if (r.source == SourceType.bdm) {
    final limit = tokens.length > 2 ? 2 : tokens.length;
    for (int i = 0; i < limit; i++) {
      final t = tokens[i];
      if (!label.contains(t) && !cip.contains(t)) return false;
    }
    return true;
  }

  // =================================================
  // 🧪 DM (pansement) / VETO
  // =================================================
  if (r.source == SourceType.dm || r.source == SourceType.veto) {
    final textTokens =
        tokens.where((t) => !RegExp(r'^\d+$').hasMatch(t)).toList();
    final numTokens =
        tokens.where((t) => RegExp(r'^\d+$').hasMatch(t)).toList();

    if (numTokens.isNotEmpty && cip.isNotEmpty) {
      if (numTokens.join() == cip) return true;
    }

    for (final t in textTokens) {
      if (label.contains(t)) return true;
    }
    return false;
  }

  // =================================================
  // 🏥 AMO / AMC (mutuelles) — recherche code
  // Si on tape un code (ex. 01241), on affiche la CPAM correspondante.
  // =================================================
  if (r.source == SourceType.amo || r.source == SourceType.amc) {
    final codeDigits = (r.cip13 ?? '').replaceAll(RegExp(r'\D'), '');
    final queryDigits = tokens.join();
    if (queryDigits.length >= 2 &&
        RegExp(r'^\d+$').hasMatch(queryDigits) &&
        codeDigits.isNotEmpty) {
      if (codeDigits == queryDigits ||
          codeDigits.startsWith(queryDigits) ||
          queryDigits.startsWith(codeDigits)) {
        return true;
      }
    }
    for (final t in tokens) {
      if (!label.contains(t) && !cip.contains(t)) return false;
    }
    return true;
  }

  // =================================================
  // 🏭 CATALOGUE (laboratoires) — startsWith sur le nom du laboratoire
  // Ex. "Viatris" → tous les laboratoires dont le nom commence par Viatris
  // =================================================
  if (r.source == SourceType.catalogue) {
    final first = tokens.first;
    if (first.length >= 2) {
      final labNameNorm = label; // label = nom du laboratoire pour catalogue
      if (requireStartsWith) {
        if (!labNameNorm.startsWith(first)) return false;
      } else {
        if (!labNameNorm.startsWith(first) && !labNameNorm.contains(first)) return false;
      }
    }
    for (final t in tokens.skip(1)) {
      if (!label.contains(t) && !cip.contains(t)) return false;
    }
    return true;
  }

  // =================================================
  // 🔁 FALLBACK GÉNÉRIQUE
  // =================================================
  for (final t in tokens) {
    if (!label.contains(t) && !cip.contains(t)) return false;
  }
  return true;
}

  // =========================================================
  // 🔢 TRI
  // =========================================================
  int _compareResults(SearchResult a, SearchResult b) {
    // 💊 Molécule tapée → princeps en ligne 1 (ex. daridorexant → QUIVIVIQ)
    final queryNorm = _normalize(_lastQuery.replaceAll(RegExp(r'\s+'), ''));
    if (queryNorm.isNotEmpty && _genericNameToPrinceps.isNotEmpty) {
      final princepsKey = _genericNameToPrinceps[queryNorm];
      if (princepsKey != null) {
        final aKey = mapper.normalizePrincepsKey(a.labelRaw);
        final bKey = mapper.normalizePrincepsKey(b.labelRaw);
        if (aKey == princepsKey && bKey != princepsKey) return -1;
        if (aKey != princepsKey && bKey == princepsKey) return 1;
      }
    }

    // 🏭 Catalogue (nom du labo) en startsWith avant tout le reste (ex. "viatris" → Viatris labo avant médicaments contenant "viatris")
    if (queryNorm.length >= 2) {
      final aLabelNorm = _normalize(a.labelRaw);
      final bLabelNorm = _normalize(b.labelRaw);
      final aIsCatalogueStarts = a.source == SourceType.catalogue && aLabelNorm.startsWith(queryNorm);
      final bIsCatalogueStarts = b.source == SourceType.catalogue && bLabelNorm.startsWith(queryNorm);
      if (aIsCatalogueStarts && !bIsCatalogueStarts) return -1;
      if (!aIsCatalogueStarts && bIsCatalogueStarts) return 1;
    }

    // 🟪 Règle startsWith : les résultats dont le libellé COMMENCE par la requête passent devant (ex. "centre" → CENTRE DE PHARMACOVIGILANCE en premier)
    if (queryNorm.length >= 2) {
      final aLabelNorm = _normalize(a.labelRaw);
      final bLabelNorm = _normalize(b.labelRaw);
      final aStarts = aLabelNorm.startsWith(queryNorm);
      final bStarts = bLabelNorm.startsWith(queryNorm);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
    }

    // 🎯 Priorité : résultats qui matchent TOUS les mots-clés en premier
    final ma = _matchedTokensCount(a);
    final mb = _matchedTokensCount(b);
    if (ma != mb) return mb.compareTo(ma); // plus de tokens matchés = meilleur

    final pa = _priority(a);
    final pb = _priority(b);
    if (pa != pb) return pa.compareTo(pb);

    final sa = _startsWithScore(a);
    final sb = _startsWithScore(b);
    if (sa != sb) return sb.compareTo(sa);

    // 🏥 AMO : ordre alphabétique (CPAM de X → tri sur X)
    if (a.source == SourceType.amo && b.source == SourceType.amo) {
      return _normalizeAmoLabel(a.labelRaw)
          .compareTo(_normalizeAmoLabel(b.labelRaw));
    }
    if (a.source == SourceType.amc && b.source == SourceType.amc) {
      return a.label.compareTo(b.label);
    }

    // 🏷️ Outils métier / 🌐 Sites web : ordre alphabétique par libellé (col B / commentaire)
    if (a.source == SourceType.keyword && b.source == SourceType.keyword) {
      return _libelleForSort(a).compareTo(_libelleForSort(b));
    }
    if (a.source == SourceType.siteWeb && b.source == SourceType.siteWeb) {
      return _libelleForSort(a).compareTo(_libelleForSort(b));
    }

    // 💊 BDM : quand la requête contient un dosage (ex. "rivarox 20"), mettre en premier les résultats avec ce dosage, puis ordre alphabétique
    if (a.source == SourceType.bdm && b.source == SourceType.bdm) {
      final dma = _dosageMatchScore(a);
      final dmb = _dosageMatchScore(b);
      if (dma != dmb) return dmb.compareTo(dma); // dosage correspondant à la requête en premier
      final da = _extractDosageFromLabel(a.labelRaw);
      final db = _extractDosageFromLabel(b.labelRaw);
      if (da != null && db != null) {
        if (da < db) return -1;
        if (da > db) return 1;
      }
      // Même dosage ou indéterminé : ordre alphabétique par libellé
      return a.labelRaw.toLowerCase().compareTo(b.labelRaw.toLowerCase());
    }

    return a.label.compareTo(b.label);
  }

  /// Extrait le premier dosage numérique (mg, g, ml, µg…) du libellé BDM pour le tri.
  static double? _extractDosageFromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    // Ex. "BRINTELLIX 10mg boîte de 28 comprimés", "0,5 mg", "2,5 g/5 mL"
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:mg|g|ml|mL|µg|mcg)',
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) return null;
    final s = match.group(1)!.replaceAll(',', '.');
    return double.tryParse(s);
  }

  /// Libellé affiché (col B) pour le tri alphabétique outils métier / sites web.
  static String _libelleForSort(SearchResult r) {
    final lib = (r.commentaire ?? r.label).trim().toLowerCase();
    return lib;
  }

  /// Pour le tri : enlève le préfixe "CPAM de/du/..." pour comparer.
  static String _normalizeAmoLabel(String label) {
    return label
        .toLowerCase()
        .replaceFirst(
          RegExp(r"^cpam\s+(de|des|du|la|le|l')\s+"),
          '',
        )
        .trim();
  }

  /// Ordre d’affichage : outils métier → catalogues → laboratoires (catalogue) → sites web → mutuelles → médicaments → LPP → pansements → veto → en dernier (AMO, CERP, etc.).
  int _priority(SearchResult r) {
    if (r.isNsfpEffective) return 900;
    if (r.hospitalOnly == true) return 1000;

    switch (r.source) {
      case SourceType.keyword:
        return -100; // 1. Outils métier
      case SourceType.siteWeb:
        return -95;  // 2. Sites web
      case SourceType.codesActes:
        return -90;  // 3. Codes actes pharmacie
      case SourceType.catalogue:
        return -80;  // 4. Catalogues / laboratoires
      case SourceType.amc:
        return -70;  // 5. Mutuelles
      case SourceType.bdm:
        return 0;    // 6. Médicaments
      case SourceType.dm:
        return 50;   // 7. Pansements (DM) avant LPP
      case SourceType.lpp:
        return 60;   // 8. LPP
      case SourceType.veto:
        return 70;   // 9. Veto
      case SourceType.amo:
      case SourceType.cerp:
      case SourceType.pharmacovigilance:
      case SourceType.centresAntiPoison:
      case SourceType.chu:
      case SourceType.ceipAddictovigilance:
      case SourceType.annuaireSanteRpps:
        return 800;  // 9. En dernier
    }
  }

  /// Tokens de la requête (normalisés, longueur >= 2 ou numériques).
  List<String> _queryTokens() {
    return _lastQuery
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((t) => t.length >= 2 || RegExp(r'^\d+$').hasMatch(t))
        .toList();
  }

  /// Valeurs numériques présentes dans la requête (ex. "rivarox 20" → {20.0}).
  Set<double> _queryNumericDosages() {
    final tokens = _queryTokens();
    final out = <double>{};
    for (final t in tokens) {
      if (RegExp(r'^\d+$').hasMatch(t)) {
        final v = double.tryParse(t);
        if (v != null) out.add(v);
      }
    }
    return out;
  }

  /// 1 si le résultat BDM a un dosage égal à un nombre présent dans la requête (ex. "20" → 20 mg en premier).
  int _dosageMatchScore(SearchResult r) {
    if (r.source != SourceType.bdm) return 0;
    final dosage = _extractDosageFromLabel(r.labelRaw);
    if (dosage == null) return 0;
    return _queryNumericDosages().contains(dosage) ? 1 : 0;
  }

  /// Nombre de tokens de la requête présents dans le résultat (label, cip, labo).
  int _matchedTokensCount(SearchResult r) {
    final tokens = _queryTokens();
    if (tokens.isEmpty) return 0;

    final label = _normalize(r.labelRaw);
    final cip = _normalize(r.cip13 ?? '');
    final lab = _normalize(r.laboratory);
    final full = label + cip + lab;

    int count = 0;
    for (final t in tokens) {
      if (full.contains(t)) count++;
    }

    // Bonus spécial pour sites web et mots clés s'ils contiennent la requête dans leur commentaire (colonne 1 visible)
    if (r.source == SourceType.siteWeb || r.source == SourceType.keyword) {
      final commentaireNorm = _normalize(r.commentaire ?? '');
      if (commentaireNorm.isNotEmpty) {
        bool allMatch = true;
        for (final t in tokens) {
          if (!commentaireNorm.contains(t)) {
            allMatch = false;
            break;
          }
        }
        if (allMatch) count += 10; // gros bonus pour remonter ces résultats
      }
    }

    return count;
  }

  int _startsWithScore(SearchResult r) {
    final tokens = _lastQuery
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((t) => t.length >= 2)
        .toList();

    final label = _normalize(r.labelRaw);
    final cip = _normalize(r.cip13 ?? '');
    final lab = _normalize(r.laboratory);

    int score = 0;

    if (tokens.isNotEmpty &&
        (label.startsWith(tokens[0]) || cip.startsWith(tokens[0]))) {
      score += 5;
    }

    if (tokens.length >= 2 &&
        (label.contains(tokens[1]) || cip.contains(tokens[1]))) {
      score += 3;
    }

    if (tokens.length >= 3 &&
        (lab.startsWith(tokens[2]) || label.contains(tokens[2]))) {
      score += 2;
    }

    return score;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
