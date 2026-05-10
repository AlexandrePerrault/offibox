import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/normalize.dart';

import 'data_sources.dart';
import 'offiboxdata_fetch.dart';
import 'weleda_cip_resolver.dart';
import 'weleda_w_cip_asset.dart';

/// Parse les 2 CSVs Weleda (formules W + unitaires EH) et retourne des
/// [SearchResult] indexables par le moteur de recherche.
///
/// Chaque composant de la formule/unitaire est indexé dans [labelRaw]
/// pour qu'une recherche sur "ARNICA" ou "BELLADONNA" trouve les formules.
///
/// Les produits marqués indisponibles (croix "x") portent le commentaire
/// « Médicament actuellement indisponible — source Weleda, MAJ dd/mm/yyyy ».
Future<List<SearchResult>> parseWeleda() async {
  final results = <SearchResult>[];
  final wcipMap = await WeledaWcipAsset.instance.loadMap();

  final responses = await Future.wait([
    OffiboxDataFetch.get(WELEDA_FORMULES_CSV_URL)
        .catchError((_) => http.Response('', 0)),
    OffiboxDataFetch.get(WELEDA_UNITAIRES_CSV_URL)
        .catchError((_) => http.Response('', 0)),
  ]);

  final rFormules = responses[0];
  final rUnitaires = responses[1];

  if (rFormules.statusCode == 200) {
    results.addAll(_parseFormules(rFormules.body, wcipMap));
  }
  if (rUnitaires.statusCode == 200) {
    results.addAll(_parseUnitaires(rUnitaires.body));
  }

  return results;
}

List<SearchResult> _parseFormules(
  String body,
  Map<String, WeledaWcipRow> wcipMap,
) {
  final lines = const LineSplitter().convert(body);
  if (lines.length <= 1) return [];

  final results = <SearchResult>[];

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final row =
        trimmed.split(';').map((s) => s.replaceAll('"', '').trim()).toList();
    if (row.length < 6) continue;

    final formule = row[0];
    final composition = row[1];
    final forme = row[2];
    final contenance = row[3];
    final eh = row[4];
    final indisponible = row[5].toLowerCase() == 'x';
    final dateMaj = row.length > 6 ? row[6] : '';

    if (formule.isEmpty) continue;

    final label = '$formule — $forme $contenance';
    final labelNorm = normalizeText(label).toUpperCase();

    final searchableRaw = '$formule $composition $eh $forme';

    final commentaire = _buildCommentaire(indisponible, dateMaj);
    final compDisplay = WeledaCipResolver.compositionForDisplay(composition);

    var sr = SearchResult(
      source: SourceType.weleda,
      label: labelNorm,
      labelRaw: normalizeText(searchableRaw).toUpperCase(),
      laboratory: 'WELEDA',
      url:
          'https://assets.weleda.com/binaries/content/assets/pdf/fr/pharma/liste-w-2025-decembre.pdf',
      commentaire: commentaire,
      badge1Name: 'Composition',
      badge1Url: null,
      groupLabel: compDisplay,
      weledaEhRegistration: eh,
      nsfp: false,
      hospitalOnly: false,
      iconUrl: 'assets/icons/weleda_com.png',
    );

    final wCode = WeledaCipResolver.extractWeledaWCode(labelNorm);
    if (wCode != null) {
      final row = wcipMap[wCode.toUpperCase()];
      if (row != null) {
        final cis = row.cis;
        sr = sr.copyWith(
          cip13: row.cip13,
          cip7: row.cip13.substring(0, 7),
          cis: cis,
          url: cis != null && cis.isNotEmpty
              ? 'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cis/extrait#tab-rcp'
              : sr.url,
        );
      }
    }

    results.add(sr);
  }

  return results;
}

List<SearchResult> _parseUnitaires(String body) {
  final lines = const LineSplitter().convert(body);
  if (lines.length <= 1) return [];

  final results = <SearchResult>[];

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final row =
        trimmed.split(';').map((s) => s.replaceAll('"', '').trim()).toList();
    if (row.length < 5) continue;

    final designation = row[0];
    final forme = row[1];
    final contenance = row[2];
    final eh = row[3];
    final indisponible = row[4].toLowerCase() == 'x';
    final dateMaj = row.length > 5 ? row[5] : '';

    if (designation.isEmpty) continue;

    final label = '$designation — $forme $contenance';
    final labelNorm = normalizeText(label).toUpperCase();

    final searchableRaw = '$designation $eh $forme';

    final commentaire = _buildCommentaire(indisponible, dateMaj);

    results.add(
      SearchResult(
        source: SourceType.weleda,
        label: labelNorm,
        labelRaw: normalizeText(searchableRaw).toUpperCase(),
        laboratory: 'WELEDA',
        url:
            'https://assets.weleda.com/binaries/content/assets/pdf/fr/pharma/liste-eh-2025-decembre.pdf',
        commentaire: commentaire,
        weledaEhRegistration: eh,
        nsfp: false,
        hospitalOnly: false,
        iconUrl: 'assets/icons/weleda_com.png',
      ),
    );
  }

  return results;
}

String _buildCommentaire(bool indisponible, String dateMaj) {
  final parts = <String>[];
  if (indisponible) {
    parts.add('Médicament actuellement indisponible');
  }
  final src =
      dateMaj.isNotEmpty ? 'Source Weleda, MAJ $dateMaj' : 'Source Weleda';
  parts.add(src);
  return parts.join(' — ');
}
