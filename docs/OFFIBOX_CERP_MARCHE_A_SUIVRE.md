# Marche à suivre : créer l’appli Offibox-CERP

L’appli peut exister en **deux variantes** selon le type de clients et leur groupement :
- **Offibox** (classique)
- **Offibox-CERP** (CERP / groupements)

Vous pouvez soit **dupliquer le projet** (deux applis distinctes), soit utiliser des **flavors** dans le même projet (une base de code, deux builds). La fiche client dans Firebase permet d’associer chaque utilisateur à une variante et à un groupement.

---

## Option A : Flavors (recommandé – un seul code, deux builds)

Un seul dépôt, deux “flavors” : `offibox` et `offibox_cerp`. Chaque build a son propre nom, identifiant et (optionnel) sa propre app Firebase.

### 1. Configurer les flavors Flutter

**1.1** Dans `pubspec.yaml`, garder le `name: offibox` (le package Dart reste commun).

**1.2** Créer des fichiers de configuration par flavor (ex. à la racine ou dans `config/`) :

- `config/offibox/app_config.dart` (ou via `--dart-define`)

```dart
class AppConfig {
  static const String appName = 'Offibox';
  static const String appVariant = 'offibox';
  static const String packageId = 'com.example.offibox';
}
```

- `config/offibox_cerp/app_config.dart`

```dart
class AppConfig {
  static const String appName = 'Offibox-CERP';
  static const String appVariant = 'offibox_cerp';
  static const String packageId = 'com.example.offibox.cerp';
}
```

Ou utiliser des **dart-defines** au build :

```bash
flutter build windows --dart-define=APP_NAME="Offibox-CERP" --dart-define=APP_VARIANT=offibox_cerp
```

**1.3** Dans le code, remplacer les chaînes en dur “Offibox” par une valeur lue depuis cette config (titre fenêtre, menu, about, etc.).

### 2. Android : deux applicationId

Dans `android/app/build.gradle.kts`, définir des **product flavors** :

```kotlin
android {
    namespace = "com.example.offibox"
    // ...

    flavorDimensions += "app"
    productFlavors {
        create("offibox") {
            dimension = "app"
            applicationId = "com.example.offibox"
            resValue("string", "app_name", "Offibox")
        }
        create("offiboxCerp") {
            dimension = "app"
            applicationId = "com.example.offibox.cerp"
            resValue("string", "app_name", "Offibox-CERP")
        }
    }
}
```

Builds :

- `flutter build apk --flavor offibox`
- `flutter build apk --flavor offiboxCerp`

### 3. Windows : nom de l’exécutable et de la fenêtre

- **CMake** : le nom du binaire est défini dans `windows/CMakeLists.txt`. Pour CERP, vous pouvez passer un argument ou dupliquer la config (ex. `set(BINARY_NAME "offibox_cerp")` pour le build CERP).
- **Runner.rc** : adapter `ProductName`, `FileDescription`, `OriginalFilename` (ex. `offibox_cerp.exe`) pour le build CERP. En pratique, on peut utiliser un script ou un second `Runner.rc` pour le flavor CERP.
- **main.cpp** : titre de fenêtre `L"offibox"` → le rendre dépendant d’une constante (dart-define ou config C++ générée) pour afficher “Offibox-CERP” pour le flavor CERP.

En résumé : un build “CERP” = même code, mais avec `APP_NAME` / `BINARY_NAME` / `ProductName` = “Offibox-CERP” et un identifiant distinct si besoin (ex. protocol `offibox-cerp://` pour auth).

### 4. Firebase : une ou deux apps dans le même projet

- **Même projet Firebase (offibox-prod)**  
  - Ajouter une **deuxième application** dans la console Firebase (Android / Windows selon vos cibles) pour “Offibox-CERP” (nouveau `applicationId` / `appId`).  
  - Générer un second `google-services.json` (Android) et, si vous utilisez FlutterFire pour Windows, une config dédiée.  
  - Dans le projet Flutter, avoir deux jeux d’options Firebase (ex. `firebase_options_offibox.dart` et `firebase_options_offibox_cerp.dart`) et choisir celui à charger selon le flavor au démarrage (`main.dart`).

- **Projet Firebase séparé**  
  - Créer un projet “offibox-cerp-prod” et y enregistrer l’app Offibox-CERP. Même code, mais `DefaultFirebaseOptions` chargé selon le flavor pointe vers ce projet. Firestore / Auth sont alors totalement séparés (vous pouvez quand même garder une “fiche client” côté Offibox si vous gérez les deux depuis le même back-office).

### 5. Installateur Windows (WiX / MSI)

- Dupliquer ou paramétrer le projet WiX pour produire un second installateur “Offibox-CERP” :
  - Nom du produit : Offibox-CERP  
  - Identifiant (GUID) différent  
  - Répertoire d’installation distinct (ex. `Offibox-CERP`)  
  - Binaire : celui du build `flutter build windows` avec flavor CERP  

Ainsi, sur une même machine on peut avoir Offibox et Offibox-CERP installés côte à côte.

### Commandes de build (Option A — implémentée)

- **Offibox (défaut)**  
  - Windows : `flutter build windows`  
  - Android : `flutter build apk --flavor offibox`  

- **Offibox-CERP**  
  - Windows :  
    `flutter build windows --dart-define=APP_NAME=Offibox-CERP --dart-define=APP_VARIANT=offibox_cerp`  
  - Android :  
    `flutter build apk --flavor offiboxCerp --dart-define=APP_NAME=Offibox-CERP --dart-define=APP_VARIANT=offibox_cerp`  

La config (nom d’app, variante, clé Registre) est lue depuis `lib/config/app_config.dart` (dart-defines en build, défaut = Offibox).

---

### Commandes de build (Option A — implémentée)

- **Offibox (défaut)** : `flutter build windows` ou `flutter build apk --flavor offibox`
- **Offibox-CERP** :  
  - Windows : `flutter build windows --dart-define=APP_NAME=Offibox-CERP --dart-define=APP_VARIANT=offibox_cerp`  
  - Android : `flutter build apk --flavor offiboxCerp --dart-define=APP_NAME=Offibox-CERP --dart-define=APP_VARIANT=offibox_cerp`  
Config : `lib/config/app_config.dart` (dart-defines au build, défaut = Offibox).

---

## Option B : Dupliquer entièrement le projet (deux dépôts / deux applis)

Vous obtenez deux applis totalement indépendantes (deux noms, deux packages, deux Firebase possibles).

### 1. Copie du projet

- Copier tout le dossier du projet (ex. `offibox` → `offibox-cerp`).
- Renommer le dossier racine en `offibox-cerp`.

### 2. Renommage global

- **pubspec.yaml** : `name: offibox_cerp`, `description: Offibox-CERP ...`
- **Android** : `applicationId` et `namespace` → `com.example.offibox.cerp` (ou votre domaine).
- **iOS/macOS** : `bundleId` → `com.example.offibox.cerp`
- **Windows** : dans `CMakeLists.txt` et `Runner.rc`, remplacer “offibox” par “offibox_cerp” (nom binaire, `ProductName`, etc.).
- **Protocol** : si vous gardez une auth redirect, enregistrer par ex. `offibox-cerp` au lieu de `offibox` dans `main.dart` (et côté site web CERP).
- **Imports** : tous les `package:offibox/` deviennent `package:offibox_cerp/` (rechercher/remplacer dans tout le projet).

### 3. Firebase

- Soit **même projet** : ajouter une nouvelle application “Offibox-CERP” dans le projet Firebase existant, télécharger les config (google-services.json, etc.) et régénérer `firebase_options.dart` pour ce nouveau appId.
- Soit **nouveau projet** : créer “offibox-cerp-prod”, y ajouter les apps (Android, Windows, etc.), configurer Firestore/Auth/Functions, et remplacer `firebase_options.dart` et les règles par celles de ce projet.

### 4. Différences métier Offibox vs Offibox-CERP

Dans le clone CERP, adapter :

- Textes, logos, titres : “Offibox-CERP” partout où c’est pertinent.
- Fonctionnalités ou écrans spécifiques CERP (ex. onglets, liens, données groupement).
- Si vous utilisez la **fiche client** Firebase (voir ci‑dessous), l’app CERP peut quand même lire le document `users/{uid}` (ou `clients/{uid}`) pour afficher le groupement ou des paramètres spécifiques.

### 5. Build et installateur

- Builder l’app CERP : `flutter build windows` (ou apk/ios selon la cible) dans le projet `offibox-cerp`.
- Créer un installateur MSI dédié “Offibox-CERP” (nom, GUID, répertoire d’installation distincts).

---

## Fiche client dans Firebase (Offibox vs Offibox-CERP, groupement)

Pour savoir quels clients utilisent Offibox classique, Offibox-CERP, et à quel groupement ils appartiennent, on s’appuie sur une **fiche client** dans Firestore.

### Option 1 : Étendre la collection `users` (recommandé si tout est dans le même projet)

Chaque utilisateur a déjà un document `users/{uid}`. Ajoutez-y les champs suivants (créés à l’inscription ou par un back-office / Cloud Function) :

| Champ            | Type   | Description |
|------------------|--------|-------------|
| `appVariant`     | string | `"offibox"` ou `"offibox_cerp"` selon l’app utilisée (ou à laquelle le client est rattaché). |
| `groupement`     | string | Nom ou ID du groupement (ex. CERP Aster, CERP Bretagne…). Optionnel pour Offibox classique. |
| `groupementId`   | string | ID technique du groupement si vous avez une collection `groupements`. Optionnel. |
| `clientName`     | string | Nom de l’officine / du client pour l’admin. |
| `onboardingDone` | bool   | (existant) |
| `plan`           | string | (existant) |
| `trialEndsAt`     | timestamp | (existant) |
| `maxDevices`     | number | (existant) |

Exemple de document `users/{uid}` :

```json
{
  "email": "pharmacie@example.fr",
  "appVariant": "offibox_cerp",
  "groupement": "CERP Aster",
  "groupementId": "cerp_aster",
  "clientName": "Pharmacie Dupont",
  "plan": "pro",
  "onboardingDone": true,
  "maxDevices": 5
}
```

- **Offibox classique** : `appVariant === "offibox"` (ou absent).  
- **Offibox-CERP** : `appVariant === "offibox_cerp"`, avec `groupement` / `groupementId` renseignés.

Vous pouvez créer ces champs depuis la console Firebase, depuis un **tableau de bord admin** (lecture/écriture Firestore), ou via une **Cloud Function** déclenchée à la création du compte ou par un script.

### Option 2 : Collection dédiée `clients`

Si vous préférez séparer “compte utilisateur” (Auth + `users/{uid}`) et “fiche client métier” :

- Créer une collection **`clients`** avec un document par utilisateur (même id que l’uid pour faciliter les requêtes) :

**`clients/{uid}`**

| Champ          | Type   | Description |
|----------------|--------|-------------|
| `userId`       | string | `uid` Firebase Auth (redondant avec l’id du document). |
| `appVariant`   | string | `"offibox"` \| `"offibox_cerp"` |
| `groupement`   | string | Nom du groupement |
| `groupementId` | string | ID du groupement |
| `clientName`   | string | Nom officine / client |
| `createdAt`    | timestamp | Date de création de la fiche |
| `updatedAt`   | timestamp | Dernière mise à jour |

Règles Firestore (exemple) :

- L’utilisateur ne peut lire que **son** document : `clients/{uid}` où `uid == request.auth.uid`.
- Seuls les admins (ou une Cloud Function) peuvent créer/modifier les fiches (ou écrire dans `users/{uid}` pour `appVariant` / `groupement`).

L’app (Offibox ou Offibox-CERP) au démarrage peut :

1. Lire `users/{uid}` (ou `clients/{uid}`) après connexion.
2. Vérifier `appVariant` pour adapter le branding ou refuser l’accès si l’utilisateur s’est connecté avec la “mauvaise” app (optionnel).
3. Afficher le `groupement` dans l’app CERP (barre latérale, en-tête, etc.).

Un **modèle Dart** pour la fiche client et un **provider** pour le charger depuis Firestore sont fournis dans le projet (voir `lib/models/client_profile.dart` et éventuellement un provider dans `lib/providers/`).

---

## Récapitulatif

| Étape | Option A (Flavors) | Option B (Copie) |
|-------|--------------------|------------------|
| Code | Un projet, deux flavors | Deux projets distincts |
| Nom / ID app | Config par flavor (app_name, applicationId) | Renommage complet du clone |
| Firebase | 1 ou 2 apps (même projet ou non) | 1 ou 2 projets selon besoin |
| Fiche client | Firestore `users` ou `clients` avec `appVariant` + `groupement` | Idem |
| Maintenance | Une base de code, deux builds | Deux bases à maintenir |

Recommandation : **Option A (flavors)** pour garder une seule codebase, et **fiche client dans `users/{uid}`** (champs `appVariant`, `groupement`, `clientName`) dans le **même projet Firebase** pour gérer Offibox et Offibox-CERP depuis un seul back-office et une seule base de données.
