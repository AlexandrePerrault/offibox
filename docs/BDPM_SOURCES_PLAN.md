# Plan : sources BDPM officielles, libellés, remboursement, NSFP

## 1. Sources officielles BDPM

- **CIS_bdpm.txt** : spécialités (une ligne par CIS). Colonnes à vérifier dans le PDF officiel « Contenu et format des fichiers téléchargeables dans la BDM » (souvent : CIS, dénomination, forme pharmaceutique, etc.).
- **CIS_CIP_bdpm.txt** : présentations (une ligne par CIP13). Souvent : CIS, CIP13, libellé de présentation, statut, etc.
- **CIS_CIP_Dispo_Spec.txt** : disponibilités (rupture, tension, remise, **arrêt de commercialisation**).

URLs :
- https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt
- https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt
- https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt

Fichiers sans en-tête, séparateur tabulation.

## 2. Reconstruction des libellés (nom, dosage, forme, quantité)

Objectif : libellé du type **« Doliprane 1000 mg boîte de 8 comprimés »**.

- **Nom** : dénomination de la spécialité (CIS_bdpm) ou dérivé du libellé de présentation (CIS_CIP_bdpm).
- **Dosage** : extrait du libellé de présentation (ex. 1000 mg, 10 mg).
- **Forme galénique** : comprimé, gélule, etc. (souvent dans CIS_bdpm ou CIS_CIP_bdpm).
- **Quantité** : « boîte de X comprimés » (souvent dans le libellé de présentation ou une colonne dédiée).

À faire après vérification des colonnes réelles :
1. Parser CIS_bdpm et CIS_CIP_bdpm (format tabulation).
2. Joindre par CIS pour avoir, par CIP13, nom + forme ; par CIP13 dans CIS_CIP : dosage + quantité.
3. Construire la chaîne `"$nom $dosage $forme $quantité"` et l’utiliser comme `label` / `labelRaw` à la place de BDM_MASTER si on bascule.

**Gain potentiel** : une seule source officielle, pas de dépendance à BDM_MASTER2026.csv ; chargement possible plus léger et plus rapide si on ne charge que les colonnes utiles.

## 3. Vérification quotidienne et exemples avant injection

- **Quotidien** : tâche planifiée (script ou job) qui télécharge CIS_bdpm.txt et CIS_CIP_bdpm.txt (et éventuellement CIS_CIP_Dispo_Spec.txt).
- **Avant injection** : le script ou l’appli génère des **exemples de libellés** (liste de 10–20 médicaments avec le libellé reconstruit) et les affiche (log, fichier, ou écran dédié) pour validation avant de remplacer BDM_MASTER dans l’appli.

À implémenter :  
- un script (ex. `scripts/check_bdpm_sources.dart` ou `.py`) qui télécharge, parse, affiche les exemples ;  
- optionnellement un mode « prévisualisation » dans l’appli qui charge les fichiers BDPM et affiche les exemples sans remplacer encore le flux actuel.

## 4. Taux de remboursement dans « plus d’infos »

- **Objectif** : afficher le taux de remboursement dans la modale « plus d’infos » (badge ligne 1 → contenu de la fenêtre).
- **Source** : à définir (fichier BDPM, LPP, ou autre). Les fichiers BDPM peuvent contenir une info de taux ou de statut de remboursement selon la version.
- **Implémentation** :  
  - Ajouter un champ optionnel (ex. `tauxRemboursement` ou ligne dédiée dans le contenu « plus d’infos »).  
  - Dans la modale « plus d’infos », afficher une ligne du type « Taux de remboursement : X % » quand la donnée est disponible.

## 5. NSFP et exception « arrêt de commercialisation »

Règle :
- Par défaut : **ne pas afficher** les médicaments « non commercialisé » (NSFP).
- **Exception** : si le CIS du médicament est présent dans **CIS_CIP_Dispo_Spec.txt** avec la mention **« arrêt de commercialisation »**, alors :
  - **afficher** le médicament ;
  - afficher un **badge « arrêt de commercialisation »** en ligne 2 ou 3 (selon la place).

Implémentation :
- Charger CIS_CIP_Dispo_Spec (officiel ou fallback GitHub) et construire l’ensemble des CIS dont une ligne contient « arrêt de commercialisation » → `Set<String> cisArretCommercialisation`.
- Filtre (ex. `SearchFilter.applyTo`) : quand `hideNsfp` est true, exclure les résultats NSFP **sauf** si `cis` est dans `cisArretCommercialisation`.
- Pour les résultats BDM NSFP dont le CIS est dans ce set : afficher le badge « arrêt de commercialisation » (ligne 2 ou 3).

## 6. Ordre de mise en œuvre proposé

1. **NSFP + Dispo_Spec** : loader `cisArretCommercialisation`, exception dans le filtre, badge « arrêt de commercialisation » (fait en code).
2. **Taux de remboursement** : ajout de l’affichage dans « plus d’infos » (structure + UI), source à brancher dès qu’elle est définie.
3. **Libellés BDPM** : après obtention du format exact des fichiers (PDF ou échantillon), parser CIS_bdpm + CIS_CIP_bdpm, construire les libellés, script d’exemples, puis option de bascule depuis BDM_MASTER.
4. **Quotidien** : exécuter `dart run scripts/check_bdpm_sources.dart` (cron ou Task Scheduler) pour vérifier les fichiers et afficher des exemples avant injection.
