import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

import 'offiboxdata_fetch.dart';
import 'package:offibox/models/source_type.dart';

/// Laboratoires de secours si le CSV est vide ou échoue (pour que VIATRIS etc. restent visibles).
const String _viatrisEspacePro = 'https://www.monespacepharmacien.viatris.com/s/login/?language=fr';
const String _viatrisService = 'https://service.viatris.fr/users/login';
const String _viatrisMyris = 'https://myris.viatris.fr/login';

List<SearchResult> get defaultLaboratoiresFallback => [
  const SearchResult(
    label: 'VIATRIS',
    labelRaw: 'VIATRIS',
    source: SourceType.catalogue,
    laboratory: 'VIATRIS',
    cip13: null,
    cis: null,
    nsfp: false,
    hospitalOnly: false,
    iconUrl: 'assets/icons/viatris.svg',
    phone: '0800 30 31 32',
    fax: '0800 30 31 33',
    email: null,
    catalogueUrl: null,
    url: _viatrisEspacePro,
    meddisparUrl: null,
    isPdf: false,
    badge1Name: 'Espace pro',
    badge1Url: _viatrisEspacePro,
    badge2Name: null,
    badge2Url: null,
    badge3Name: 'service.viatris.fr',
    badge3Url: _viatrisService,
    badge4Name: 'MYRIS',
    badge4Url: _viatrisMyris,
  ),
];

Future<List<SearchResult>> parseLaboratoires(String url) async {
  try {
    final response = await OffiboxDataFetch.get(url);

    if (response.statusCode != 200) {
      if (kDebugMode) debugPrint('[Offibox] Laboratoires non disponibles (HTTP ${response.statusCode})');
      return [];
    }

    final body = response.body.replaceAll('\uFEFF', '').trim();
    final lines = const LineSplitter().convert(body);
    final results = <SearchResult>[];

    for (int i = 1; i < lines.length; i++) {
    final row = lines[i]
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();

    final firstCol = row.isNotEmpty ? row[0].replaceAll(RegExp(r'[\r\n]'), '').trim() : '';
    if (row.isEmpty || firstCol.isEmpty) continue;

    final label = firstCol.toUpperCase();
    if (label.isEmpty) continue;

    // Col 1 = icône (path assets/... ou "ok" à ignorer). Normaliser \ en / pour Flutter asset bundle.
    final rawIcon = _v(row, 1);
    final iconUrl = (rawIcon != null &&
            rawIcon.isNotEmpty &&
            (rawIcon.startsWith('assets/') || rawIcon.contains('.svg') || rawIcon.contains('.png')))
        ? rawIcon.replaceAll(r'\', '/')
        : null;

    // LABORATOIRES.csv : F=5 espace pro (URL), G=6 catalogue (URL), H=7 tarif,
    // I=8 libellé badge 2, J=9 URL badge 2, K=10 libellé badge 3, L=11 URL badge 3,
    // M=12 libellé badge 4, N=13 URL badge 4
    final urlEspacePro = _v(row, 5);   // F
    final urlCatalogue = _v(row, 6);   // G
    final labelBadge2 = _v(row, 8);    // I
    final urlBadge2 = _v(row, 9);      // J
    final labelBadge3 = _v(row, 10);   // K
    final urlBadge3 = _v(row, 11);     // L
    final labelBadge4 = _v(row, 12);   // M
    final urlBadge4 = _v(row, 13);      // N

    // Badge 2 : I (libellé) + J (URL). Si vides → "Catalogue" + G pour ouvrir le panneau catalogue.
    final bool hasBadge2 = (labelBadge2 != null && labelBadge2.isNotEmpty && urlBadge2 != null && urlBadge2.isNotEmpty);
    final String? name2 = hasBadge2 ? labelBadge2 : (urlCatalogue != null && urlCatalogue.isNotEmpty ? 'Catalogue' : null);
    final String? url2 = hasBadge2 ? urlBadge2 : urlCatalogue;

    // Badge 3 : K (libellé) + L (URL)
    final bool hasBadge3 = (labelBadge3 != null && labelBadge3.isNotEmpty && urlBadge3 != null && urlBadge3.isNotEmpty);

    // Badge 4 : M (nom du badge) + N (URL correspondante)
    final bool hasBadge4 = (labelBadge4 != null && labelBadge4.isNotEmpty && urlBadge4 != null && urlBadge4.isNotEmpty);

    results.add(
      SearchResult(
        label: label,
        labelRaw: label,
        source: SourceType.catalogue,
        laboratory: label,
        cip13: null,
        cis: null,
        nsfp: false,
        hospitalOnly: false,
        iconUrl: iconUrl,
        phone: _v(row, 2),
        fax: _v(row, 3),
        email: _v(row, 4),
        catalogueUrl: urlCatalogue,
        url: urlEspacePro ?? urlCatalogue,
        meddisparUrl: null,
        isPdf: (urlCatalogue ?? '').toLowerCase().endsWith('.pdf'),
        badge1Name: urlEspacePro != null && urlEspacePro.isNotEmpty ? 'Espace pro' : null,
        badge1Url: urlEspacePro,
        badge2Name: name2,
        badge2Url: url2,
        badge3Name: hasBadge3 ? labelBadge3 : null,
        badge3Url: hasBadge3 ? urlBadge3 : null,
        badge4Name: hasBadge4 ? labelBadge4 : null,
        badge4Url: hasBadge4 ? urlBadge4 : null,
      ),
    );
  }

    return results;
  } catch (e) {
    if (kDebugMode) debugPrint('[Offibox] Laboratoires erreur: $e');
    return [];
  }
}

String? _v(List<String> row, int index) {
  if (index >= row.length) return null;
  return row[index].isEmpty ? null : row[index];
}
