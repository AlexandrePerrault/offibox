String normalizeLoose(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ô]'), 'o')
      .replaceAll(RegExp(r'[ùû]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '');
}
String normalizeLooseKeepSpaces(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Enlève les guillemets (", «, ») du texte affiché.
String stripGuillemets(String input) {
  if (input.isEmpty) return input;
  return input.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
}

String normalizeText(String input) {
  if (input.isEmpty) return input;

  return input
      // Guillemets à enlever (normalisation affichage)
      .replaceAll('"', '')
      .replaceAll('«', '')
      .replaceAll('»', '')
      // Espaces et caractères Latin / Unicode courants (barre d'infos, plus d'infos)
      .replaceAll('\u00A0', ' ') // no-break space → espace
      .replaceAll('\u2019', "'")  // apostrophe typographique → apostrophe ASCII
      .replaceAll('\u2018', "'")
      .replaceAll('\u201C', '"').replaceAll('\u201D', '"')
      // Caractères spéciaux en tête (ð, Â, ☐, etc.) — avant le nom du médicament
      .replaceFirst(RegExp(r'^[^A-Za-zÀ-ÿ0-9\s]+'), '')
      // dâÂ Â alcool → d'alcool (mojibake UTF-8)
      .replaceAll('dâÂ Â ', "d'")
      .replaceAll(RegExp(r'dâÂ\s*Â\s*'), "d'")
      // CSV BDM : ? = placeholder pour é (comprim?, s?cable, g?lule...)
      .replaceAll('sp?cialistes', 'spécialistes')
      .replaceAll('sp?cialiste', 'spécialiste')
      .replaceAll('s?cable', 'sécable')
      .replaceAll('s?cables', 'sécables')
      .replaceAll('comprim?', 'comprimé')
      .replaceAll('comprim?s', 'comprimés')
      .replaceAll('comprim?(s)', 'comprimé(s)')
      .replaceAll('g?lule', 'gélule')
      .replaceAll('g?lules', 'gélules')
      .replaceAll('g?lule(s)', 'gélule(s)')
      .replaceAll('pellicul?', 'pelliculé')
      .replaceAll('pellicul?s', 'pelliculés')
      .replaceAll('pelicul?', 'pelliculé')
      .replaceAll('s?curit?', 'sécurité')
      .replaceAll('s?curit', 'sécurit')
      .replaceAll('lib?ration', 'libération')
      .replaceAll('prolong?e', 'prolongée')
      .replaceAll('prolong?s', 'prolongés')
      .replaceAll('limit?e', 'limitée')
      .replaceAll('limit?s', 'limités')
      .replaceAll('n?buliseur', 'nébuliseur')
      .replaceAll('n?buliseurs', 'nébuliseurs')
      .replaceAll('port?e', 'portée')
      .replaceAll(' solution ? diluer', ' solution à diluer')
      .replaceAll(RegExp(r'\s\?\s'), ' à ')
      // Typo BDPM (CIS_CPD_bdpm.txt) : stuéiants → stupéfiants
      .replaceAll('stuéiants', 'stupéfiants')
      .replaceAll('stuéiant', 'stupéfiant')
      // Placeholders type export CSV/Excel dans statuts (plus d'infos)
      .replaceAll(r'$1é$2uri$1ée', 'sécurisée')
      .replaceAll('éuriée', 'sécurisée')
      .replaceAll('éuriee', 'sécurisée')
      .replaceAll(RegExp(r'\$\d+'), '')
      // Guillemets / apostrophes parasites dans statuts (ex. s'écurisée, s«écurisée → sécurisée)
      .replaceAll("s'écurisée", 'sécurisée')
      .replaceAll("s'écurisé", 'sécurisé')
      .replaceAll('s«écurisée', 'sécurisée')
      .replaceAll('s»écurisée', 'sécurisée')
      .replaceAll('s"écurisée', 'sécurisée')
      // Regex générique retirée (problèmes d’encodage sur Windows) ; les replaceAll littéraux ci‑dessus suffisent.
      .replaceAll(RegExp(r"\w'écurisée"), 'sécurisée')
      .replaceAll(RegExp(r"\w'écurisé"), 'sécurisé')
      // ? = é ou è dans mots courants (statuts, ordonnance, etc.)
      .replaceAll(RegExp(r'(\w)\?e\b'), r'$1ée')
      .replaceAll(RegExp(r'(\w)\?s\b'), r'$1és')
      .replaceAll(RegExp(r'(\w)\?(s)\b'), r'$1é$2')
      .replaceAll(RegExp(r'(\w)\?(\w)'), r'$1é$2')
      // UTF-8 mal décodé
      .replaceAll('Ã©', 'é')
      .replaceAll('Ã¨', 'è')
      .replaceAll('Ãª', 'ê')
      .replaceAll('Ã«', 'ë')
      .replaceAll('Ã ', 'à')
      .replaceAll('Ã¢', 'â')
      .replaceAll('Ã®', 'î')
      .replaceAll('Ã¯', 'ï')
      .replaceAll('Ã´', 'ô')
      .replaceAll('Ã¹', 'ù')
      .replaceAll('Ã»', 'û')
      .replaceAll('Ã§', 'ç')
      .replaceAll('Ã‰', 'É')
      .replaceAll('Ãˆ', 'È')
      .replaceAll('Å“', 'œ')
      .replaceAll('Å’', 'Œ')

      // caractères invalides résiduels
      .replaceAll('\uFFFD', '')

      // Apostrophes élision françaises manquantes : uniquement en début de mot (évite sant'é, modalit'és, etc.)
      .replaceAll('LORDRE', "L'ORDRE")
      .replaceAll('LOrdre', "L'Ordre")
      .replaceAll('lOrdre', "l'Ordre")
      .replaceAllMapped(RegExp(r"(^|\s)([ldncjsmt])([A-ZÀ-Ÿ])"), (m) => "${m[1]}${m[2]}'${m[3]}")

      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

/// Nettoyage des libellés affichés en ligne 1 : moins d’apostrophes, pas de doublons de phrases, coquilles.
String cleanLabelLine1(String input) {
  if (input.isEmpty) return input;
  String s = normalizeText(input);
  // Réduire les apostrophes sur les mots courants (S'ÉCABLE → SÉCABLE)
  s = s.replaceAll("S'ÉCABLE", 'SÉCABLE').replaceAll("S'ÉCABLES", 'SÉCABLES');
  s = s.replaceAll("s'écable", 'sécable').replaceAll("s'écables", 'sécables');
  // Typo BDPM courante
  s = s.replaceAll('GÉLULESS', 'GÉLULES').replaceAll('géluless', 'gélules');
  // Supprimer les phrases consécutives dupliquées (ex. "COMPRIMÉ SÉCABLE COMPRIMÉ SÉCABLE" → "COMPRIMÉ SÉCABLE")
  final words = s.split(RegExp(r'\s+'));
  bool changed = true;
  while (changed && words.length > 1) {
    changed = false;
    for (int len = 1; len <= words.length ~/ 2; len++) {
      for (int i = 0; i <= words.length - 2 * len; i++) {
        bool match = true;
        for (int k = 0; k < len; k++) {
          if (words[i + k] != words[i + len + k]) {
            match = false;
            break;
          }
        }
        if (match) {
          for (int k = 0; k < len; k++) {
            words.removeAt(i + len);
          }
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
  }
  s = words.join(' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return s;
}

/// Normalise l'adresse avant injection : accents → ASCII, espaces entre blocs.
String normalizeAddressForStorage(String input) {
  if (input.isEmpty) return input;

  var s = normalizeText(input);

  // Accents → ASCII
  s = s
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('œ', 'oe')
      .replaceAll('Œ', 'Oe');

  // Espaces entre blocs (virgule, point-virgule)
  s = s
      .replaceAll(RegExp(r','), ', ')
      .replaceAll(RegExp(r';'), ' ; ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return s;
}
