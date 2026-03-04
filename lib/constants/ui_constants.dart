import 'package:flutter/material.dart';

/// 🎨 Couleurs Offibox (source unique)
class OffiboxColors {
  static const Color primary = Color(0xFF5A9094);
  static const Color darkGray = Color(0xFF3F4346);
  /// Teal très léger (skeleton, placeholders)
  static const Color tealLight = Color(0xFFE8F5F4);
}
const Color offiboxGrey = Color(0xFF6B7280);

/// 📐 Tailles communes
const double actionButtonSize = 40;

/// 📐 Résultats de recherche (liste, tuiles)
/// Espace vertical entre la ligne 1 (libellé) et la ligne 2 (codes / badges).
const double resultLineGap = 4;
/// Padding horizontal des tuiles dans le panneau de résultats.
const double resultTileHorizontalPadding = 12;
/// Padding vertical minimal d’une tuile (confort au clic).
const double resultTileVerticalPadding = 10;
