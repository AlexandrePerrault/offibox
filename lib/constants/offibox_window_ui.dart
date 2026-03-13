import 'package:flutter/material.dart';

class OffiboxWindowUI {
  // ───────────────────────────
  // DIMENSIONS GÉNÉRALES
  // ───────────────────────────
  /// Largeur barre repliée : doit contenir logo (pill) + menu (évite RenderFlex overflow).
  static const double collapsedWidth = 116;
  /// Pill légèrement plus petit que la barre (66) pour éviter le débordement du rendu (ombre, scale).
  static const double pillSize = 60;

  // ───────────────────────────
  // BARRE PRINCIPALE (déploiement plus compact)
  // ───────────────────────────
  static const double barHeight = 68;           // état normal
  static const double barHeightExpanded = 118;  // 2 lignes (titre + badges)
  /// 3 lignes : titre + badges + RCP/MEDDISPAR/Sources
  static const double barHeightExpandedThreeLines = 146;
  /// 4 lignes : + ligne biosimilaires / bonnes pratiques
  static const double barHeightExpandedFourLines = 174;
  /// Hauteur barre quand le résultat sélectionné est sur une ligne (outils métier, sites web, catalogues).
  static const double barHeightExpandedSingleLine = 96;  // une à deux lignes
  /// Hauteur barre quand elle est déployée mais vide (aucun résultat sélectionné) : -20 % par rapport à une ligne.
  static const double barHeightExpandedEmpty = barHeightExpandedSingleLine * 0.8;

  // ───────────────────────────
  // POSITIONNEMENT (2 cm du bord ≈ 76 px logical)
  // ───────────────────────────
  static const double rightMargin = 76;
  static const double topMargin = 76;
  /// Web (iframe Wix) : marges réduites pour rapprocher le logo du bandeau animation.
  static const double topMarginWeb = 12;
  static const double rightMarginWeb = 16;
  static const double gapBelowBar = 8;

  /// Hauteur barre d'infos (ticker).
  static const double tickerBarHeight = 38;
  /// Hauteur des badges (toggle INFOS, pills rouges/bleus) — moitié de la barre, centrés.
  static const double tickerBadgeHeight = 19;
  static const double tickerBarGap = 6;

  /// Style unifié badge INFOS + messages déroulants (rouge mat, pill, typo).
  static const Color tickerInfosRed = Color(0xFFB71C1C);
  /// Couleur du badge INFOS (vert mat discret).
  static const Color tickerInfosBadgeGreen = Color(0xFF4E8A72);
  static const double tickerBadgeBorderRadius = 8;
  static const double tickerBadgeFontSize = 10;
  static const EdgeInsets tickerBadgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 2.5);

  /// Y minimum pour les menus : sous la barre (cas max = TickerBar + barre étendue)
  static double get menuBelowBarTop =>
      topMargin + tickerBarHeight + tickerBarGap + barHeightExpanded + gapBelowBar;

  // ───────────────────────────
  // STYLE
  // ───────────────────────────
  static const double borderRadius = 15;

  /// Taille commune du bouton filtre (gauche) et du bouton menu hamburger (droite) dans la barre.
  static const double menuButtonSize = 40;
}
