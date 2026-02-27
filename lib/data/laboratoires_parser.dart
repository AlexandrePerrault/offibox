import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';
import 'package:offibox/models/source_type.dart';

/// Laboratoires de secours si le CSV est vide ou échoue (pour que VIATRIS etc. restent visibles).
const String _viatrisEspacePro = 'https://www.monespacepharmacien.viatris.com/s/login/?language=fr';
const String _viatrisEspaceProAlt = 'https://www.monespacepharmacien.viatris.com/s/login/?language=fr&ec=302&startURL=%2Fs%2F';
const String _viatrisService = 'https://service.viatris.fr/users/login';
const String _viatrisMyris = 'https://myris.viatris.fr/login';

List<SearchResult> get defaultLaboratoiresFallback => [
  SearchResult(
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
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Erreur chargement LABORATOIRES.csv');
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

    // Col 1 = icône (path assets/... ou "ok" à ignorer)
    final rawIcon = _v(row, 1);
    final iconUrl = (rawIcon != null &&
            rawIcon.isNotEmpty &&
            (rawIcon.startsWith('assets/') || rawIcon.contains('.svg') || rawIcon.contains('.png')))
        ? rawIcon
        : null;

    // F=5 Espace pro, G=6 Catalogue, H=7, I=8 nom site 2, J=9 url, K=10 nom badge 4, L=11 url
    final urlEspacePro = _v(row, 5);
    final urlCatalogue = _v(row, 6);
    final urlH = _v(row, 7);
    final nomSite2 = _v(row, 8);
    final urlSite2 = _v(row, 9);
    final badge4Name = _v(row, 10);
    final badge4Url = _v(row, 11);

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
        badge2Name: urlCatalogue != null && urlCatalogue.isNotEmpty ? 'Catalogue' : null,
        badge2Url: urlCatalogue,
        badge3Name: (urlH != null && urlH.isNotEmpty) ? 'Espace pro 2' : nomSite2,
        badge3Url: (urlH != null && urlH.isNotEmpty) ? urlH : urlSite2,
        badge4Name: badge4Name,
        badge4Url: badge4Url,
      ),
    );
  }

  return results;
}

String? _v(List<String> row, int index) {
  if (index >= row.length) return null;
  return row[index].isEmpty ? null : row[index];
}
