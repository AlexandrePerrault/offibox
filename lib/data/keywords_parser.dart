import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

/// CSV mots-clés (outils_metier.csv / sites_web.csv sur offiboxdata) :
/// Col 0 = keyword tapé, Col 1 = mot affiché ligne 1, Col 2 = icône (ex. assets/icons/icone_BDNM.png),
/// Col 3 = url ligne 1, Col 4-5 = nom/url badge 1, Col 6-7 = badge 2, Col 8-9 = badge 3.
Future<List<SearchResult>> parseKeywords(String url, {SourceType sourceType = SourceType.keyword}) async {
  final response = await http.get(Uri.parse(url));
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
    // Col C : normaliser \ en / pour que Image.asset / SvgPicture.asset trouvent l'asset
    final iconPathRaw = cellAt(row, 2);
    final iconPath = iconPathRaw.isNotEmpty
        ? iconPathRaw.replaceAll(r'\', '/')
        : '';
    final urlLigne1 = cellAt(row, 3);
    final nomBadge1 = cellAt(row, 4);
    final urlBadge1 = cellAt(row, 5);
    final nomBadge2 = cellAt(row, 6);
    final urlBadge2 = cellAt(row, 7);
    final nomBadge3 = cellAt(row, 8);
    final urlBadge3 = cellAt(row, 9);

    String? badge1Name;
    String? badge1Url;
    String? badge2Name;
    String? badge2Url;
    String? badge3Name;
    String? badge3Url;

    if (nomBadge1.isNotEmpty && urlBadge1.isNotEmpty) {
      badge1Name = nomBadge1;
      badge1Url = urlBadge1;
    } else if (urlLigne1.isNotEmpty && sourceType == SourceType.keyword) {
      badge1Name = 'Lien';
      badge1Url = urlLigne1;
    }
    if (nomBadge2.isNotEmpty && urlBadge2.isNotEmpty) {
      badge2Name = nomBadge2;
      badge2Url = urlBadge2;
    }
    if (nomBadge3.isNotEmpty && urlBadge3.isNotEmpty) {
      badge3Name = nomBadge3;
      badge3Url = urlBadge3;
    }

    final url = urlLigne1.isNotEmpty
        ? urlLigne1
        : (badge1Url ?? badge2Url ?? badge3Url);

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
      iconUrl: iconPath.isNotEmpty ? iconPath : null,
      badge1Name: badge1Name,
      badge1Url: badge1Url,
      badge2Name: badge2Name,
      badge2Url: badge2Url,
      badge3Name: badge3Name,
      badge3Url: badge3Url,
    );

    final keywords = colANormalized.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
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
