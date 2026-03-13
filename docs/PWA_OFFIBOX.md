# Offibox en PWA (Progressive Web App)

Ce document décrit comment déployer et utiliser Offibox comme PWA complète, et comment ajouter un raccourci sur iPhone/iPad.

---

## 1. Marche à suivre pour une PWA complète

### 1.1 Build web

À la racine du projet :

```bash
flutter build web
```

Les fichiers générés sont dans `build/web/`.

### 1.2 Fichiers essentiels PWA

- **`web/index.html`**  
  Meta tags pour iOS (apple-mobile-web-app-*), viewport, theme-color, lien vers le manifest et les icônes.

- **`web/manifest.json`**  
  Nom, short_name, start_url, scope, display (standalone), couleurs, icônes 192/512 et maskable.

- **Icônes**  
  Le build Flutter attend dans `web/icons/` (ou les génère selon la config) :
  - `Icon-192.png`, `Icon-512.png`
  - `Icon-maskable-192.png`, `Icon-maskable-512.png` (recommandé pour l’écran d’accueil)

Si les icônes manquent, créez le dossier `web/icons/` et ajoutez au minimum une image 192×192 (et 512×512 si possible). Vous pouvez partir du logo Offibox.

### 1.3 Hébergement

- Servir le contenu de **`build/web/`** en HTTPS (obligatoire pour une PWA).
- L’URL de base doit correspondre au `base href` utilisé au build (par défaut `/`).
- Exemples : Firebase Hosting, Netlify, Vercel, ou votre propre serveur avec SSL.

### 1.4 Service Worker

Flutter génère automatiquement `flutter_service_worker.js` dans `build/web/`. Aucune configuration supplémentaire n’est nécessaire pour le cache de base.

### 1.5 Vérifications

- Ouvrir le site en HTTPS dans Chrome (Desktop ou Android).
- DevTools → Application → Manifest : vérifier que le manifest est chargé et que les icônes s’affichent.
- Sur Android : l’option « Ajouter à l’écran d’accueil » ou « Installer l’application » doit apparaître (selon le navigateur).

---

## 2. Raccourci sur iOS (iPhone / iPad)

Sur iOS, il n’y a pas de « installation » PWA comme sur Android ; on ajoute un **raccourci sur l’écran d’accueil** qui ouvre la page en mode plein écran (sans barre d’adresse Safari).

### Étapes

1. Ouvrir l’**URL d’Offibox** (ex. `https://votre-domaine.fr`) dans **Safari** (obligatoire : pas Chrome ni Firefox sur iOS pour ce geste).
2. Appuyer sur l’icône **Partager** (carré avec une flèche vers le haut), en bas ou en haut de l’écran.
3. Dans le menu, faire défiler et choisir **« Sur l’écran d’accueil »** (ou « Add to Home Screen » en anglais).
4. Ajuster le nom si besoin (ex. « Offibox ») puis appuyer sur **« Ajouter »**.

Un raccourci « Offibox » apparaît sur l’écran d’accueil. En le touchant, l’app s’ouvre en plein écran (PWA), avec la barre de statut style défini dans `index.html` (`apple-mobile-web-app-status-bar-style`).

### Rappel

- Utiliser **Safari** pour ajouter au bureau ; les autres navigateurs sur iOS ne proposent pas correctement « Sur l’écran d’accueil » pour une PWA.
- Après mise à jour du site, recharger la page depuis le raccourci (tirer pour actualiser) pour bénéficier du nouveau cache du service worker.

---

## 3. Modifications apportées pour la « version PWA complète »

- **Badge téléchargement supprimé**  
  Après une première connexion réussie, le bouton / badge « Télécharger — Windows » ou « Ouvrir la page de téléchargement » a été retiré. Le message affiché est uniquement : « Vous pouvez continuer à utiliser Offibox sur cette page. » (adapté à un usage PWA).
- **Manifest**  
  Ajout de `scope` pour une PWA bien délimitée.
- **Documentation**  
  Ce fichier décrit la marche à suivre PWA et le raccourci iOS.

Pour toute question sur le déploiement ou les icônes, se référer au projet Flutter et au dossier `web/`.
