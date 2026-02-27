import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offibox/data/bdm_parser.dart';
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/utils/normalize.dart';

/// Index des colonnes — CIS_bdpm : col A = 0 (code CIS), col B = 1 (nom/dénomination), col C = 2 (forme).
/// CIS_CIP_bdpm : col C = 2 (libellé de présentation).
const int _cisBdpmColCodeCis = 0;
const int _cisBdpmColDenomination = 1;
const int _cisBdpmColFormePharmaceutique = 2;

const int _cisCipColCis = 0;
const int _cisCipColLibelle = 2;
const int _cisCipColCip13 = 6;
const int _cisCipColTauxRemboursement = 8;

const String _bdpmLastLoadDateKey = 'bdpm_labels_last_load_date';

/// Résultat du chargement des libellés BDPM (optionnel, pour remplacer ou compléter BDM_MASTER).
class BdpmLabelsResult {
  const BdpmLabelsResult({
    required this.cip13ToLabel,
    required this.cisToTauxRemboursement,
  });
  /// CIP13 (chiffres) → libellé reconstruit (nom, dosage, forme, quantité).
  final Map<String, String> cip13ToLabel;
  /// CIS (chiffres) → taux de remboursement affichable (ex. "65 %") depuis CIS_CIP_bdpm.
  final Map<String, String> cisToTauxRemboursement;
}

/// Formate un CIP13 avec espaces pour l'affichage : 3400938130287 → "34009 381 302 8 7" (5-3-3-1-1).
String formatCip13WithSpaces(String cip13) {
  final digits = cip13.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) return cip13;
  return '${digits.substring(0, 5)} ${digits.substring(5, 8)} ${digits.substring(8, 11)} ${digits.substring(11, 12)} ${digits.substring(12, 13)}';
}

/// Cache des libellés BDPM issus des fichiers TXT (CIS_bdpm.txt + CIS_CIP_bdpm.txt).
/// Rempli au chargement phase 2 ; utilisé pour afficher "CIP_espaces : dénomination, forme (présentation)".
class BdpmTxtLabelCache {
  BdpmTxtLabelCache._();
  static final BdpmTxtLabelCache _instance = BdpmTxtLabelCache._();
  static BdpmTxtLabelCache get instance => _instance;

  Map<String, String> _cip13ToLabel = {};
  Map<String, String> _cisToTauxRemboursement = {};
  bool _loaded = false;
  Map<String, String> get cip13ToLabel => _cip13ToLabel;
  /// CIS (chiffres) → taux affichable (ex. "65 %") depuis CIS_CIP_bdpm.txt colonne I. Utilisé pour « Plus d'infos ».
  Map<String, String> get cisToTauxRemboursement => Map.unmodifiable(_cisToTauxRemboursement);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today7am = DateTime(now.year, now.month, now.day, 7, 0);
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_loaded) {
      final lastStr = prefs.getString(_bdpmLastLoadDateKey);
      if (lastStr == todayStr) return; // déjà rechargé aujourd'hui
      if (now.isBefore(today7am)) return; // avant 7h on garde le cache (reconstruction à 7h)
      _loaded = false;
    }
    final result = await loadBdpmLabels();
    _cip13ToLabel = result.cip13ToLabel;
    _cisToTauxRemboursement = result.cisToTauxRemboursement;
    _loaded = true;
    await prefs.setString(_bdpmLastLoadDateKey, todayStr);
  }

  /// True si le CIS a un taux de remboursement dans la col I du fichier CIS_CIP_bdpm.txt.
  bool hasTauxRemboursement(String? cis) {
    if (cis == null) return false;
    final clean = cis.replaceAll(RegExp(r'\D'), '').trim();
    return clean.isNotEmpty && _cisToTauxRemboursement.containsKey(clean);
  }

  String? get(String? cip13) {
    if (cip13 == null) return null;
    final clean = cip13.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 13) return null;
    return _cip13ToLabel[clean];
  }
}

/// Charge CIS_bdpm.txt et CIS_CIP_bdpm.txt, reconstruit les libellés par CIP13 et optionnellement le taux par CIS.
/// En cas d'erreur réseau ou de format, retourne des maps vides.
Future<BdpmLabelsResult> loadBdpmLabels() async {
  final cisRes = await http.get(Uri.parse(CIS_BDPM_TXT_URL));
  final cipRes = await http.get(Uri.parse(CIS_CIP_BDPM_TXT_URL));
  if (cisRes.statusCode != 200 || cipRes.statusCode != 200) {
    return const BdpmLabelsResult(cip13ToLabel: {}, cisToTauxRemboursement: {});
  }

  final cisLines = cisRes.body.split(RegExp(r'\r?\n'));
  final cipLines = cipRes.body.split(RegExp(r'\r?\n'));

  final cisByCode = <String, ({String denom, String form})>{};
  for (final line in cisLines) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final cols = t.split('\t');
    if (cols.length <= _cisBdpmColFormePharmaceutique) continue;
    final cis = cols[_cisBdpmColCodeCis].replaceAll(RegExp(r'\D'), '').trim();
    if (cis.isEmpty) continue;
    cisByCode[cis] = (
      denom: normalizeText(fixEncoding(cols[_cisBdpmColDenomination].trim())),
      form: normalizeText(fixEncoding(cols[_cisBdpmColFormePharmaceutique].trim())),
    );
  }

  final cip13ToLabel = <String, String>{};
  final cisToTaux = <String, String>{};
  for (final line in cipLines) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final cols = t.split('\t');
    if (cols.length <= _cisCipColCip13) continue;
    final cis = cols[_cisCipColCis].replaceAll(RegExp(r'\D'), '').trim();
    final cip13 = cols[_cisCipColCip13].replaceAll(RegExp(r'\D'), '').trim();
    if (cip13.length != 13) continue;
    final libelleRaw = normalizeText(fixEncoding(cols[_cisCipColLibelle].trim()));
    final info = cisByCode[cis];
    final form = info?.form ?? '';
    final libelle = _simplifyPresentation(libelleRaw, form: form);
    final denom = info?.denom ?? '';
    final label = _buildLabel(denom: denom, form: form, libellePresentation: libelle);
    cip13ToLabel[cip13] = label;

    if (cols.length > _cisCipColTauxRemboursement) {
      final taux = cols[_cisCipColTauxRemboursement].trim();
      if (taux.isNotEmpty && RegExp(r'\d+').hasMatch(taux)) {
        final normalized = taux.endsWith('%') ? taux : '$taux %';
        cisToTaux[cis] = normalized;
      }
    }
  }

  return BdpmLabelsResult(cip13ToLabel: cip13ToLabel, cisToTauxRemboursement: cisToTaux);
}

/// Contenant canonique selon la forme pharmaceutique : pommade → tube, comprimé → boîte, collyre/sirop/suspension buvable → flacon, injectable → seringue.
String? _canonicalContainerForForm(String form) {
  final f = form.toLowerCase();
  if (f.contains('pommade') || f.contains('crème') || (f.contains('gel') && !f.contains('gélule') && !f.contains('injectable'))) return 'tube';
  if (f.contains('comprimé') || f.contains('gélule')) return 'boîte';
  if (f.contains('collyre') || f.contains('sirop') || f.contains('suspension buvable')) return 'flacon';
  if (f.contains('injectable') || f.contains('solution injectable') || f.contains('suspension injectable')) return 'seringue';
  return null;
}

/// Simplifie la col C (présentation) : forme courte sans matériaux. Utilise la forme pharmaceutique pour le contenant canonique (tube/boîte/flacon/seringue).
String _simplifyPresentation(String s, {String form = ''}) {
  if (s.isEmpty) return s;
  String t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final canonical = _canonicalContainerForForm(form);

  // Flacon + seringue(s) pour administration orale (sirop, suspension buvable)
  final flaconSeringue = RegExp(
    r'^(\d+)\s*flacon[s]?\s*(?:en\s+brun\s*)?.*?de\s*(\d+)\s*ml\b',
    caseSensitive: false,
    dotAll: true,
  );
  final flaconMatch = flaconSeringue.firstMatch(t);
  if (flaconMatch != null && (canonical == 'flacon' || canonical == null)) {
    final hasSeringue = t.toLowerCase().contains('seringue') && t.toLowerCase().contains('administration orale');
    if (hasSeringue) {
      return '${flaconMatch.group(1)} flacon(s) de ${flaconMatch.group(2)} ml avec seringue(s) pour administration orale';
    }
    return '${flaconMatch.group(1)} flacon(s) de ${flaconMatch.group(2)} ml';
  }

  // Injectables : X seringue(s) de Y ml
  if (canonical == 'seringue') {
    final seringueMatch = RegExp(r'^(\d+)\s*(?:seringue[s]?|préremplie[s]?).*?(\d+)\s*ml\b', caseSensitive: false, dotAll: true).firstMatch(t);
    if (seringueMatch != null) {
      return '${seringueMatch.group(1)} seringue(s) de ${seringueMatch.group(2)} ml';
    }
    final seringueMatch2 = RegExp(r'^(\d+)\s*(?:seringue[s]?|préremplie[s]?)', caseSensitive: false).firstMatch(t);
    if (seringueMatch2 != null) return '${seringueMatch2.group(1)} seringue(s)';
  }

  // Formes courtes (replaceAllMapped avec groupes)
  t = t.replaceAllMapped(
    RegExp(r'plaquette[s]?\s*(?:thermoformée[s]?)?\s*(?:[^d]*(?:PVC|aluminium)[^d]*)?de\s*(\d+)\s*gélule[s]?', caseSensitive: false),
    (m) => (canonical == 'boîte') ? '1 boîte(s) de ${m.group(1)} gélules' : 'plaquette de ${m.group(1)} gélules',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*récipient[s]?\s*unidose[s]?\s*(?:polyéthylène|polyethylène[^,]*)?', caseSensitive: false),
    (m) => '${m.group(1)} récipients unidoses',
  );
  t = t.replaceAllMapped(
    RegExp(r'pilulier[s]?\s*(?:polypropylène|polypropylene\s*)?de\s*(\d+)\s*comprimé[s]?', caseSensitive: false),
    (m) => (canonical == 'boîte') ? '1 boîte(s) de ${m.group(1)} comprimés' : 'pilulier de ${m.group(1)} comprimés',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*tube[s]?\s*(?:alumino-plastique|[^d]*aluminium[^d]*)?de\s*(\d+)\s*g\b', caseSensitive: false),
    (m) => (canonical == 'tube') ? '${m.group(1)} tube(s) de ${m.group(2)} g' : '${m.group(1)} tube de ${m.group(2)} g',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*flacon[s]?\s*(?:en\s+verre\s*)?de\s*(\d+)\s*ml\b', caseSensitive: false),
    (m) => (canonical == 'flacon') ? '${m.group(1)} flacon(s) de ${m.group(2)} ml' : '${m.group(1)} flacon de ${m.group(2)} ml',
  );
  t = t.replaceAllMapped(
    RegExp(r'flacon[s]?\s*(?:en\s+verre|polyéthylène|polyethylène)[^d]*de\s*(\d+)\s*(ml|g)\b', caseSensitive: false),
    (m) => (canonical == 'flacon') ? '1 flacon(s) de ${m.group(1)} ${m.group(2)}' : 'flacon de ${m.group(1)} ${m.group(2)}',
  );
  t = t.replaceAllMapped(
    RegExp(r'boîte[s]?\s*(?:[^d]*(?:PVC|aluminium|polyéthylène|polypropylène)[^d]*)?de\s*(\d+)\s*comprimé[s]?', caseSensitive: false),
    (m) => (canonical == 'boîte') ? '1 boîte(s) de ${m.group(1)} comprimés' : 'boîte de ${m.group(1)} comprimés',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*sachet[s]?-dose[s]?\s*(?:p[ao]pier\s*aluminium[^,]*)?\s*(?:de\s*(\d+(?:[,.]\d+)?)\s*g)?', caseSensitive: false),
    (m) => m.group(2) != null ? '${m.group(1)} sachets-doses de ${m.group(2)} g' : '${m.group(1)} sachets-doses',
  );

  // Retirer mentions de matériaux restantes
  t = t.replaceAll(RegExp(r'(?:thermoformée[s]?|PVC|aluminium|polyéthylène|polyethylène|polypropylène|polypropylene|PEHD|PELD|verre|alumino-plastique)\s*', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'\s*\([^)]*(?:polyéthylène|polyethylène|polypropylène|aluminium|verre|PVC)[^)]*\)', caseSensitive: false), ' ');
  // (s) → s
  t = t.replaceAllMapped(RegExp(r'(\w+)\(s\)', caseSensitive: false), (m) => '${m.group(1)}s');
  return t.replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'[,;\s]+$'), '').replaceAll(RegExp(r'^[,;\s]+'), '').trim();
}

/// Construit le libellé normalisé : "DÉNOMINATION, forme, présentation" (dénomination en majuscules, forme et présentation en minuscules).
/// Ex. DOLIPRANE 2,4 POUR CENT, suspension buvable, 1 flacon(s) de 100 ml avec seringue(s) pour administration orale.
String _buildLabel({
  required String denom,
  required String form,
  required String libellePresentation,
}) {
  final denomTrim = denom.replaceAll(RegExp(r'\s+'), ' ').trim();
  final formTrim = form.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lib = libellePresentation
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final skipLib = lib.isEmpty ||
      lib.toLowerCase() == 'présentation active' ||
      lib.toLowerCase() == 'présentation abrogée';

  if (denomTrim.isEmpty && formTrim.isEmpty && skipLib) {
    return libellePresentation.trim();
  }

  final parts = <String>[];
  if (denomTrim.isNotEmpty) parts.add(denomTrim.toUpperCase());
  bool addForm = formTrim.isNotEmpty;
  if (addForm) {
    final formNorm = formTrim.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final libNorm = lib.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (formNorm.length >= 3 && libNorm.contains(formNorm)) addForm = false;
  }
  if (addForm) parts.add(formTrim.toLowerCase());
  if (skipLib) return parts.join(', ');
  if (parts.isEmpty) return lib.toLowerCase();
  // Enlever en début de présentation la forme si elle y figure déjà.
  String libDisplay = lib;
  if (formTrim.isNotEmpty && formTrim.length >= 3) {
    final formNorm = formTrim.toLowerCase().trim();
    final libLower = libDisplay.toLowerCase();
    if (libLower.startsWith(formNorm)) {
      libDisplay = libDisplay.substring(formNorm.length).replaceAll(RegExp(r'^[\s,;\-]+'), '').trim();
    } else if (libLower.contains(formNorm) && libLower.indexOf(formNorm) <= 2) {
      libDisplay = libDisplay.substring(libLower.indexOf(formNorm) + formNorm.length).replaceAll(RegExp(r'^[\s,;\-]+'), '').trim();
    }
  }
  if (libDisplay.isEmpty) return parts.join(', ');
  parts.add(libDisplay.toLowerCase());
  return parts.join(', ');
}

/// Indices CIS_COMPO_bdpm.txt (tab) : col A=0 (CIS), col D=3, E=4, F=5 pour "composition : D : E pour F".
const int _cisCompoColCis = 0;
const int _cisCompoColD = 3;
const int _cisCompoColE = 4;
const int _cisCompoColF = 5;

/// Charge CIS_COMPO_bdpm.txt et retourne CIS → "colD : colE pour colF" (première ligne par CIS ; si plusieurs substances, joint avec " ; ").
Future<Map<String, String>> loadCompositionBdpmByCis() async {
  try {
    final res = await http.get(Uri.parse(CIS_COMPO_BDPM_TXT_URL));
    if (res.statusCode != 200) return {};
    final lines = res.body.split(RegExp(r'\r?\n'));
    final out = <String, List<String>>{};
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final cols = t.split('\t');
      if (cols.length <= _cisCompoColF) continue;
      final cis = cols[_cisCompoColCis].replaceAll(RegExp(r'\D'), '').trim();
      if (cis.isEmpty) continue;
      final d = cols[_cisCompoColD].trim();
      final e = cols[_cisCompoColE].trim();
      final f = cols[_cisCompoColF].trim();
      final phrase = '$d : $e pour $f';
      if (phrase == ' :  pour ') continue;
      out.putIfAbsent(cis, () => []).add(phrase);
    }
    return out.map((cis, list) => MapEntry(cis, list.join(' ; ')));
  } catch (_) {
    return {};
  }
}
