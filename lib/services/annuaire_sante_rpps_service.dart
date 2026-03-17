import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:csv/csv.dart';
import 'package:offibox/data/data_sources.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';

/// Base URL de l'API FHIR Annuaire Santé (interop.esante.gouv.fr / gateway).
const String _kFhirAnnuaireBase =
    'https://gateway.api.esante.gouv.fr/fhir/v2';

/// Clé API (optionnelle). Si absente, recherche via CSV data.gouv.fr (GitHub).
String _apiKey() =>
    const String.fromEnvironment('ESANTE_API_KEY', defaultValue: '');

/// Service de recherche dans l'annuaire RPPS.
/// Avec ESANTE_API_KEY : API FHIR + cache Cloud Function.
/// Sans clé : CSV issu de [ANNUAIRE_PS_DATA_GOUV_SOURCE] (pipeline annuaire_ps_2026 → offiboxdata).
class AnnuaireSanteRppsService {
  AnnuaireSanteRppsService();

  List<List<String>>? _csvRows;

  /// Score de préférence structure (plus petit = affiché en premier).
  /// Libéral / cabinet avant hôpital.
  static int preferredStructureScore(SearchResult hit) {
    final gl = (hit.groupLabel ?? '').toLowerCase();
    if (gl.contains('cabinet') || gl.contains('libéral') || gl.contains('officine')) return 0;
    if (gl.contains('hopital') || gl.contains('hôpital') || gl.contains('chr') || gl.contains('chu')) return 2;
    return 1;
  }

  /// Ordre d'affichage par profession (tri).
  static int professionDisplayOrder(String label) {
    final l = label.toLowerCase();
    if (l.contains('médecin') || l.contains('medecin')) return 0;
    if (l.contains('pharmacien')) return 1;
    if (l.contains('dentiste')) return 2;
    if (l.contains('sage-femme')) return 3;
    if (l.contains('infirmier')) return 4;
    return 5;
  }

  Future<List<SearchResult>> search({
    String? rpps,
    String? structure,
    String? nom,
    String? prenom,
    int limit = 20,
  }) async {
    final key = _apiKey();

    try {
      if (key.isEmpty) {
        // Sans clé FHIR : recherche via CSV data.gouv.fr (pipeline offiboxdata)
        final st = structure?.trim() ?? '';
        final no = nom?.trim() ?? '';
        return _searchViaCsv(
          rpps: rpps?.trim(),
          structure: st.length >= 2 ? st : null,
          nom: no.isNotEmpty ? no : null,
          prenom: prenom?.trim(),
          limit: limit,
        );
      }

      // Avec clé : 1) cache Cloud Function 2) fallback FHIR direct
      final st = structure?.trim() ?? '';
      final no = nom?.trim() ?? '';
      final cached = await _searchViaCache(
        rpps: rpps?.trim(),
        structure: st.length >= 2 ? st : null,
        nom: no.isNotEmpty ? no : null,
        prenom: prenom?.trim(),
        limit: limit,
        apiKey: key,
      );
      if (cached != null) return cached;

      if (rpps != null && rpps.trim().isNotEmpty) {
        return _searchByRpps(rpps.trim(), limit, key);
      }
      if (structure != null && structure.trim().length >= 2) {
        return _searchByStructure(structure.trim(), limit, key);
      }
      if (nom != null && nom.trim().isNotEmpty) {
        return _searchByName(
          nom.trim(),
          prenom?.trim() ?? '',
          limit,
          key,
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Offibox] Annuaire PS: $e');
        debugPrint(st.toString());
      }
    }
    return [];
  }

  /// Recherche dans le CSV data.gouv.fr (format pipeline annuaire_ps_2026).
  /// Colonnes : RPPS, Nom, Prenom, Titre, Adresse, Code_postal, Ville, Telephone, Nom_structure.
  Future<List<SearchResult>> _searchViaCsv({
    String? rpps,
    String? structure,
    String? nom,
    String? prenom,
    required int limit,
  }) async {
    if (rpps == null && structure == null && (nom == null || nom.isEmpty)) {
      return [];
    }
    try {
      _csvRows ??= await _loadAnnuaireCsv();
      if (_csvRows == null || _csvRows!.length < 2) return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[Offibox] Annuaire CSV: $e');
      return [];
    }
    final rows = _csvRows!;
    final header = rows[0].map((c) => c.toString().toLowerCase()).toList();
    final idxRpps = header.indexOf('rpps');
    final idxNom = header.indexOf('nom');
    final idxPrenom = header.indexOf('prenom');
    final idxTitre = header.indexOf('titre');
    final idxAdresse = header.indexOf('adresse');
    final idxCp = header.indexOf('code_postal');
    final idxVille = header.indexOf('ville');
    final idxTel = header.indexOf('telephone');
    final idxStructure = header.indexOf('nom_structure');

    if (idxRpps < 0) return [];

    final results = <SearchResult>[];
    final lim = limit.clamp(1, 100);

    String cell(List<String> row, int i) =>
        (i >= 0 && i < row.length) ? row[i].trim() : '';

    for (var i = 1; i < rows.length && results.length < lim; i++) {
      final row = rows[i].map((c) => c.toString()).toList();
      final rowRpps = cell(row, idxRpps).replaceAll(RegExp(r'\D'), '');
      final rowNom = cell(row, idxNom).toLowerCase();
      final rowPrenom = cell(row, idxPrenom).toLowerCase();
      final rowStructure = cell(row, idxStructure).toLowerCase();

      bool match = false;
      if (rpps != null && rpps.isNotEmpty) {
        final q = rpps.replaceAll(RegExp(r'\D'), '');
        match = rowRpps == q || rowRpps.contains(q) || q.contains(rowRpps);
      } else if (structure != null && structure.isNotEmpty) {
        match = rowStructure.contains(structure.toLowerCase());
      } else if (nom != null && nom.isNotEmpty) {
        final qNom = nom.toLowerCase();
        final qPrenom = (prenom ?? '').toLowerCase();
        match = rowNom.contains(qNom) || rowPrenom.contains(qNom);
        if (match && qPrenom.isNotEmpty) {
          match = rowPrenom.contains(qPrenom) || rowNom.contains(qPrenom);
        }
      }
      if (!match) continue;

      final titre = cell(row, idxTitre);
      final labelParts = [cell(row, idxPrenom), cell(row, idxNom)]
          .where((s) => s.isNotEmpty)
          .join(' ');
      final label = titre.isNotEmpty
          ? '$labelParts, $titre'
          : labelParts;

      final addr = [
        cell(row, idxAdresse),
        [cell(row, idxCp), cell(row, idxVille)].join(' ').trim(),
      ].where((s) => s.isNotEmpty).join(', ');
      final dept = cell(row, idxCp).length >= 2
          ? cell(row, idxCp).substring(0, 2)
          : null;

      results.add(
        SearchResult(
          label: label,
          labelRaw: label,
          source: SourceType.annuaireSanteRpps,
          laboratory: cell(row, idxStructure),
          cip13: rowRpps.isNotEmpty ? rowRpps : null,
          groupLabel: cell(row, idxStructure),
          departement: dept,
          address: addr.isNotEmpty ? addr : null,
          phone: cell(row, idxTel).isNotEmpty ? cell(row, idxTel) : null,
        ),
      );
    }
    return results;
  }

  Future<List<List<String>>?> _loadAnnuaireCsv() async {
    final res = await http.get(Uri.parse(ANNUAIRE_PS_CSV_URL));
    if (res.statusCode != 200) return null;
    final text = utf8
        .decode(res.bodyBytes)
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    // Pipeline annuaire_ps_2026 utilise build_csv_content(delimiter=';')
    final parsed = const CsvToListConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    return parsed
        .map((r) => r.map((c) => c.toString()).toList())
        .toList();
  }

  /// Appel via Cloud Function (cache Firestore). Retourne null si échec → fallback FHIR direct.
  Future<List<SearchResult>?> _searchViaCache({
    String? rpps,
    String? structure,
    String? nom,
    String? prenom,
    required int limit,
    required String apiKey,
  }) async {
    if (rpps == null && structure == null && (nom == null || nom.isEmpty)) {
      return null;
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('searchAnnuairePS');
      final result = await callable.call<Map<String, dynamic>>({
        'rpps': rpps,
        'structure': structure,
        'nom': nom,
        'prenom': prenom,
        'limit': limit,
        'apiKey': apiKey,
      });
      final data = result.data as Map<String, dynamic>?;
      final body = data?['body'] as String?;
      if (body != null && body.isNotEmpty) {
        return _parsePractitionerBundle(body);
      }
    } catch (_) {
      // CF non déployée, erreur réseau, etc. → fallback
    }
    return null;
  }

  /// GET Practitioner?identifier=RPPS&_revinclude=PractitionerRole:practitioner&_include=PractitionerRole:organization
  Future<List<SearchResult>> _searchByRpps(
    String rpps,
    int limit,
    String apiKey,
  ) async {
    final onlyDigits = rpps.replaceAll(RegExp(r'\D'), '');
    if (onlyDigits.isEmpty) return [];

    final uri = Uri.parse('$_kFhirAnnuaireBase/Practitioner').replace(
      queryParameters: {
        'identifier': onlyDigits,
        'active': 'true',
        '_revinclude': 'PractitionerRole:practitioner',
        '_include': 'PractitionerRole:organization',
        '_count': '${limit.clamp(1, 50)}',
      },
    );
    final res = await http.get(
      uri,
      headers: {
        'ESANTE-API-KEY': apiKey,
        'Accept': 'application/fhir+json',
      },
    );
    if (res.statusCode != 200) return [];
    return _parsePractitionerBundle(res.body);
  }

  /// GET Practitioner?family=X&given=Y&_revinclude=...&_include=...
  Future<List<SearchResult>> _searchByName(
    String nom,
    String prenom,
    int limit,
    String apiKey,
  ) async {
    final params = <String, String>{
      'active': 'true',
      '_revinclude': 'PractitionerRole:practitioner',
      '_include': 'PractitionerRole:organization',
      '_count': '${limit.clamp(1, 50)}',
    };
    if (nom.isNotEmpty) params['name:family'] = nom;
    if (prenom.isNotEmpty) params['name:given'] = prenom;

    final uri = Uri.parse('$_kFhirAnnuaireBase/Practitioner')
        .replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: {
        'ESANTE-API-KEY': apiKey,
        'Accept': 'application/fhir+json',
      },
    );
    if (res.statusCode != 200) return [];
    return _parsePractitionerBundle(res.body);
  }

  /// GET Organization?name:contains=Q&_revinclude=PractitionerRole:organization&_include=PractitionerRole:practitioner
  Future<List<SearchResult>> _searchByStructure(
    String query,
    int limit,
    String apiKey,
  ) async {
    final uri = Uri.parse('$_kFhirAnnuaireBase/Organization').replace(
      queryParameters: {
        'name:contains': query,
        'active': 'true',
        '_revinclude': 'PractitionerRole:organization',
        '_include': 'PractitionerRole:practitioner',
        '_count': '${limit.clamp(1, 50)}',
      },
    );
    final res = await http.get(
      uri,
      headers: {
        'ESANTE-API-KEY': apiKey,
        'Accept': 'application/fhir+json',
      },
    );
    if (res.statusCode != 200) return [];
    return _parseOrganizationBundle(res.body);
  }

  /// Parse Bundle (Practitioner + PractitionerRole + Organization) → SearchResult list.
  List<SearchResult> _parsePractitionerBundle(String body) {
    final list = <SearchResult>[];
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return list;
    }
    if (json == null || json['resourceType'] != 'Bundle') return list;

    final entries = json['entry'] as List<dynamic>?;
    if (entries == null) return list;

    final practitioners = <String, Map<String, dynamic>>{};
    final roles = <Map<String, dynamic>>[];
    final organizations = <String, Map<String, dynamic>>{};

    for (final e in entries) {
      final res = (e as Map<String, dynamic>)['resource'] as Map<String, dynamic>?;
      if (res == null) continue;
      final type = res['resourceType'] as String?;
      final id = res['id'] as String?;
      if (id == null) continue;
      switch (type) {
        case 'Practitioner':
          practitioners[id] = res;
          break;
        case 'PractitionerRole':
          roles.add(res);
          break;
        case 'Organization':
          organizations[id] = res;
          break;
      }
    }

    for (final role in roles) {
      final pracRef = _refId(role['practitioner'] as Map<String, dynamic>?);
      final orgRef = _refId(role['organization'] as Map<String, dynamic>?);
      if (pracRef == null) continue;
      final practitioner = practitioners[pracRef];
      final organization = orgRef != null ? organizations[orgRef] : null;
      final sr = _buildResultFromRole(
        practitioner: practitioner,
        role: role,
        organization: organization,
      );
      if (sr != null) list.add(sr);
    }

    return list;
  }

  /// Parse Bundle (Organization + PractitionerRole + Practitioner) → SearchResult list.
  List<SearchResult> _parseOrganizationBundle(String body) {
    return _parsePractitionerBundle(body);
  }

  String? _refId(Map<String, dynamic>? ref) {
    if (ref == null) return null;
    final refStr = ref['reference'] as String?;
    if (refStr == null) return null;
    if (refStr.startsWith('Practitioner/')) return refStr.substring(13);
    if (refStr.startsWith('Organization/')) return refStr.substring(13);
    return null;
  }

  SearchResult? _buildResultFromRole({
    required Map<String, dynamic>? practitioner,
    required Map<String, dynamic> role,
    required Map<String, dynamic>? organization,
  }) {
    final rpps = _extractRpps(practitioner);
    if (rpps == null || rpps.isEmpty) return null;

    final labelParts = _practitionerDisplayName(practitioner);
    final profession = _roleProfession(role, practitioner);
    final label = profession != null && profession.isNotEmpty
        ? '$labelParts, $profession'
        : labelParts;

    final orgName = _orgName(organization);
    final address = _orgAddress(organization);
    final telecom = _telecom(role, organization);
    final departement = _departementFromAddress(organization);

    return SearchResult(
      label: label,
      labelRaw: label,
      source: SourceType.annuaireSanteRpps,
      laboratory: orgName ?? '',
      cip13: rpps,
      groupLabel: orgName,
      departement: departement,
      address: address,
      phone: telecom.phone,
      fax: telecom.fax,
    );
  }

  String? _extractRpps(Map<String, dynamic>? practitioner) {
    if (practitioner == null) return null;
    final ids = practitioner['identifier'] as List<dynamic>?;
    if (ids == null) return null;
    for (final id in ids) {
      final m = id is Map<String, dynamic> ? id : null;
      if (m == null) continue;
      final system = (m['system'] as String? ?? '').toLowerCase();
      final value = m['value'] as String?;
      if (value != null &&
          value.isNotEmpty &&
          (system.contains('rpps') || system.contains('810000005479'))) {
        return value.replaceAll(RegExp(r'\D'), '');
      }
    }
    return null;
  }

  String _practitionerDisplayName(Map<String, dynamic>? practitioner) {
    if (practitioner == null) return '';
    final names = practitioner['name'] as List<dynamic>?;
    if (names == null || names.isEmpty) return '';
    final n = names.first as Map<String, dynamic>;
    final prefix = (n['prefix'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(' ')
            .trim() ??
        '';
    final given = (n['given'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(' ')
            .trim() ??
        '';
    final family = n['family'] as String? ?? '';
    final parts = <String>[];
    if (prefix.isNotEmpty) parts.add(prefix);
    if (given.isNotEmpty) parts.add(given);
    if (family.isNotEmpty) parts.add(family);
    return parts.join(' ');
  }

  String? _roleProfession(
    Map<String, dynamic> role,
    Map<String, dynamic>? practitioner,
  ) {
    final codes = role['code'] as List<dynamic>?;
    if (codes != null && codes.isNotEmpty) {
      final c = codes.first as Map<String, dynamic>?;
      final coding = c?['coding'] as List<dynamic>?;
      if (coding != null && coding.isNotEmpty) {
        final firstCoding = coding.first as Map<String, dynamic>?;
        final display = firstCoding?['display'] as String?;
        if (display != null && display.isNotEmpty) return display;
      }
    }
    final quals = practitioner?['qualification'] as List<dynamic>?;
    if (quals != null && quals.isNotEmpty) {
      final q = quals.first as Map<String, dynamic>?;
      final code = q?['code'];
      final coding = (code is Map ? code['coding'] : null) as List<dynamic>?;
      if (coding != null && coding.isNotEmpty) {
        final firstCoding = coding.first as Map<String, dynamic>?;
        final display = firstCoding?['display'] as String?;
        if (display != null && display.isNotEmpty) return display;
      }
    }
    return null;
  }

  String? _orgName(Map<String, dynamic>? org) {
    if (org == null) return null;
    return org['name'] as String?;
  }

  String? _orgAddress(Map<String, dynamic>? org) {
    if (org == null) return null;
    final addrs = org['address'] as List<dynamic>?;
    if (addrs == null || addrs.isEmpty) return null;
    final a = addrs.first as Map<String, dynamic>;
    final lines = a['line'] as List<dynamic>?;
    final line = lines != null && lines.isNotEmpty
        ? (lines.map((e) => e.toString()).join(', '))
        : '';
    final postal = a['postalCode'] as String? ?? '';
    final city = a['city'] as String? ?? '';
    final parts = <String>[];
    if (line.isNotEmpty) parts.add(line);
    if (postal.isNotEmpty || city.isNotEmpty) {
      parts.add([postal, city].join(' ').trim());
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  ({String? phone, String? fax}) _telecom(
    Map<String, dynamic> role,
    Map<String, dynamic>? organization,
  ) {
    String? phone, fax;
    void from(List<dynamic>? list) {
      if (list == null) return;
      for (final t in list) {
        final m = t is Map<String, dynamic> ? t : null;
        if (m == null) continue;
        final system = m['system'] as String?;
        final value = m['value'] as String?;
        if (value == null) continue;
        if (system == 'phone') {
          if (m['use'] == 'fax') {
            fax ??= value;
          } else {
            phone ??= value;
          }
        }
      }
    }

    from(role['telecom'] as List<dynamic>?);
    if (organization != null) {
      from(organization['telecom'] as List<dynamic>?);
    }
    return (phone: phone, fax: fax);
  }

  String? _departementFromAddress(Map<String, dynamic>? org) {
    if (org == null) return null;
    final addrs = org['address'] as List<dynamic>?;
    if (addrs == null || addrs.isEmpty) return null;
    final postal = (addrs.first as Map<String, dynamic>)['postalCode'] as String?;
    if (postal == null || postal.length < 2) return null;
    return postal.substring(0, 2);
  }

  void dispose() {}
}
