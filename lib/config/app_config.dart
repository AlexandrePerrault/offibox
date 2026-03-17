/// Configuration par variante d'app (flavor): Offibox vs Offibox-CERP.
/// Valeurs au build via --dart-define, sinon defaut Offibox.
class AppConfig {
  AppConfig._();

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Offibox',
  );

  static const String appVariant = String.fromEnvironment(
    'APP_VARIANT',
    defaultValue: 'offibox',
  );

  static const String packageId = String.fromEnvironment(
    'APP_PACKAGE_ID',
    defaultValue: 'com.example.offibox',
  );

  /// true si le build est ciblé Windows avec registre/autostart (flutter build windows --dart-define=FLUTTER_BUILD_WINDOWS=true).
  /// Utilisé pour l'import conditionnel stub vs installer_autostart_windows.
  static const bool flutterBuildWindows = bool.fromEnvironment(
    'FLUTTER_BUILD_WINDOWS',
    defaultValue: false,
  );

  static String get registryPath => appName;
  static bool get isOffiboxCerp => appVariant == 'offibox_cerp';

  /// CERP (catalogue équipement, client BA, etc.) : désactivé dans le build principal.
  /// Réactiver pour un setup MSI dédié (dossier CERP sur GitHub).
  static const bool cerpFeaturesEnabled = false;

  /// Mode essai sans identification : pas de login, 15 jours à partir du premier lancement.
  /// Build : flutter build windows --dart-define=OFFIBOX_TRIAL_NO_AUTH=true
  static const bool trialNoAuth = bool.fromEnvironment(
    'OFFIBOX_TRIAL_NO_AUTH',
    defaultValue: false,
  );
}
