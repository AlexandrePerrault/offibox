# Liste médication officinale (OTC / Libre accès)

Fichier utilisé par Offibox pour afficher le badge **« OTC/Libre accès »** (commonspan) en ligne 1 des résultats BDM.  
Les CIP13 proviennent de la **liste des médicaments de médication officinale** publiée par l’ANSM (médicaments en accès direct).

- **Référence ANSM :** [Médicaments en accès direct (MMO)](https://ansm.sante.fr/documents/reference/medicaments-en-acces-direct)
- **Fichier source :** XLS mis à jour mensuellement (lien sur la page ci-dessus), ex.  
  `https://ansm.sante.fr/uploads/2025/12/22/20251222-liste-medication-officinale-listecomplete-decembre-2025.xls`
- **Emplacement dans offiboxdata :** à la **racine** du dépôt  
  → `https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/liste_medication_officinale_cip13.csv`

## Génération du CSV

À partir du XLS ANSM (colonne **D** = code CIP 13 chiffres) :

```bash
cd scripts
pip install requests xlrd
python build_liste_medication_officinale_cip13.py
```

Options :

- `--xls URL_ou_chemin` : URL du XLS ou fichier .xls local (par défaut : URL décembre 2025).
- `--out fichier.csv` : nom du fichier de sortie (défaut : `liste_medication_officinale_cip13.csv`).

Le script écrit un CSV avec **un CIP13 par ligne** (sans en-tête), conforme au chargement dans l’app.

## Mise à jour mensuelle

1. Aller sur [Médicaments en accès direct](https://ansm.sante.fr/documents/reference/medicaments-en-acces-direct) et récupérer le lien du dernier XLS (liste complète).
2. Lancer le script avec cette URL (ou télécharger le XLS et passer le chemin) :
   ```bash
   python build_liste_medication_officinale_cip13.py --xls "https://ansm.sante.fr/uploads/AAAA/MM/JJ/fichier-listecomplete-....xls"
   ```
3. Copier le fichier généré à la **racine** du dépôt **offiboxdata** sous le nom exact :  
   `liste_medication_officinale_cip13.csv`
4. Commit + push sur `main` (ou la branche utilisée par l’app).

Si l’ANSM change la structure du XLS (ex. CIP13 dans une autre colonne), adapter dans le script la constante `CIP13_COLUMN_INDEX` (colonne D = index 3).

## Vérifier le déploiement et le nombre de médicaments

- **Présence du fichier :**  
  Ouvrir  
  [liste_medication_officinale_cip13.csv (raw)](https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/liste_medication_officinale_cip13.csv)  
  → si la page s’affiche (CSV avec des lignes de 13 chiffres), le fichier est bien déployé.

- **Nombre de médicaments portant le badge :**  
  Au démarrage, l’app affiche dans les logs une ligne du type :  
  `[Offibox] Exception: X CIP13, OTC/Libre accès: Y CIP13 (liste médication officinale)`  
  → **Y** = nombre de CIP13 chargés depuis ce CSV = nombre de médicaments pouvant afficher le badge OTC/Libre accès.

  Vous pouvez aussi compter les lignes du CSV dans offiboxdata (une ligne = un CIP13) pour vérifier la cohérence.
