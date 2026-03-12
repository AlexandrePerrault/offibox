# Version Linux – Faisabilité

## En bref

**Oui, une version Linux est envisageable.** Le projet contient déjà le runner Flutter pour Linux (`linux/`) et plusieurs chemins de code gèrent déjà le cas « non-Windows » (splash, panneaux WebView). Avec quelques adaptations, l’application peut tourner sur Linux.

---

## Ce qui est déjà en place

- **Runner Linux** : le dossier `linux/` (CMake, `main.cc`, `my_application.cc`) est présent ; `flutter build linux` est utilisable.
- **Splash** : `windows_preload_wrapper` affiche le splash uniquement sur Windows ; sur Linux, l’app affiche directement le contenu (pas de blocage).
- **Panneaux WebView (PDF, web, Word, etc.)** : sous non-Windows, ils affichent déjà un message du type « Aperçu web disponible sous Windows » au lieu de planter. On peut ensuite proposer « Ouvrir dans le navigateur » (déjà possible avec `url_launcher`).
- **Fenêtre** : `bitsdojo_window` a une variante Linux ; le reste de l’UI Flutter est multiplateforme.

---

## Adaptations nécessaires

### 1. Identifiant appareil (device ID)

- **Problème** : `getDeviceId()` lançait `UnsupportedError` en dehors de Windows.
- **Solution** : utilisation de `device_info_plus` pour Linux : `LinuxDeviceInfo.machineId` fournit un identifiant machine stable.
- **Statut** : corrigé dans `lib/utils/device_id.dart` (support Linux ajouté).

### 2. WebView intégrée

- **Actuel** : `webview_windows` est Windows-only. Sur Linux, les panneaux sous la barre (sites, PDF via WebView, etc.) affichent un message d’indisponibilité.
- **Option** : garder ce comportement sur Linux, ou proposer un bouton « Ouvrir dans le navigateur » qui appelle `url_launcher` pour ouvrir l’URL dans le navigateur par défaut. Aucun plugin additionnel obligatoire.

### 3. Mises à jour automatiques

- **Actuel** : logique orientée Windows (installer, dernières versions, etc.).
- **Linux** : on peut ne pas gérer les mises à jour auto (l’utilisateur met à jour via le gestionnaire de paquets ou en retéléchargeant). Optionnel pour un premier portage.

### 4. Démarrage automatique (autostart)

- **Actuel** : `win32` / `win32_registry` pour le démarrage avec Windows.
- **Linux** : possible plus tard via fichier `.desktop` dans `~/.config/autostart/` (pas nécessaire pour une première version).

### 5. Dépendances optionnelles Windows

- **win32 / win32_registry** : utilisés pour l’autostart et éventuellement d’autres réglages Windows. Ils ne sont chargés que sur Windows ; pas d’impact direct sur le build Linux.

---

## Build et exécution

```bash
flutter build linux
# Binaire dans build/linux/x64/release/bundle/
```

Pour tester sans packager :

```bash
flutter run -d linux
```

---

## Résumé

| Élément              | Windows | Linux (après adaptations) |
|----------------------|--------|----------------------------|
| Lancement            | OK     | OK (avec `getDeviceId()` Linux) |
| Barre de recherche   | OK     | OK                         |
| Panneaux PDF/Web/…   | WebView intégrée | Message + possibilité « Ouvrir dans le navigateur » |
| Mise à jour auto     | OK     | Optionnel (non implémenté) |
| Démarrage auto       | OK     | Optionnel (non implémenté) |

Une version Linux utilisable au quotidien est envisageable en gardant les limitations ci-dessus (pas de WebView intégrée sous la barre, pas de mise à jour auto ni autostart par défaut). Pour aller plus loin (paquet .deb, mise à jour, autostart), il faudra ajouter du travail spécifique Linux.
