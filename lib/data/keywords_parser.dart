import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

import 'offiboxdata_fetch.dart';

/// CSV mots-clés (outils_metier.csv / sites_web.csv sur offiboxdata) :
/// Col A(0) = mots-clés, B(1) = libellé ligne 1, C(2) = date apparition, D(3) = logo, E(4) = url principale,
/// F(5)-G(6) = badge 1 (libellé + url), H(7)-I(8) = badge 2, J(9)-K(10) = badge 3,
/// L(11)-M(12) = badge 4, N(13)-O(14) = badge 5, P(15)-Q(16) = badge 6.
Future<List<SearchResult>> parseKeywords(String url, {SourceType sourceType = SourceType.keyword}) async {
  final response = await OffiboxDataFetch.get(url);
  if (response.statusCode != 200) return [];

  final lines = const LineSplitter().convert(response.body);
  if (lines.length <= 1) return [];

  final results = <SearchResult>[];

  String cellAt(List<String> row, int i) {
    if (i >= row.length) return '';
    return row[i].replaceAll('"', '').replaceAll("'", '').trim();
  }

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final sep = trimmed.contains(';') ? ';' : ',';
    final row = trimmed.split(sep).map((s) => s.trim()).toList();
    if (row.isEmpty) continue;

    final colA = cellAt(row, 0);
    if (colA.isEmpty) continue;

    final colANormalized = normalizeText(colA);
    final libelleLigne1 = normalizeText(cellAt(row, 1));
    final dateApparition = cellAt(row, 2);
    // Col D : logo — normaliser \ en / pour Image.asset / SvgPicture.asset. Vide ou placeholder → pas d'icône.
    final iconPathRaw = cellAt(row, 3);
    final _raw = iconPathRaw.replaceAll(r'\', '/').trim();
    final bool iconCellEmpty = _raw.isEmpty ||
        _raw == '-' ||
        _raw.toLowerCase() == 'n/a' ||
        _raw.toLowerCase() == 'na' ||
        _raw == '.';
    // Ne garder que les chemins qui ressemblent à un asset (ex. assets/... ou .png/.svg)
    final iconPath = !iconCellEmpty &&
            _raw.isNotEmpty &&
            (_raw.toLowerCase().contains('assets/') ||
                _raw.toLowerCase().contains('.png') ||
                _raw.toLowerCase().contains('.svg') ||
                _raw.toLowerCase().contains('.webp') ||
                _raw.toLowerCase().contains('.jpg'))
        ? _raw
        : '';
    final urlPrincipale = cellAt(row, 4);
    final nomBadge1 = cellAt(row, 5);
    final urlBadge1 = cellAt(row, 6);
    final nomBadge2 = cellAt(row, 7);
    final urlBadge2 = cellAt(row, 8);
    final nomBadge3 = cellAt(row, 9);
    final urlBadge3 = cellAt(row, 10);
    final nomBadge4 = cellAt(row, 11);
    final urlBadge4 = cellAt(row, 12);
    final nomBadge5 = cellAt(row, 13);
    final urlBadge5 = cellAt(row, 14);
    final nomBadge6 = cellAt(row, 15);
    final urlBadge6 = cellAt(row, 16);

    String? badge1Name;
    String? badge1Url;
    String? badge2Name;
    String? badge2Url;
    String? badge3Name;
    String? badge3Url;
    String? badge4Name;
    String? badge4Url;
    String? badge5Name;
    String? badge5Url;
    String? badge6Name;
    String? badge6Url;

    if (nomBadge1.isNotEmpty && urlBadge1.isNotEmpty) {
      badge1Name = nomBadge1;
      badge1Url = urlBadge1;
    } else if (urlPrincipale.isNotEmpty && sourceType == SourceType.keyword) {
      badge1Name = 'Lien';
      badge1Url = urlPrincipale;
    }
    if (nomBadge2.isNotEmpty && urlBadge2.isNotEmpty) {
      badge2Name = nomBadge2;
      badge2Url = urlBadge2;
    }
    if (nomBadge3.isNotEmpty && urlBadge3.isNotEmpty) {
      badge3Name = nomBadge3;
      badge3Url = urlBadge3;
    }
    if (nomBadge4.isNotEmpty && urlBadge4.isNotEmpty) {
      badge4Name = nomBadge4;
      badge4Url = urlBadge4;
    }
    if (nomBadge5.isNotEmpty && urlBadge5.isNotEmpty) {
      badge5Name = nomBadge5;
      badge5Url = urlBadge5;
    }
    if (nomBadge6.isNotEmpty && urlBadge6.isNotEmpty) {
      badge6Name = nomBadge6;
      badge6Url = urlBadge6;
    }

    final url = urlPrincipale.isNotEmpty
        ? urlPrincipale
        : (badge1Url ?? badge2Url ?? badge3Url ?? badge4Url ?? badge5Url ?? badge6Url);

    final searchResult = SearchResult(
      source: sourceType,
      labelRaw: colANormalized.toUpperCase(),
      label: colANormalized.toUpperCase(),
      cip13: null,
      cis: null,
      url: url,
      isPdf: (url ?? '').toLowerCase().endsWith('.pdf'),
      nsfp: false,
      hospitalOnly: false,
      laboratory: '',
      meddisparUrl: null,
      commentaire: libelleLigne1.isNotEmpty ? libelleLigne1 : null,
      keywordAppearanceDate: dateApparition.isNotEmpty ? dateApparition : null,
      iconUrl: iconPath.isNotEmpty ? iconPath : null,
      badge1Name: badge1Name,
      badge1Url: badge1Url,
      badge2Name: badge2Name,
      badge2Url: badge2Url,
      badge3Name: badge3Name,
      badge3Url: badge3Url,
      badge4Name: badge4Name,
      badge4Url: badge4Url,
      badge5Name: badge5Name,
      badge5Url: badge5Url,
      badge6Name: badge6Name,
      badge6Url: badge6Url,
    );

    // Un mot dans la cellule = un mot-clé (séparation par espaces)
    final keywords = colANormalized.split(RegExp(r'\s+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (keywords.isEmpty) {
      results.add(searchResult);
    } else {
      for (final kw in keywords) {
        final kwNorm = normalizeText(kw);
        results.add(searchResult.copyWith(
          labelRaw: kwNorm.toUpperCase(),
          label: kwNorm.toUpperCase(),
        ),);
      }
    }
  }

  return results;
}
