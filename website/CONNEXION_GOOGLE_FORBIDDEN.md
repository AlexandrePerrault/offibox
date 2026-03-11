# Erreur 403 à la connexion Google (emailAddresses / APIs)

Si la requête vers `content-people.googleapis.com` ou une API Google renvoie **403**, c’est en général un problème de **scopes**, **consentement** ou **APIs désactivées** dans le projet Google Cloud (celui lié à Firebase).

## À faire dans Google Cloud Console

1. **Même projet que Firebase**  
   Aller sur [Google Cloud Console](https://console.cloud.google.com/) et sélectionner le projet **offibox-prod** (ou celui de votre Firebase).

2. **OAuth consent screen (écran de consentement)**  
   - **APIs & Services** → **OAuth consent screen**  
   - Vérifier / ajouter les scopes nécessaires, par exemple :  
     - `email`  
     - `profile`  
     - `openid`  
   - Si vous utilisez l’agenda : `https://www.googleapis.com/auth/calendar.readonly`  
   - Enregistrer.

3. **Credentials → client OAuth 2.0 Web**  
   - **APIs & Services** → **Credentials**  
   - Ouvrir le client **Web application** (souvent « Web client (auto created by Google Service) »).  
   - **Authorized JavaScript origins** : ajouter **exactement** les origines d’où vous testez ou déployez, par exemple :  
     - `https://www.offibox.fr`  
     - `https://offibox.fr`  
     - `https://alexandreperrault.github.io` (GitHub Pages)  
     - En test local : `http://localhost:PORT`  
   - **Authorized redirect URIs** : doit contenir **exactement** (obligatoire pour Firebase Auth) :  
     - `https://offibox-prod.firebaseapp.com/__/auth/handler`  
     - Ne pas supprimer cette URI ; sans elle, la connexion Google après redirection échoue.  
   - Enregistrer et attendre 1–2 minutes.

4. **APIs à activer (APIs & Services → Library)**  
   Offibox utilise les scopes `email`, `profile` et `calendar.readonly`. Les APIs suivantes doivent être **activées** dans le projet :

   | API | Pourquoi |
   |-----|----------|
   | **People API** (Google People API) | Requise lorsque l’app demande le scope `email` / `profile` : Google peut appeler l’API People pour récupérer l’email (ressource `emailAddresses`). Sans elle → 403 sur `content-people.googleapis.com`. |
   | **Google Calendar API** | Requise pour l’agenda intégré dans l’app (scope `https://www.googleapis.com/auth/calendar.readonly`). Sans elle → 403 sur `calendar/v3`. |

   **Comment activer** :  
   - **APIs & Services** → **Library** (Bibliothèque).  
   - Rechercher « **People API** » → cliquer → **Enable** (Activer).  
   - Rechercher « **Google Calendar API** » → cliquer → **Enable** (Activer).  

   La simple connexion Google (Firebase Auth) ne nécessite pas d’autre API à activer ; en revanche, si vous voyez un 403 sur une URL contenant `people` ou `emailAddresses`, activer **People API** règle en général le problème.

Après modification, attendre quelques minutes puis réessayer la connexion Google.
