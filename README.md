# offibox

**Offibox classique** : ce dépôt (dossier `offibox`) est le projet de l’application **Offibox** (version classique).  
La variante **Offibox-CERP** est produite à partir de ce même code via les [flavors](docs/OFFIBOX_CERP_MARCHE_A_SUIVRE.md) ; les livrables et contenus spécifiques CERP (ex. catalogues par labo) sont rangés dans le dossier **`offibox CERP`** à la racine du projet (ex. `offibox CERP/SANTRALIA`).

Pour distinguer clairement sur ton PC le classique du CERP, tu peux par exemple :
- garder ce dossier tel quel pour le **classique** (build par défaut) ;
- ou renommer ce dossier en **`offibox_classique`** et avoir à côté un dossier **`offibox_cerp`** (copie du dépôt ou sorties CERP).

## Securite : cle API Google / Firebase

Le fichier `android/app/google-services.json` (cles Firebase) **ne doit pas etre committe**. Il est dans `.gitignore`. Si une alerte Google signale une cle exposee sur GitHub :

1. **Immediat** : [Google Cloud Console](https://console.cloud.google.com/) → projet offibox-prod → APIs et services → Identifiants → revoquer ou supprimer la cle concernee, puis en creer une nouvelle. Telecharger le nouveau `google-services.json` depuis Firebase et remplacer le fichier local.
2. Ne plus jamais pousser `google-services.json`. Utiliser `android/app/google-services.json.example` comme modele (sans vraie cle).
3. (Optionnel) Retirer le fichier de l’historique Git avec `git filter-repo` ou BFG puis `git push --force`.

## PDF (pdfrx)

Le visualiseur de catalogues PDF utilise **pdfrx**. Sur **Windows**, le mode Développeur peut être requis pour que le build réussisse (pdfrx utilise des symlinks). Activer : Paramètres → Confidentialité et sécurité → Pour les développeurs → **Mode développeur**.

Si pdfrx ne fonctionne pas (ex. build ou runtime), alternatives possibles : Syncfusion PDF Viewer v26+, ou `native_pdf_view` / `printing`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
