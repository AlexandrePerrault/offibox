# Configuration

## Annuaire PS (API FHIR)

Pour activer la recherche dans l’annuaire des professionnels de santé (RPPS, nom, structure), une clé API ANS est requise :

- **À la compilation** : `--dart-define=ESANTE_API_KEY=votre_cle`
- Obtenir la clé : [portal.api.esante.gouv.fr](https://portal.api.esante.gouv.fr) → Applications → souscrire à « API Annuaire Santé en libre accès ».
- **Documentation API** (guide complet, cas d’usage, démonstrateur) : [ansforge.github.io/annuaire-sante-fhir-documentation](https://ansforge.github.io/annuaire-sante-fhir-documentation/)

Sans clé, la recherche annuaire utilise le CSV data.gouv.fr (pipeline offiboxdata).

**Cache backend** : la Cloud Function `searchAnnuairePS` met en cache les résultats FHIR dans Firestore (24 h). L’app appelle cette fonction en priorité pour réduire la latence. Déployer : `firebase deploy --only functions`.

---

## OAuth Google Calendar

Pour activer l'agenda Google dans l'app Offibox (Windows / Desktop) :

## 1. Créer les identifiants OAuth (Google Cloud Console)

- Projet **offibox-prod** (ou le vôtre)  
- **APIs & Services** > **Credentials** > **Create Credentials** > **OAuth client ID**  
- Type : **Desktop app**  
- Nom : par ex. "Offibox Windows"  
- Copiez le **Client ID** et le **Client Secret**

## 2. Configurer l’app

Placez les identifiants dans l’un des emplacements suivants :

- **Fichier** : `google_oauth_credentials.json` dans le dossier de données de l’app (AppData / Application Support selon l’OS), avec le contenu :
  ```json
  {
    "client_id": "XXX.apps.googleusercontent.com",
    "client_secret": "XXX"
  }
  ```
- Ou **variables d’environnement** au build :  
  `GOOGLE_OAUTH_CLIENT_ID` et `GOOGLE_OAUTH_CLIENT_SECRET`

*(En dev, un fichier `config/oauth_credentials.json` avec les mêmes clés peut être utilisé selon la config du projet.)*

## 3. Connecter l’agenda dans l’app

1. Ouvrez le **menu hamburger** (icône ☰ à droite de la barre).  
2. En bas du menu, cliquez sur **« Connecter l'agenda Google »**.  
3. Une page Google s’ouvre dans le navigateur : connectez-vous avec le compte souhaité (ex. offibox@gmail.com) et **autorisez l’accès au calendrier**.  
4. Une fois l’autorisation donnée, l’app affiche « Agenda Google connecté » et l’entrée du menu devient **« Google Agenda »** (ouverture de calendar.google.com).  
5. Le **prochain rendez-vous** du calendrier apparaît dans la barre d’infos (ticker) sous la barre de recherche.

*(Sur Windows/Linux l’app utilise OAuth Desktop ; sur d’autres plateformes la connexion Google peut être gérée différemment.)*
