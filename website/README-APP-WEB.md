# Afficher la barre Offibox (app Flutter) sur le site

L’app web Flutter (barre + recherche + données) est générée par :

```bash
flutter build web -t lib/main_web.dart --no-wasm-dry-run
```

- **`--no-wasm-dry-run`** : supprime les avertissements « dart:ffi / dart:html unsupported » (future compilation WebAssembly). Ils n’impactent pas le build web actuel (JavaScript).
- Si tu vois un avertissement sur les polices (MaterialIcons / CupertinoIcons), tu peux ajouter **`--no-tree-shake-icons`** pour inclure toutes les icônes (bundle un peu plus lourd).

Le résultat est dans `build/web`. Pour que la **barre** apparaisse sur ton site, tu as deux possibilités.

---

## 1. Lien vers l’app (page pleine)

- Déploie le contenu de **`build/web`** sur un chemin dédié, par exemple :
  - `https://www.offibox.fr/app/`  
  - ou un sous-domaine : `https://app.offibox.fr/`
- Sur le site (menu, bouton, page projet), mets un lien vers cette URL :
  - ex. *« Ouvrir Offibox »* → `https://www.offibox.fr/app/`

L’utilisateur ouvre alors l’app en pleine page (barre + recherche + données).

---

## 2. Intégrer la barre dans une page du site (iframe)

- Même déploiement que ci‑dessus (contenu de `build/web` servi à `/app/` ou sur `app.offibox.fr`).
- Sur une page HTML de ton site, ajoute une iframe qui pointe vers cette URL :

```html
<iframe
  src="https://www.offibox.fr/app/"
  title="Offibox – Barre d'outils"
  style="width:100%; height:600px; border:none;">
</iframe>
```

Tu peux t’inspirer de **`app-embed-example.html`** dans ce dossier : il contient un en-tête de site + l’iframe, donc la barre s’affiche **à l’intérieur** de la page.

- En local : si tu sers le site et l’app sur des ports différents, adapte `src` (ex. `http://localhost:PORT_APP/`).
- En production : mets l’URL réelle de l’app (ex. `https://www.offibox.fr/app/`).

---

## Résumé

| Objectif              | Action |
|-----------------------|--------|
| Déployer l’app        | Copier `build/web` vers `/app/` (ou sous-domaine). |
| Lien « Ouvrir l’app » | Lien href vers l’URL de l’app. |
| Barre dans la page    | Une page avec une iframe dont `src` = URL de l’app. |

Les données viennent toujours d’offiboxdata (comme en desktop) ; si le dépôt est privé, rebuild avec :

`--dart-define=OFFIBOXDATA_GITHUB_TOKEN=xxx`
