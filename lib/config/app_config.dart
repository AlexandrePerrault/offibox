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

  static String get registryPath => appName;
  static bool get isOffiboxCerp => appVariant == 'offibox_cerp';
}
