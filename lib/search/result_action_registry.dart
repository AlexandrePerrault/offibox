import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/utils/open_url.dart';

import 'result_action.dart';

bool _isSignedInWithGoogle() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  return user.providerData.any((p) => p.providerId == 'google.com');
}

// ============================================================================
// ⭐ ACTION PRINCIPALE
// ============================================================================
ResultAction? getPrimaryAction(SearchResult item) {
  for (final action in line3Actions) {
    if (action.isPrimary && action.isVisible(item)) {
      return action;
    }
  }
  return null;
}

// ============================================================================
// 🧩 ACTIONS — LIGNE 3
// ============================================================================
final List<ResultAction> line3Actions = [

  // =========================
  // 🏥 ORGANISMES — SITE WEB / URL (AMO + AMC, ligne 3)
  // 👉 AMO : colonne G du CSV mutuelles ; AMC : colonne N
  // 👉 clic = ouverture url
  // =========================
  ResultAction(
    label: 'Site web',
    icon: Icons.language,
    tooltip: 'Ouvrir le site web',
    isVisible: (item) =>
        (item.source == SourceType.amo || item.source == SourceType.amc) &&
        item.url != null &&
        item.url!.isNotEmpty,
    onTap: (item) => () {
      openUrl(item.url!);
    },
  ),

  // =========================
  // 🏥 AMC — MAIL (Gmail si connecté Google, sinon mailto)
  // =========================
  ResultAction(
    label: 'Mail',
    icon: Icons.mail_outline,
    tooltip: 'Envoyer un mail',
    isVisible: (item) =>
        item.source == SourceType.amc &&
        item.email != null &&
        item.email!.isNotEmpty,
    onTap: (item) => () {
      final email = item.email!;
      final url = _isSignedInWithGoogle()
          ? 'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(email)}'
          : 'mailto:$email';
      openUrl(url);
    },
  ),

  // =========================
  // 🟪 CRPV — MAIL (ligne 3, avec copier comme mutuelles)
  // =========================
  ResultAction(
    label: 'Mail',
    icon: Icons.mail_outline,
    tooltip: 'Envoyer un mail',
    isVisible: (item) =>
        (item.source == SourceType.pharmacovigilance ||
            item.source == SourceType.centresAntiPoison ||
            item.source == SourceType.chu) &&
        item.email != null &&
        item.email!.isNotEmpty,
    onTap: (item) => () {
      final email = item.email!;
      final url = _isSignedInWithGoogle()
          ? 'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(email)}'
          : 'mailto:$email';
      openUrl(url);
    },
  ),

  // =========================
  // 🟪 CRPV — + d'infos (ligne 3) → liste des CRPV sur le site ANSM
  // =========================
  ResultAction(
    label: "+ d'infos",
    icon: Icons.info_outline,
    tooltip: 'Liste des centres régionaux de pharmacovigilance (ANSM)',
    isVisible: (item) => item.source == SourceType.pharmacovigilance,
    onTap: (_) => () {
      openUrl(
        'https://ansm.sante.fr/page/liste-des-centres-regionaux-de-pharmacovigilance',
      );
    },
  ),

  // =========================
  // 🟪 CRPV — Signaler un effet indésirable (ligne 3)
  // =========================
  ResultAction(
    label: 'Signaler un effet indésirable',
    icon: Icons.warning_amber_outlined,
    tooltip: 'Portail de signalement des événements sanitaires indésirables',
    isVisible: (item) => item.source == SourceType.pharmacovigilance,
    onTap: (_) => () {
      openUrl(
        'https://signalement.social-sante.gouv.fr/espace-declaration/guidage?profil=PROFESSIONNEL_SANTE',
      );
    },
  ),

  // =========================
  // 🏥 CHU — Ouvrir la fiche (l'annuaire service-public)
  // =========================
  ResultAction(
    label: 'Ouvrir la fiche',
    icon: Icons.open_in_new,
    tooltip: 'Voir la fiche sur l\'annuaire du service public',
    isVisible: (item) =>
        item.source == SourceType.chu &&
        item.url != null &&
        item.url!.trim().isNotEmpty,
    onTap: (item) => () => openUrl(item!.url!),
  ),

  // =========================
  // 🏥 AMC — RESOPHARMA
  // =========================
  ResultAction(
    label: 'Resopharma',
    icon: Icons.account_tree_outlined,
    tooltip: 'Organismes conventionnés Resopharma',
    isVisible: (item) => item.source == SourceType.amc,
    onTap: (_) => () {
      openUrl(
        'https://www.resopharma.fr/organismesconventionnes.php',
      );
    },
  ),

  // =========================
  // 🏥 AMC — CONVENTIONNEMENT
  // =========================
  ResultAction(
    label: 'Conventionnement',
    icon: Icons.assignment_outlined,
    tooltip: 'Télécharger le document de conventionnement',
    isVisible: (item) => item.source == SourceType.amc,
    onTap: (_) => () {
      openUrl(
        'https://raw.githubusercontent.com/AlexandrePerrault/offiboxdata/main/tiers%20payant%20(3).docx',
      );
    },
  ),

  // =========================
  // 💊 RCP (BDM)
  // =========================
  ResultAction(
    label: 'RCP',
    icon: Icons.description_outlined,
    tooltip: 'Accéder au RCP',
    isPrimary: true,
    isVisible: (item) =>
        item.source == SourceType.bdm &&
        item.url != null &&
        item.url!.isNotEmpty,
    onTap: (item) => () {
      openUrl(item.url!);
    },
  ),

  // =========================
  // 🐶 RCP VÉTO (au-dessus de la ligne Sources en barre injectée)
  // =========================
  ResultAction(
    label: 'RCP VÉTO',
    icon: Icons.description_outlined,
    tooltip: 'Accéder au RCP vétérinaire',
    isVisible: (item) {
      final isVeto =
          item.source == SourceType.veto ||
          item.label.toUpperCase().contains('VETO') ||
          item.label.contains('🐾');
      final hasUrl = (item.url != null && item.url!.trim().isNotEmpty) ||
          (item.rcpVetoUrl != null && item.rcpVetoUrl!.trim().isNotEmpty);
      return isVeto && hasUrl;
    },
    onTap: (item) => () {
      final url = item.rcpVetoUrl?.trim().isNotEmpty == true
          ? item.rcpVetoUrl!
          : item.url;
      if (url != null && url.trim().isNotEmpty) openUrl(url.trim());
    },
  ),

  // 📘 LPP : pas d’action ligne 3 — uniquement le badge "+ d'infos" en ligne 2 (tooltip "accès nomenclature LPP")

  // =========================
  // ⚠️ MEDDISPAR (BDM)
  // =========================
  ResultAction(
    label: 'Fiche MEDDISPAR',
    icon: Icons.warning_amber_rounded,
    tooltip: 'Ouvrir Meddispar',
    isVisible: (item) =>
        item.source == SourceType.bdm &&
        item.meddisparUrl != null &&
        item.meddisparUrl!.isNotEmpty,
    onTap: (item) => () {
      openUrl(item.meddisparUrl!);
    },
  ),

  // =========================
  // 🩹 DISPOSITIF MÉDICAL — pas de pill "Fiche produit" : icône external link à côté du logo Source (voir result_line_3_actions).
  // =========================
];
