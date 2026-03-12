# Démonstrations (website/demo)

Ce dossier regroupe les démos HTML et les images associées (JPG, etc.).

## Contenu actuel

- **demo-app-animation.html** — Animation fidèle de l’app (recherche Imbruvica, TROD angine, badges, clics).
- **demo-fiche-voc.jpg** — Capture pour le panneau PDF (fiche VOC Imbruvica).
- **TROD_ANGINE_IMAGES_README.md** — Liste des 6 JPG à ajouter pour la séquence TROD angine (compte-rendu, logigramme AMELI, HAS, Bons prise en charge).

Les images Imbruvica (RCP, MEDDISPAR, fiches patient/pro) sont dans `website/assets/images/` et référencées en relatif depuis ce dossier.

## Ajouter une nouvelle démo

1. Créer un nouveau fichier HTML (ou sous-dossier) dans `website/demo/`.
2. Utiliser des chemins relatifs : `../assets/` pour les assets partagés (website).
3. Mettre les JPG ou assets spécifiques à la démo dans ce dossier.
4. Mettre à jour les URLs dans `docs/URLS_OFFIBOX_WEB_ET_PC.html` et `installer/push_build_web_pc_and_urls.ps1` si besoin.

## Anciens emplacements

Les anciens fichiers démo ont été déplacés ici depuis `website/pages/html/`. Tu peux supprimer manuellement dans `website/pages/html/` s’ils y sont encore : `demo-app-animation.html`, `demo-fiche-voc.jpg`, `TROD_ANGINE_IMAGES_README.md`.
