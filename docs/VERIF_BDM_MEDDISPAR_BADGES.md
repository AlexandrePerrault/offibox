# Vérification cohérence BDM / Meddispar et badge OTC/autre (NR)

## 1. Sources officielles

- **BDM (Base de données sur le médicament)**  
  - Site : https://base-donnees-publique.medicaments.gouv.fr/  
  - Fichiers téléchargeables (format détaillé dans le PDF « Contenu et format des fichiers ») : CIS_bdpm.txt, CIS_CIP_bdpm.txt, CIS_CIP_Dispo_Spec.txt  
- **Meddispar**  
  - Site : https://www.meddispar.fr/  
  - Utilisé pour statuts (exception, PIH, surveillance particulière, stupéfiants, OTC, etc.) et fiches par spécialité.

Dans Offibox, les données BDM viennent du CSV **BDM_MASTER2026** (dépôt offiboxdata) avec colonnes : Dénomination, CIP7, CIP13, CIS, Date, URL BDPM, **Libre-accès** (col 6), NSFP, URL EXTERNES, **URL MEDDISPAR** (col 9), Biosimilaire, etc.

## 2. Produits à vérifier (exemples)

| Produit | À contrôler BDM | À contrôler Meddispar |
|--------|-----------------|------------------------|
| **HULIO 40 mg** – solution injectable SC ; boîte de 2 stylos préremplis de 0,8 ml | Présentation, CIP13, CIS, Libre-accès, taux, NSFP | Fiche si disponible, statut (exception, biosimilaire, etc.) |
| **Ozemic 0,5 mg** | Idem | Idem |
| **Codoliprane 400** | Idem | Idem |
| **Fluimucil 200** – boîte de 30 | Idem | Idem |

**Comment vérifier :**

1. **BDM** : Rechercher le médicament sur https://base-donnees-publique.medicaments.gouv.fr/ (ou dans les fichiers .txt officiels), noter CIP13, CIS, libellé, « Libre-accès », taux de remboursement (colonne I dans CIS_CIP_bdpm si vous utilisez les .txt).
2. **Meddispar** : Rechercher sur https://www.meddispar.fr/ la fiche correspondante et le statut (liste, exception, PIH, OTC, etc.).
3. **Offibox** : Rechercher le même produit dans l’appli et comparer : libellé, badge OTC/autre (ou NR), lien Meddispar (pill MEDDISPAR), taux en « + d’infos ».

## 3. Badge « common span » OTC/autre (NR) — en place

- **Définition** : badge en ligne 1 pour les médicaments BDM **libre accès / OTC / autre / NR**.
- **Fichier** : `lib/ui/spans/common_spans.dart`
  - `otcSquareSpan()` : label **`OTC/autre`**, tooltip **`OTC / autre / NR`**, couleur vert (lightGreenAccent.shade700), lien ANSM.
- **Affichage** : `lib/ui/results/result_line_1.dart`
  - Pour **BDM** : le badge est ajouté quand `item.isOtc == true` (lignes 355–377 et 1060–1092).
- **Source de `isOtc`** : `lib/data/bdm_parser.dart`
  - Colonne 6 **Libre-accès** = `oui` **ou** libellé contient `(OTC)` → `isOtc = true`.

Donc le **badge OTC/autre (common span) est bien en place** pour tous les médicaments BDM dont la colonne Libre-accès = oui ou le libellé contient (OTC).

**Note** : Les produits **non remboursés** (NR) sans taux et non hospitaliers sont décrits dans les commentaires du code comme devant afficher un badge « non remboursé ». Actuellement, ce cas est couvert par le même badge **OTC/autre** lorsque le produit est aussi en **Libre-accès** dans le CSV. Si un produit est NR mais sans « Libre-accès » ni (OTC), on peut compléter la logique pour afficher quand même le badge OTC/autre lorsque : BDM **et** pas de taux **et** CIP13 non dans la liste des CIP hospitaliers (voir § 4).

## 4. Option : afficher le badge NR pour « sans taux + non hospitalier »

Pour aligner complètement avec les commentaires existants (« badge non remboursé si BDM hors liste hospitalière et sans taux »), on peut afficher le même badge **OTC/autre** en ligne 1 BDM lorsque :

- `item.source == SourceType.bdm`
- et `tauxRemboursement` est null ou vide
- et `hospitalCip13Set` ne contient pas le `cip13` du produit

Cela se ferait dans `result_line_1.dart` en ajoutant une condition du type : afficher `otcSquareSpan()` si `isOtc == true` **ou** (pas de taux et cip13 pas dans hospitalCip13Set).

## 5. Résumé

- **Cohérence BDM / Meddispar** : à vérifier manuellement pour chaque produit (HULIO 40 mg, Ozemic 0,5 mg, Codoliprane 400, Fluimucil 200 boîte de 30) via les sites officiels et le CSV BDM_MASTER2026 / colonne URL MEDDISPAR.
- **Badge common span NR/autre** : **en place** dans `common_spans.dart` (`otcSquareSpan`, label « OTC/autre », tooltip « OTC / autre / NR »), affiché en ligne 1 BDM lorsque `isOtc == true` (Libre-accès = oui ou (OTC) dans le libellé).
