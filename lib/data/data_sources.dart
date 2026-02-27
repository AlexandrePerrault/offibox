

// ============================================================================
// 🌍 SOURCES DE DONNÉES (CSV GitHub)
// ============================================================================

const String BDM_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_MASTER2026.csv';

const String PANSEMENTS_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/PANSEMENTS+DM2026.csv';

const String VETO_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/FICHIER%20MED%20VETERINAIRES2026.csv';

/// Codes LPP (source : codes LPP +++ - codes LPP) : Code LPP (col A), URL (col B), Libellé (col C) ; séparateur ;
const String LPP_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/codes%20LPP%20%2B%2B%2B%20-%20codes%20LPP.csv';

/// Outils métier (mots-clés) — même format que keywords : keyword tapé, mot affiché, icône, url, badges.
const String OUTILS_METIER_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/outils_metier.csv';

/// Sites web (mots-clés) — même format.
const String SITES_WEB_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/sites_web.csv';

/// Vidéos thérapeutiques (feuille videos) : col B = CIP13, col C = URL. Affichage pill "video" en ligne 2 BDM.
const String VIDEOS_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/videos.csv';

const String LABORATOIRES_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/LABORATOIRES.csv';

const String CERP_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CERP.csv';


const String STUPEFIANTS_HOP_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/stup%C3%A9fiants%2Bhopital%202026.csv';

/// Médicaments d’exception — source pour le badge EXCEPTION en ligne 1.
/// CSV : col 0 = CIP13, col 1 = libellé. Toutes les lignes = exception.
const String MEDICAMENTS_EXCEPTION_URL =
  "https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/medicaments%20d'exception.csv";

/// OTC/autre — optionnel. CSV : CIP13 (col 0) ; Type (col 1) = "otc". Si absent, badge OTC = BDM uniquement.
const String EXCEPTION_OTC_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/exception_otc_2026.csv';

const String AMC_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/mutuelles_2026.csv';

/// Centres régionaux de pharmacovigilance (CRPV) — annuaire.
/// CSV : nom, adresse_complete, tel, fax, mail (séparateur virgule, champs entre guillemets).
const String PHARMACOVIGILANCE_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/pharmacovigilance.csv';

const String CIP_HOSPITALIERS_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CIP%20hospitaliers.csv';

/// BDM CIP → quantité par boîte ; source officielle du libellé affiché en ligne 1 pour les médicaments.
/// Colonnes utilisées : A = CIP13, C = dosage, E = libellé (affiché en résultat).
/// https://github.com/AlexandrePerrault/offiboxdata/blob/main/BDM_CIP_QUANTITE.csv
const String BDM_CIP_QUANTITE_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/BDM_CIP_QUANTITE.csv';

/// URL de la source affichée pour les médicaments (BDM) — page GitHub lisible
const String BDM_SOURCE_DISPLAY_URL =
  'https://github.com/AlexandrePerrault/offiboxdata/blob/main/BDM_CIP_QUANTITE.csv';

/// Composition BDM : CIS ; COMPOSITION (molécule / DCI) — pour recherche molécule → princeps
const String COMPOSITION_BDM_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/composition-bdm.csv';

/// Statut CIS 2026 : CIS ; STATUT (col B = libellé statut, un CIS peut avoir plusieurs lignes)
const String STATUT_CIS_2026_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/statut%20CIS%202026.csv';

/// Taux de remboursement par CIS (optionnel). CSV : CIS ; taux (ex. "65" ou "65 %"). Vide = désactivé.
const String TAUX_REMBOURSEMENT_CIS_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/taux_remboursement_cis.csv';

/// ANSM disponibilités : CIS (col A), CIP, type, libellé, dates, URL — seuls les CIS de ce fichier affichent un statut ANSM
const String CIS_CIP_DISPO_SPEC_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CIS_CIP_Dispo_Spec.csv';

/// Fichier officiel BDPM : ruptures, tension, remises à disposition. On ne garde que les lignes dont la date MAJ (col F) est < 2 mois.
const String CIS_CIP_DISPO_SPEC_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt';

/// Fichiers officiels BDPM pour reconstruction des libellés (nom, dosage, forme, quantité). Vérification quotidienne + exemples avant injection.
const String CIS_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt';
const String CIS_CIP_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt';

/// Composition par CIS (CIS_COMPO_bdpm.txt) : col D, E, F pour affichage « composition : D : E pour F » dans + d'infos.
const String CIS_COMPO_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt';

/// Conditions de prescription et de dispensation par CIS (CIS_CPD_bdpm.txt) — source officielle des libellés de statut affichés dans « Plus d'infos ».
const String CIS_CPD_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CPD_bdpm.txt';

/// Statuts ANSM (fallback) : fichiers-medicaments/statutsANSM.csv
/// Colonnes : CIS (A), (B), type (C), libellé (D), (E), date MAJ (F), date remise (G), URL (H).
const String STATUTS_ANSM_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/fichiers-medicaments/statutsANSM.csv';

/// Rappels ANSM : CSV avec colonne A = nom du produit (ex. export Excel/CSV depuis https://ansm.sante.fr/informations-de-securite, col A = produit).
/// Mettre l’URL du fichier (ex. raw GitHub) ou laisser vide pour désactiver l’alerte « produit concerné par un rappel de lot N° ».
const String ANSM_RAPPELS_CSV_URL = '';

/// Fiches VOC (voie orale cancer) OMÉDIT : col A = médicament, col B = URL fiche patient, col C = URL fiche pro.
const String FICHES_VOC_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/fiches_voc.csv';

/// Spécialités ANSM (fic03spe) : col 1 = code_spe, col 2 = CIP8, col 3 = G|R (Générique|Princeps). Permet d’afficher le badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
const String FIC03SPE_TXT_URL =
    'https://ansm.sante.fr/uploads/2026/01/20/fic03spe.txt';
