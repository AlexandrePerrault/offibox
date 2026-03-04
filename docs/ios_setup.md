# Offibox iOS — configuration

## Connexion Google et Email au démarrage

Sur iOS, l’app affiche d’abord une **page de connexion** (Google ou email/mot de passe via Firebase Auth). Une fois connecté, l’utilisateur accède au shell avec la barre de recherche en haut en **mode paysage**.

## Google Sign-In sur iOS

1. **Firebase** : ajouter une application iOS dans le projet Firebase (Bundle ID = celui du projet Xcode), télécharger `GoogleService-Info.plist` et le placer dans `ios/Runner/`.

2. **URL scheme pour Google Sign-In** : dans `ios/Runner/Info.plist`, ajouter une entrée `CFBundleURLTypes` avec le **reversed client ID** (ex. `com.googleusercontent.apps.123456789-xxxx`) présent dans `GoogleService-Info.plist` (clé `REVERSED_CLIENT_ID`). Exemple :

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>VOTRE_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

3. **Google Cloud Console** : activer l’API Google Sign-In et configurer l’écran de consentement OAuth si besoin.

## Orientation

- **Portrait** : message invitant à tourner l’iPad/téléphone en mode paysage pour profiter pleinement d’Offibox.
- **Paysage** : barre de recherche en haut, résultats en dessous (même logique que la version Windows).

## Build

```bash
flutter build ios
```

Ou ouvrir `ios/Runner.xcworkspace` dans Xcode et lancer sur simulateur ou appareil.
