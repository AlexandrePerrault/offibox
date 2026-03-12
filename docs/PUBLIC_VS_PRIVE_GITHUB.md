# GitHub : quoi garder en public / en privé

## Résumé

| Dépôt | Visibilité recommandée | Raison |
|-------|-------------------------|--------|
| **offibox** (ce dépôt) | **Privé** | Code source, historique, scripts. Les clients ne vont pas sur GitHub pour télécharger le setup. |
| **offibox-web** | **Public** | Héberge la version web (GitHub Pages). Doit rester public pour que tout le monde puisse afficher l’app sans connexion. |

---

## Téléchargement du setup par les clients

L’app est déjà configurée pour le **mode dépôt privé** dans `lib/constants/app_update_config.dart` :

- **customLatestVersionUrl** = `https://offibox.fr/download/latest.json`
- Tant que cette URL est renseignée, l’app **n’utilise pas** l’API GitHub. Elle récupère la version et l’URL de téléchargement depuis ton site.

**Conséquences :**

1. Tu peux mettre le dépôt **offibox** en **privé**.
2. Les clients qui ont installé le setup continuent à recevoir les mises à jour : l’app appelle `https://offibox.fr/download/latest.json`, puis télécharge le .exe depuis l’URL indiquée dans ce JSON (en pratique `https://offibox.fr/download/Offibox-Setup-X.Y.Z.exe`).
3. Personne n’a besoin d’accéder aux « pages » GitHub (dépôt, code, Releases) pour installer ou mettre à jour l’app.

**À faire côté site :**

- Héberger sur **offibox.fr/download** :
  - **latest.json** (exemple : `{ "version": "1.1.26", "download_url": "https://offibox.fr/download/Offibox-Setup-1.1.26.exe" }`)
  - **Offibox-Setup-X.Y.Z.exe** (fichier produit par Inno Setup)
- Mettre à jour **latest.json** à chaque nouvelle version.

---

## Version web (offibox en ligne)

- La version web est déployée sur un **autre dépôt** : **offibox-web**, servi en GitHub Pages (`https://alexandreperrault.github.io/offibox-web/`).
- **Mettre offibox en privé ne bloque pas l’affichage de la version web** : c’est offibox-web qui sert la page, pas offibox.
- En revanche, **offibox-web doit rester public** : avec un dépôt privé, GitHub Pages ne permet pas (sans offre payante) d’avoir un site visible par tout le monde sans connexion.

---

## Récap

- **offibox** en **privé** → OK. Les clients téléchargent le setup et les mises à jour via **offibox.fr/download** (latest.json + .exe), pas via GitHub.
- **offibox-web** en **public** → nécessaire pour que la version web reste accessible à tous.
- Aucun accès aux pages du dépôt offibox n’est requis pour les utilisateurs finaux.
