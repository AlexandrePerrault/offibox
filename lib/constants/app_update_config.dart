/// Configuration des mises à jour automatiques.
/// Les releases doivent être publiées sur GitHub avec des tags (ex: v1.0.1).
class AppUpdateConfig {
  AppUpdateConfig._();

  /// Repo GitHub pour les releases (format: owner/repo)
  static const String githubRepo = 'AlexandrePerrault/offibox';

  /// URL de l'API GitHub Releases
  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubRepo/releases/latest';

  /// Clé SharedPreferences pour la date de dernière vérification
  static const String lastCheckKey = 'app_update_last_check';

  /// Clé SharedPreferences : ne plus afficher la demande d'installation (auto-install au démarrage)
  static const String doNotAskKey = 'app_update_do_not_ask';

  /// Extension de l'installer Windows recherchée (MSI généré par WiX)
  static const String windowsAssetExtension = '.msi';
}
