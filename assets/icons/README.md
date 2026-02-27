# Icônes Offibox

## Où mettre les icônes pour le projet

**Tous les fichiers d’icônes (PNG, SVG, JPG, etc.) doivent être placés ici :**

```
offibox/assets/icons/
```

Exemples de chemins complets :
- `assets/icons/logo text.png` — logo texte à côté de « Rechercher sur »
- `assets/icons/logo_offibox.png` — logo pill / boîte
- `assets/icons/filtre.png` — bouton filtre
- `assets/icons/logo_offibox_text.png` — fallback logo texte

## Utilisation dans le code

Dans le code Dart, utilisez le chemin **relatif au projet** (sans `lib/`) :

```dart
Image.asset('assets/icons/nom_du_fichier.png')
```

## Déclaration dans pubspec.yaml

Le dossier est déjà déclaré :

```yaml
flutter:
  assets:
    - assets/icons/
```

Les fichiers avec un espace dans le nom (ex. `logo text.png`) sont aussi listés explicitement si besoin. Après avoir ajouté une nouvelle icône dans `assets/icons/`, un `flutter pub get` suffit ; pas besoin de l’ajouter à la liste si `assets/icons/` est déjà inclus.

## Bonnes pratiques

- Préférer des noms sans espaces (ex. `logo_text.png`) pour éviter les soucis sur certains systèmes.
- PNG pour les icônes avec transparence, SVG pour le vectoriel (avec le package `flutter_svg`).
