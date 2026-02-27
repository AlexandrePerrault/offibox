import 'package:flutter/widgets.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/search/medicine_picto.dart';
import 'package:offibox/search/mte_molecules.dart';
import 'package:offibox/ui/spans/common_spans.dart';
import 'package:offibox/models/source_type.dart';

final List<MedicinePicto> medicinePictos = [

// 🩹 DM / LPP
MedicinePicto(
  isVisible: (item) =>
      item.source == SourceType.dm,
  build: (_) => dmSquareSpan(),
),

// 🐾 VÉTÉRINAIRE
MedicinePicto(
  isVisible: (item) => item.source == SourceType.veto,
  build: (_) => vetoSquareSpan(),
),


  // 🩸 MDS — Médicaments dérivés du sang
  MedicinePicto(
    isVisible: (item) => item.isMds == true,
    build: (_) => mdsSquareSpan(),
  ),

  // 🟥 HÔPITAL — affiché en ligne 1 (result_line_1)
  // MedicinePicto HOP supprimé : ajout explicite en ligne 1

  // 🚨 STUPÉFIANT — affiché en ligne 1 (result_line_1)
  // MedicinePicto stup supprimé : ajout explicite en ligne 1

  // ❌ NSFP
  MedicinePicto(
    isVisible: (item) =>
        item.nsfpDate != null && item.nsfpDate!.isNotEmpty,
    build: (_) => nsfpIconSpan(),
  ),

  // 🟦 EXCEPTION — affiché en ligne 1 (result_line_1)
  // MedicinePicto exception supprimé : ajout explicite en ligne 1

// 🟧 PIH — affiché en ligne 1 (result_line_1)
  // MedicinePicto PIH supprimé : ajout explicite en ligne 1

// 🟪 SURVEILLANCE PARTICULIÈRE
MedicinePicto(
  isVisible: (item) => item.isSurveillanceParticuliere == true,
  build: (_) => surveillanceSquareSpan(),
),

// 🔴 MTE — Marge thérapeutique étroite (lacosamide, oxcarbazépine, lamotrigine, etc.)
MedicinePicto(
  isVisible: (item) => isMteMolecule(item),
  build: (_) => mteSquareSpan(
    tooltip: 'Médicaments à marge thérapeutique étroite',
  ),
),

// 🟩 OTC — affiché en ligne 1 (result_line_1)
  // MedicinePicto OTC supprimé : ajout explicite en ligne 1

// 🏥 AMC : badge MUT affiché dans result_line_1 (éviter doublon)

// ======================================================
// 📘 LPP — BADGE
// ======================================================
MedicinePicto(
  isVisible: (item) => item.source == SourceType.lpp,
  build: (_) => lppSquareSpan(
    tooltip: 'Code LPP',
  ),
),


  // 🧬 BIOSIMILAIRE (sans tooltip vert « Biosimilaire de X »)
  MedicinePicto(
    isVisible: (item) =>
        item.biosimilaireOf != null && item.biosimilaireOf!.isNotEmpty,
    build: (item) => clickableMarkerSpan(
      emoji: '🧬',
      url: 'https://ansm.sante.fr/documents/reference/medicaments-biosimilaires',
    ),
  ),
];


// ======================================================
// 🧬 BUILD MEDICINE PICTOS (pour ResultLine1)
// ======================================================
List<InlineSpan> buildMedicinePictos(SearchResult item) {
  final spans = <InlineSpan>[];

  for (final picto in medicinePictos) {
    if (picto.isVisible(item)) {
      spans.add(picto.build(item));
      spans.add(const TextSpan(text: ' '));
    }
  }

  return spans;
}


