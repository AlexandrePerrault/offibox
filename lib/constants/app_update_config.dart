/// Configuration des mises à jour automatiques.
/// Mode 1 (dépôt public) : API GitHub releases/latest pour la version + téléchargement depuis [publicDownloadBaseUrl].
/// Mode 2 (dépôt privé) : [customLatestVersionUrl] renvoie un JSON { "version": "1.1.26", "download_url": "https://..." }.
///   Les clients téléchargent sans accès GitHub ; mettre offibox en privé et héberger le .exe sur ton site.
class AppUpdateConfig {
  AppUpdateConfig._();

  /// Repo GitHub pour les releases (format: owner/repo). Utilisé seulement si [customLatestVersionUrl] est vide.
  static const String githubRepo = 'AlexandrePerrault/offibox';

  /// Si défini, l'app utilise cette URL au lieu de l'API GitHub pour détecter la dernière version.
  /// Réponse attendue (JSON) : { "version": "1.1.26", "download_url": "https://offibox.fr/download/Offibox-Setup-1.1.26.exe" }
  /// Permet de garder le dépôt offibox en privé tout en laissant les clients télécharger depuis ton site.
  static const String customLatestVersionUrl = 'https://offibox.fr/download/latest.json';

  /// URL de l'API GitHub Releases (utilisée seulement si [customLatestVersionUrl] est vide).
  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubRepo/releases/latest';

  /// Page de téléchargement affichée aux clients (bouton « Télécharger », liens).
  /// Les utilisateurs n’arrivent pas sur GitHub.
  static const String publicDownloadPageUrl = 'https://offibox.fr/download';

  /// Page d'inscription Offibox (page officielle du site ; le formulaire est embarqué en iframe).
  /// Utilisée pour la première connexion depuis le site et depuis l'application (PC, web).
  static const String publicInscriptionPageUrl =
      'https://www.offibox.fr/inscription';

  /// Base URL pour l’installer Windows. Si défini, téléchargement depuis
  /// [publicDownloadBaseUrl]/[windowsInstallerName]-[version].exe (ou via [customLatestVersionUrl]).
  static const String publicDownloadBaseUrl = 'https://offibox.fr/download';

  /// Nom du fichier installer Windows sans extension (ex. Offibox-Setup pour Offibox-Setup-1.1.26.exe).
  static const String windowsInstallerName = 'Offibox-Setup';

  /// Clé SharedPreferences pour la date de dernière vérification
  static const String lastCheckKey = 'app_update_last_check';

  /// Clé SharedPreferences : ne plus afficher la demande d'installation (auto-install au démarrage)
  static const String doNotAskKey = 'app_update_do_not_ask';

  /// Extension de l'installer Windows (.exe Inno Setup ou .msi WiX)
  static const String windowsAssetExtension = '.exe';

  /// URL affichée sur iOS quand une mise à jour est disponible.
  static String get iosUpdateUrl => publicDownloadPageUrl;
}
