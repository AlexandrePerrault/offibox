import 'package:flutter/material.dart';

import 'package:offibox/data/codes_actes_image_assets.dart';
import 'package:offibox/data/cis_dispo_loader.dart';
import 'package:offibox/data/generiques.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/ui/results/result_line_1.dart';
import 'package:offibox/ui/results/result_tile.dart';
import 'package:offibox/ui/results/result_line_3_actions.dart';
import 'package:offibox/ui/results/result_line_2_code.dart';
import 'package:offibox/ui/results/result_line_4_rappel_alert.dart';
import 'package:offibox/utils/gs1_scan_payload.dart';

class SelectedResultView extends StatelessWidget {
  final SearchResult item;
  /// Annuaire RPPS : nombre de structures (badge « Structures » affiché seulement si > 1).
  final int? rppsStructureCountForSelected;
  final VoidCallback? onOpenSelected;
  final VoidCallback? onClose;
  final List<String>? statutsForCis;
  /// Taux de remboursement (ex. "65 %") pour la modale « plus d'infos » (ligne 3).
  final String? tauxRemboursement;
  /// Composition BDPM "colD : colE pour colF" pour modale « + d'infos » (ligne 1).
  final String? compositionLine;
  /// Listes (ex. ["Liste 1", "Liste 2"]) pour modale « + d'infos » (ligne 2).
  final List<String>? listes;
  /// CIS → info statut ANSM (source : fichiers-medicaments/statutsANSM.csv).
  final Map<String, AnsmStatutInfo>? ansmStatutsByCis;
  /// Ouverture des URL (badges statut ANSM, plus d’infos, etc.) une fois le résultat injecté dans la barre.
  final Map<String, Generique2026Info>? generiques2026ByCis;
  final Map<String, String>? generiques2026PrincepsKeyToGenericName;
  final Map<String, String>? generiques2026DciToGenericName;
  final Set<String>? generiques2026CisSet;
  final Map<String, String>? biosimilairesInfoByCip;
  final Map<String, String>? compositionByCis;
  final void Function(String url)? onOpenUrl;
  final void Function(BuildContext context, String url, String labName, String? iconUrl)? onOpenEspacePro;
  final VoidCallback? onOpenCataloguePanel;
  final void Function(String youtubeUrl)? onOpenYouTubeVideo;
  /// Au clic sur le pill "video" (ligne 2 BDM) : affiche le panneau vidéo thérapeutique.
  final void Function(String url)? onOpenTherapeuticVideo;
  /// CIP13 (chiffres) → URL vidéo (feuille videos). Pour pill "video" en ligne 2.
  final Map<String, String>? videosByCip13;
  /// Ouvre le panneau Flash info Pharmaradio sous la barre (au clic sur le pill « Flash info »).
  final VoidCallback? onOpenPharmaradioFlash;
  /// Payload du dernier scan GS1 : affiche expiration, lot, n° série en ligne 1.
  final Gs1ScanPayload? scanPayload;
  /// Noms normalisés des produits en rappel ANSM (pour affichage « produit concerné par un rappel de lot N° »).
  final Set<String>? recalledProductNames;
  /// Dernier rappel ANSM (ticker) : date en ligne 2, alerte ligne 4 si < 15 jours.
  final AnsmRappelItem? ansmLastRappel;
  /// Rappel correspondant à ce médicament pour le badge rouge ligne 3 « rappel de produit + date » (clic → ANSM).
  final AnsmRappelItem? rappelForLine3Badge;
  /// CIS avec « arrêt de commercialisation » (CIS_CIP_Dispo_Spec) — badge ligne 2 pour ces NSFP.
  final Set<String>? cisArretCommercialisation;
  /// CIS → date + URL pour le badge « arrêt de commercialisation » (clic → ouvrir URL).
  final Map<String, ArretCommercialisationInfo>? arretCommercialisationByCis;
  /// URL fiche VOC patient (OMÉDIT) — pill ligne 3 si BDM.
  final String? vocPatientUrl;
  /// URL fiche VOC pro (OMÉDIT) — pill ligne 3 si BDM.
  final String? vocProUrl;
  /// CIP13 hospitaliers — badge « non remboursé » si BDM hors liste et sans taux.
  final Set<String>? hospitalCip13Set;
  /// fic03spe ANSM (CIS_CIP8 → "R"|"G") pour badge Princeps (R) ou Gé vert (G) en ligne 1 BDM.
  final Map<String, String>? cip13ToFic03Status;
  /// Au clic sur le badge DCI (princeps) : lance une recherche avec la DCI pour afficher les génériques sous la barre.
  final void Function(String dci)? onDciTap;

  const SelectedResultView({
    super.key,
    required this.item,
    this.rppsStructureCountForSelected,
    this.onOpenSelected,
    this.onClose,
    this.statutsForCis,
    this.tauxRemboursement,
    this.compositionLine,
    this.listes,
    this.ansmStatutsByCis,
    this.generiques2026ByCis,
    this.generiques2026PrincepsKeyToGenericName,
    this.generiques2026DciToGenericName,
    this.generiques2026CisSet,
    this.biosimilairesInfoByCip,
    this.compositionByCis,
    this.onOpenUrl,
    this.onOpenEspacePro,
    this.onOpenCataloguePanel,
    this.onOpenYouTubeVideo,
    this.onOpenTherapeuticVideo,
    this.videosByCip13,
    this.onOpenPharmaradioFlash,
    this.scanPayload,
    this.recalledProductNames,
    this.ansmLastRappel,
    this.rappelForLine3Badge,
    this.cisArretCommercialisation,
    this.arretCommercialisationByCis,
    this.vocPatientUrl,
    this.vocProUrl,
    this.hospitalCip13Set,
    this.cip13ToFic03Status,
    this.onDciTap,
  });

  @override
  Widget build(BuildContext context) {
    // Même structure et espacements que ResultTile avec isSingleResult: true (liste à 1 résultat).
    final parts = <String>[];
    if (scanPayload?.expirationMMYY != null && scanPayload!.expirationMMYY!.isNotEmpty) {
      parts.add('Expiration : ${scanPayload!.expirationMMYY}');
    }
    if (scanPayload?.lot != null && scanPayload!.lot!.isNotEmpty) {
      parts.add('Lot : ${scanPayload!.lot}');
    }
    if (scanPayload?.serialNumber != null && scanPayload!.serialNumber!.isNotEmpty) {
      parts.add('N° série : ${scanPayload!.serialNumber}');
    }
    final scanLine = parts.isNotEmpty ? parts.join(' · ') : null;

    final bool isVetoInjectable = item.source == SourceType.veto &&
        item.labelRaw.toLowerCase().contains('inject');
    final double line2ToLine3Height = item.source == SourceType.veto
        ? (isVetoInjectable ? 0.0 : 2.0)
        : 9.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scanLine != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                scanLine,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontFamily: 'Spinnaker',
                ),
              ),
            ),
          ],
          ResultLine1(
            item: item,
            label: ResultLabelHelper.displayLabel(item),
            query: '',
            hasNsfpDate: item.isNsfpEffective,
            onOpenUrl: onOpenUrl ?? (_) {},
            statutsForCis: statutsForCis,
            tauxRemboursement: tauxRemboursement,
            compositionLine: compositionLine,
            listes: listes ?? const [],
            hospitalCip13Set: hospitalCip13Set,
            generiques2026ByCis: generiques2026ByCis,
            generiques2026PrincepsKeyToGenericName: generiques2026PrincepsKeyToGenericName,
            cip13ToFic03Status: cip13ToFic03Status,
            scaleDownToFitLine1: true,
          ),
          const SizedBox(height: 2),
          ResultLine2Code(
            item: item,
            onOpenUrl: onOpenUrl,
            ansmStatutsByCis: ansmStatutsByCis,
            generiques2026ByCis: generiques2026ByCis,
            generiques2026PrincepsKeyToGenericName: generiques2026PrincepsKeyToGenericName,
            generiques2026DciToGenericName: generiques2026DciToGenericName,
            biosimilairesInfoByCip: biosimilairesInfoByCip,
            onOpenEspacePro: onOpenEspacePro,
            onOpenCataloguePanel: onOpenCataloguePanel,
            onOpenYouTubeVideo: onOpenYouTubeVideo,
            videosByCip13: videosByCip13,
            onOpenTherapeuticVideo: onOpenTherapeuticVideo,
            onOpenPharmaradioFlash: onOpenPharmaradioFlash,
            isInjected: true,
            recalledProductNames: recalledProductNames,
            ansmLastRappel: ansmLastRappel,
            cisArretCommercialisation: cisArretCommercialisation,
            arretCommercialisationByCis: arretCommercialisationByCis,
            statutsForCis: statutsForCis,
            tauxRemboursement: tauxRemboursement,
            compositionLine: compositionLine,
            listes: listes,
            vocPatientUrl: vocPatientUrl,
            vocProUrl: vocProUrl,
            onDciTap: onDciTap,
          ),
          SizedBox(height: line2ToLine3Height),
          ResultLine3Actions(
            item: item,
            rppsStructureCountForSelected: rppsStructureCountForSelected,
            generiques2026CisSet: generiques2026CisSet,
            isInjected: true,
            onOpenUrl: onOpenUrl,
            vocPatientUrl: vocPatientUrl,
            vocProUrl: vocProUrl,
            videosByCip13: videosByCip13,
            onOpenTherapeuticVideo: onOpenTherapeuticVideo,
            rappelForLine3Badge: rappelForLine3Badge,
          ),
          ResultLine4RappelAlert(
            item: item,
            ansmLastRappel: ansmLastRappel,
            onOpenUrl: onOpenUrl,
          ),
          // Codes actes : image thématique (honoraires ordonnance, entretiens, dépistage, etc.)
          if (item.source == SourceType.codesActes) ...[
            _CodesActesImageSection(label: item.label),
          ],
        ],
      ),
    );
  }
}

/// Retourne le chemin avec l'extension remplacée par .webp (pour fallback depuis .png / .jpg).
String _assetPathToWebp(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return path.substring(0, path.length - 4) + '.webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return path.substring(0, path.length - (lower.endsWith('.jpeg') ? 5 : 4)) + '.webp';
  return path;
}

/// Affiche l'image asset associée au code acte sélectionné (sous la barre de recherche).
/// Gère .png, .webp (et .jpg) dans assets/images.
class _CodesActesImageSection extends StatelessWidget {
  final String label;

  const _CodesActesImageSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final assetPath = codesActesImageAssetForLabel(label);
    if (assetPath == null || assetPath.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Image.asset(
              _assetPathToWebp(assetPath),
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
