/// Gestion de la position de la fenêtre (sauvegarde/restauration, visibilité au démarrage).
class WindowPosition {
  /// Assure que la fenêtre est visible au démarrage (position sûre).
  static Future<void> ensureVisibleAtStartup() async {
    // No-op si pas d'implémentation plateforme (windows_*); à surcharger si besoin.
  }

  /// Restaure la position sauvegardée et écoute les changements.
  static Future<void> restoreAndListen() async {
    // No-op; à implémenter avec window_manager ou API Windows si besoin.
  }
}
