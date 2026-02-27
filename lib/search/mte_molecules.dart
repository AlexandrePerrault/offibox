import 'package:offibox/models/search_result.dart';
import 'package:offibox/utils/normalize.dart';

/// Molécules à marge thérapeutique étroite (non substituables) — liste CNOP.
/// Voir : https://www.ordre.pharmacien.fr/les-communications/focus-sur/les-actualites/la-liste-des-medicaments-a-marge-therapeutique-etroite-non-substituables-est-etendue
/// On matche sur le label normalisé : substance (génériques) ou nom de princeps (ex. Lamictal = lamotrigine).
const List<String> _mteMoleculesNormalized = [
  'lacosamide',
  'oxcarbazepine',
  'lamotrigine',
  'pregabaline',
  'zonisamide',
  'levetiracetam',
  'topiramate',
  'valproate',   // valproate de sodium
  'levothyroxine',
  'mycophenolate', // mofétil + sodique
  'buprenorphine',
  'azathioprine',
  'ciclosporine',
  'everolimus',
];

/// Noms de princeps MTE (normalisés, sans accent) pour afficher le badge sur les spécialités (ex. Lamictal → lamotrigine).
const List<String> _mtePrincepsNormalized = [
  'lamictal',    // lamotrigine
  'vimpat',      // lacosamide
  'trileptal',   // oxcarbazépine
  'lyrica',      // prégabaline
  'keppra',      // lévétiracétam
  'epitomax',    // topiramate
  'depakine',    // valproate de sodium
  'levothyrox',  // lévothyroxine
  'euthyral',
  'cellcept',    // mycophénolate mofétil
  'subutex',     // buprénorphine
  'imurel',      // azathioprine
  'neoral',      // ciclosporine
  'sandimmun',
  'afinitor',    // évérolimus
  'myfortic',    // mycophénolate sodique
  'zonegran',    // zonisamide
];

/// Retourne true si le résultat correspond à une molécule MTE : soit le label contient une substance MTE (génériques), soit un nom de princeps MTE (ex. Lamictal, Vimpat, Trileptal).
bool isMteMolecule(SearchResult item) {
  final norm = normalizeLoose(item.label);
  for (final molecule in _mteMoleculesNormalized) {
    if (norm.contains(molecule)) return true;
  }
  for (final princeps in _mtePrincepsNormalized) {
    if (norm.contains(princeps)) return true;
  }
  return false;
}
