/// Configuration des mises à jour automatiques.
/// Les releases doivent être publiées sur GitHub avec des tags (ex: v1.0.1).
class AppUpdateConfig {
  AppUpdateConfig._();

  /// Repo GitHub pour les releases (format: owner/repo)
  static const String githubRepo = 'AlexandrePerrault/offibox';

  /// URL de l'API GitHub Releases (appel interne uniquement, pas visible par le client).
  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubRepo/releases/latest';

  /// Page de téléchargement affichée aux clients (bouton « Télécharger », liens).
  /// Les utilisateurs n’arrivent pas sur GitHub.
  static const String publicDownloadPageUrl = 'https://offibox.fr/download';

  /// Page d'inscription Offibox (formulaire web) utilisée pour la première connexion
  /// depuis le site et depuis l'application desktop.
  /// Hébergée sur GitHub Pages (gratuit) ; voir website/deploy-netlify/README.md.
  static const String publicInscriptionPageUrl =
      'https://alexandreperrault.github.io/offibox/html/inscription.html';

  /// Base URL pour l’installer Windows. Si défini, téléchargement depuis
  /// [publicDownloadBaseUrl]/[windowsInstallerName]-[version].msi au lieu de GitHub.
  static const String publicDownloadBaseUrl = 'https://offibox.fr/download';

  /// Nom du fichier installer Windows (sans extension) pour l’URL publique.
  static const String windowsInstallerName = 'Offibox';

  /// Clé SharedPreferences pour la date de dernière vérification
  static const String lastCheckKey = 'app_update_last_check';

  /// Clé SharedPreferences : ne plus afficher la demande d'installation (auto-install au démarrage)
  static const String doNotAskKey = 'app_update_do_not_ask';

  /// Extension de l'installer Windows recherchée (MSI généré par WiX)
  static const String windowsAssetExtension = '.msi';

  /// URL affichée sur iOS quand une mise à jour est disponible.
  static String get iosUpdateUrl => publicDownloadPageUrl;
}
