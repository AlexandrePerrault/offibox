

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

/// Codes actes pharmacie (col 1 = Code Acte, col 2 = Libellé, col 3 = Tarif ; séparateur ;).
const String CODES_ACTES_PHARMACIE_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/codes_actes_pharmacie.csv';

/// Vidéos thérapeutiques (feuille videos) : col B = CIP13, col C = URL. Affichage pill "video" en ligne 2 BDM.
const String VIDEOS_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/videos.csv';

const String LABORATOIRES_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/LABORATOIRES.csv';

/// CERP (Madouest, etc.) — désormais dans le dossier CERP
const String CERP_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CERP/CERP.csv';

/// Co&Pharm 2026 (réservé CERP) : col1=CIP(7/13), col2=Libellé, col3=URL PDF, col4=URL logo
const String COETPHARM_2026_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/CERP/CO%26PHARM%202026.csv';


const String STUPEFIANTS_HOP_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/stup%C3%A9fiants%2Bhopital%202026.csv';

/// Médicaments d’exception — source pour le badge EXCEPTION en ligne 1.
/// CSV : col 0 = CIP13, col 1 = libellé. Toutes les lignes = exception.
const String MEDICAMENTS_EXCEPTION_URL =
  "https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/medicaments%20d'exception.csv";

/// OTC/autre — optionnel. CSV : CIP13 (col 0) ; Type (col 1) = "otc". Si absent, badge OTC = BDM uniquement.
const String EXCEPTION_OTC_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/exception_otc_2026.csv';

/// Liste des médicaments de médication officinale (OTC/Libre accès).
/// Source officielle : https://ansm.sante.fr/uploads/2025/12/22/20251222-liste-medication-officinale-listecomplete-decembre-2025.xls (CIP13 en col D).
/// Ce CSV doit contenir les CIP13 (un par ligne ou col 0) exportés depuis la colonne D du XLS.
const String LISTE_MEDICATION_OFFICINALE_CIP13_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/liste_medication_officinale_cip13.csv';

const String AMC_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/mutuelles_2026.csv';

/// Centres régionaux de pharmacovigilance (CRPV) — annuaire.
/// CSV : nom, adresse_complete, tel, fax, mail (séparateur virgule, champs entre guillemets).
const String PHARMACOVIGILANCE_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/pharmacovigilance.csv';

/// Centres anti poison — annuaire (ville, téléphone, mail, adresse).
const String CENTRES_ANTI_POISON_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/centres_anti_poison.csv';

/// CHU — annuaire (nom, adresse, téléphone, email, url).
const String CHU_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/chu.csv';

/// Centres CEIP-A (addictovigilance) — annuaire. CSV : nom, adresse_complete, tel, fax, mail.
const String CEIP_ADDICTOVIGILANCE_URL =
  'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/ceip_addictovigilance.csv';

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

// ============================================================================
// Fichiers officiels BDPM (alignés medicaments-api)
// https://github.com/Giygas/medicaments-api — downloader.go + tsvConverter.go
// 5 fichiers TSV (tab), pas d'en-tête, UTF-8 ou ISO-8859-1 selon le fichier.
// Pipeline : 1) Télécharger les 5 fichiers  2) Parser TSV  3) Indexer par CIS
//            4) Construire médicaments (spécialité + présentations + compositions + génériques + conditions)
// Colonnes (indices 0-based) :
//   CIS_bdpm     : 0=CIS, 1=Dénomination, 2=Forme pharmaceutique, 3=Voies admin, 4=Statut AMM, 5=Type proc, 6=État comm, 7=Date AMM, 10=Titulaire, 11=Surveillance
//   CIS_CIP_bdpm : 0=CIS, 1=CIP7, 2=Libellé présentation, 3=Statut, 4=État comm, 5=Date décl, 6=CIP13, 7=Agrément, 8=Taux remboursement, 9=Prix
//   CIS_COMPO    : 0=CIS, 1=Désignation élément, 2=Code substance, 3=Dénomination substance, 4=Dosage, 5=Référence dosage, 6=Nature composant
//   CIS_GENER    : 0=Id groupe, 1=Libellé, 2=CIS, 3=Type (0=Princeps, 1=Générique, 2=Complém. poso, 3=Substituable)
//   CIS_CPD      : 0=CIS, 1=Condition (prescription / dispensation)
// ============================================================================

const String CIS_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt';
const String CIS_CIP_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt';
const String CIS_COMPO_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt';
const String CIS_GENER_BDPM_TXT_URL =
  'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt';
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

/// URL d’un PDF utilisé **uniquement** pour la démo de la page de connexion (animation bandeau + panneau).
/// Exemple pris parmi les fiches VOC (OMÉDIT) ; ne pas généraliser : les vraies fiches viennent de [FICHES_VOC_CSV_URL] et [loadFichesVoc].
const String DEMO_VOC_PDF_URL =
    'https://www.omedit-fiches-cancer.fr/media-files/37293/imbruvica-ibrutinib-comprime-et-gelule-v6-pro.pdf';

/// Actualités (popup barre) : col 1 = date, col 2 = Affichage, col 3 = URL, col 4 = CIP 13.
const String NEWS_CSV_URL =
    'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/news.csv';

/// Spécialités ANSM (fic03spe) : col 1 = code_spe, col 2 = CIP8, col 3 = G|R (Générique|Princeps). Permet d’afficher le badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
const String FIC03SPE_TXT_URL =
    'https://ansm.sante.fr/uploads/2026/01/20/fic03spe.txt';
