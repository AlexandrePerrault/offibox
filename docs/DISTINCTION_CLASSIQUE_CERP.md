# Différencier Offibox classique et Offibox-CERP

## Ce que tu as aujourd’hui

- **Un seul dossier projet** : `offibox` (à la racine de ton repo).
- **Un seul code** : il produit soit l’app **Offibox classique**, soit **Offibox-CERP** selon les options de build (flavors / dart-define).
- **Un dossier de livrables CERP** : `offibox CERP` (ex. `offibox CERP/SANTRALIA` pour les PDF par labo).

Donc : **Offibox classique** = le projet dans le dossier `offibox` (build par défaut). **Offibox-CERP** = le même projet, build avec les options CERP.

## Oui, tu peux les différencier clairement

### Option 1 : Garder un seul dossier, bien nommer (recommandé)

- **Dossier actuel** : tu le considères comme le projet **Offibox classique** (c’est déjà le cas dans le README).
- **Build classique** : `flutter build windows` ou `flutter build apk --flavor offibox` → installateur / APK « Offibox ».
- **Build CERP** : `flutter build windows --dart-define=APP_NAME=Offibox-CERP ...` → installateur / APK « Offibox-CERP ».
- **Contenus CERP** : tout ce qui est spécifique CERP (catalogues, etc.) reste dans **`offibox CERP`** à la racine du projet.

Ainsi, dans l’explorateur de fichiers :
- le **dossier `offibox`** = projet Offibox **classique** (et source commune pour CERP) ;
- le **dossier `offibox CERP`** = uniquement livrables / contenus CERP (pas le code source).

### Option 2 : Deux dossiers distincts sur ton PC

Pour avoir **deux dossiers** bien séparés (classique vs CERP) :

1. **Renommer le dossier actuel** en **`offibox_classique`**  
   - Par exemple : `Documents\projets_flutter\offibox` → `Documents\projets_flutter\offibox_classique`.
2. **Créer un second dossier** **`offibox_cerp`** :
   - soit en **copiant** tout `offibox_classique` dans `offibox_cerp` (tu auras deux projets, deux builds, maintenance en double) ;
   - soit en gardant **un seul repo** dans `offibox_classique` et en utilisant **`offibox_cerp`** seulement pour les **sorties** CERP (builds, SANTRALIA, etc.) : tu builds depuis `offibox_classique` avec les dart-define CERP et tu copies l’exe/installateur dans `offibox_cerp`.

Résumé :
- **`offibox_classique`** = dossier du projet (Offibox classique + source commune).
- **`offibox_cerp`** = soit copie du projet (deux codebases), soit simple dossier de livrables CERP (exe, catalogues, etc.).

### Option 3 : Un repo, deux dossiers de sortie dans le projet

Sans renommer le dossier racine, tu peux organiser les **builds** pour qu’ils aillent dans des sous-dossiers distincts :

- **Sortie classique** : ex. `build/offibox_classique/` ou `dist/offibox/`.
- **Sortie CERP** : ex. `build/offibox_cerp/` ou `offibox CERP/` (déjà en place pour SANTRALIA).

Comme ça, dans un seul dossier `offibox`, tu vois clairement :
- le code (Offibox classique par défaut),
- `offibox CERP` = tout ce qui est CERP (catalogues + éventuellement exe/installateur CERP si tu les y copies).

## En résumé

- **Différencier** Offibox classique et « dossier offibox original » est possible.
- Le **dossier offibox (original)** peut être considéré comme le projet **Offibox classique** ; le **dossier `offibox CERP`** contient ce qui est spécifique CERP.
- Si tu veux deux dossiers au même niveau sur ton PC : renomme `offibox` en **`offibox_classique`** et utilise **`offibox_cerp`** pour une copie du projet ou uniquement les livrables CERP.
