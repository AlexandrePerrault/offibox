# Logos des sources — chemins dans `assets/icons`

Utiliser dans le code Flutter : **`assets/icons/nom_fichier.png`** ou **`.svg`**

| Source | Chemin (à utiliser dans le projet) | Présent ? |
|--------|-----------------------------------|-----------|
| Base de données publiques sur le médicament | `assets/icons/base-donnees-publique_medicaments_gouv_fr.png` | À ajouter |
| DGS urgent | `assets/icons/solidarites-sante_gouv_fr.png` | À ajouter |
| pharmaradio | `assets/icons/pharmaradio_fr.png` | À ajouter |
| le moniteur des pharmacies | `assets/icons/lemoniteurdespharmacies_fr.png` | À ajouter |
| le quotidien du pharmacien | `assets/icons/lequotidiendopharmacien_fr.png` | À ajouter |
| ordre national des pharmaciens | `assets/icons/ordre_pharmaciens_fr.png` | À ajouter |
| vidal | `assets/icons/vidal_fr.png` | À ajouter |
| thériaque | `assets/icons/theriaque_org.png` | À ajouter |
| vigirupture | `assets/icons/vigirupture_fr.png` | À ajouter |
| posos | `assets/icons/posos_fr.png` | À ajouter |
| Pharmalia (PHOENIX OCP) | `assets/icons/phoenixgroup_eu.png` | À ajouter |
| Lohmann et Rauscher | `assets/icons/lohmann-rauscher_com.png` | À ajouter |
| Coloplast (pansements) | `assets/icons/coloplast_com.png` | Oui |
| Coloplast (uro et colostomie) | `assets/icons/coloplast_com.png` | Oui |
| convatec | `assets/icons/convatec_com.png` | À ajouter |
| Hartmann | `assets/icons/hartmann.svg` | Oui |
| Urgo Médical | `assets/icons/urgo_com.png` | Oui |
| Smith & Nephew | `assets/icons/smith-nephew_com.png` | À ajouter |
| Meddispar | `assets/icons/meddispar_fr.png` | À ajouter |
| Mailiz | `assets/icons/mailiz_fr.png` | À ajouter |
| doctolib Pro | `assets/icons/doctolib_fr.png` | À ajouter |
| annuaire santé | `assets/icons/sante_fr.png` | À ajouter |
| recommandations sanitaires aux voyageurs | `assets/icons/diplomatie_gouv_fr.png` | À ajouter |
| Thuasne (compression / orthopédie) | `assets/icons/thuasne_com.png` | À ajouter |
| Sigvaris | `assets/icons/sigvaris_com.png` | À ajouter |
| Innothera-Gibaud | `assets/icons/innothera_fr.png` | À ajouter |
| Orliman | `assets/icons/orliman_com.png` | À ajouter |
| Radiante | `assets/icons/radiante_fr.png` | À ajouter |
| Madouest | `assets/icons/madouest_fr.png` | À ajouter |
| Cerp équipement | `assets/icons/cerp_fr.png` | À ajouter |

---

## Déjà présents dans `assets/icons`

- **assets/icons/coloplast_com.png** — Coloplast (pansements, uro, colostomie)
- **assets/icons/hartmann.svg** — Hartmann
- **assets/icons/urgo_com.png** — Urgo Médical

## À faire

Les autres logos ne sont pas dans l’API Brandfetch (sites .gouv.fr, .fr, etc.). Il faut les récupérer manuellement (site officiel, page « presse » ou « médiathèque ») et les enregistrer dans `assets/icons` avec le **nom de fichier** indiqué dans le tableau (ex. `vidal_fr.png`, `doctolib_fr.png`). Penser à déclarer les nouveaux fichiers dans `pubspec.yaml` sous `flutter: assets:` si besoin.

## Script

Le script `scripts/fetch_source_logos.py` tente de télécharger ces logos via Brandfetch. Pour relancer :

```bash
cd C:\Users\perra\Documents\projets_flutter\offibox
python scripts/fetch_source_logos.py
```
