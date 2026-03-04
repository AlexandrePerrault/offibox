import 'package:offibox/models/search_result.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';

/// Construit un slug type ANSM à partir du libellé et du laboratoire (ex. "doliprane-2-4-pour-cent-suspension-buvable-opella-healthcare-france-sas").
/// Utilisé pour comparer au slug extrait de l'URL du rappel et cibler uniquement le produit concerné.
String slugFromProduct(SearchResult item) {
  final raw = item.labelRaw.trim();
  final lab = item.laboratory.trim();
  var combined = lab.isEmpty ? raw : '$raw – $lab';
  // Aligner avec les libellés ANSM : "2,4 %" → "2,4 Pour cent" pour le slug
  combined = combined.replaceAll(RegExp(r'\s*%\s*'), ' pour cent ');
  return _toAnsmSlug(combined);
}

/// Normalise une chaîne au format slug des URLs ANSM (minuscules, espaces/ponctuation → tirets).
String _toAnsmSlug(String s) {
  if (s.isEmpty) return '';
  var t = s
      .toLowerCase()
      .replaceAll(RegExp(r'[\u2013\u2014–]'), '-')
      .replaceAll(' - ', '-')
      .replaceAll(',', '-')
      .replaceAll(RegExp(r'\s+'), '-');
  // Accents → ascii pour correspondre aux URLs ANSM
  t = t
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[ïî]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return t;
}

/// Indique si le résultat correspond au dernier rappel ANSM.
/// On matche par slug exact (URL du rappel) pour ne pas afficher l'info sur tous les produits contenant le même mot (ex. uniquement "Doliprane 2,4 % suspension" et pas tous les Doliprane).
bool isProductConcernedByLastRappel(SearchResult item, AnsmRappelItem rappel) {
  // 1) Si le rappel a un slug (ex. doliprane-2-4-pour-cent-suspension-buvable-opella-healthcare-france-sas), matching strict par slug
  final rappelSlug = rappel.slug?.trim();
  if (rappelSlug != null && rappelSlug.isNotEmpty) {
    final productSlug = slugFromProduct(item);
    if (productSlug.isNotEmpty && productSlug == rappelSlug) return true;
    // Pas de match par slug → pas concerné (on n'utilise plus le "premier mot" pour éviter les faux positifs)
    return false;
  }
  // 2) Fallback si pas de slug : pas d'alerte (évite "tous les produits contenant X")
  return false;
}

/// Retourne le rappel correspondant au produit (liste triée par date décroissante) pour le badge ligne 3, ou null.
AnsmRappelItem? findMatchingRappel(SearchResult item, List<AnsmRappelItem> rappels) {
  final productSlug = slugFromProduct(item);
  if (productSlug.isEmpty) return null;
  for (final rappel in rappels) {
    final rappelSlug = rappel.slug?.trim();
    if (rappelSlug != null && rappelSlug.isNotEmpty && productSlug == rappelSlug) {
      return rappel;
    }
  }
  return null;
}

/// Indique si la date du rappel est à moins de [maxDays] jours.
bool isRappelRecent(AnsmRappelItem rappel, {int maxDays = 15}) {
  final dateStr = rappel.dateStr;
  if (dateStr == null || dateStr.isEmpty) return false;
  final parts = dateStr.split('/');
  if (parts.length != 3) return false;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return false;
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  DateTime rappelDate;
  try {
    rappelDate = DateTime(year, month, day);
  } catch (_) {
    return false;
  }
  final now = DateTime.now();
  final diff = now.difference(rappelDate).inDays;
  return diff >= 0 && diff < maxDays;
}
