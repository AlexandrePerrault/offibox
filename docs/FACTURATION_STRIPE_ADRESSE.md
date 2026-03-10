# Facturation clients : adresse et Stripe

## 1. Connexion Google : qu’est-ce qu’on récupère ?

Avec **Google Sign-In** (Firebase Auth), vous obtenez uniquement :

- **Email**
- **Nom** (displayName, souvent prénom + nom)
- **Photo de profil** (optionnel)

**Google ne fournit pas l’adresse postale** dans le flux OAuth standard. Il existe un scope `https://www.googleapis.com/auth/user.addresses.read` mais il est restreint (vérification Google) et peu utilisé. Pour la facturation, il ne faut pas compter sur Google pour l’adresse.

---

## 2. Où récupérer l’adresse ?

Il faut **la collecter dans votre application** :

1. **À l’inscription**  
   Pour les inscriptions par email/mot de passe, vous avez déjà un formulaire avec **adresse + code postal + ville** (et autocomplete API Adresse). Il suffit d’enregistrer ces champs en base (Firestore ou votre backend) en plus de l’email / nom de la pharmacie.

2. **Après la première connexion Google**  
   Pour les utilisateurs qui se connectent **uniquement** avec Google, ils n’ont pas rempli d’adresse. Il faut donc :
   - soit les rediriger vers un écran **« Complétez votre profil »** (nom de la pharmacie, adresse, CP, ville, téléphone) après la 1ère connexion,
   - soit demander l’adresse au moment d’**activer l’abonnement / le paiement** (première fois qu’ils paient).

Recommandation : **profil / adresse de facturation** complété après la 1ère connexion Google, stocké en base (Firestore `users/{uid}` avec champs `address`, `postalCode`, `city`, `pharmacyName`, etc.). Ainsi vous avez toujours une adresse à envoyer à Stripe.

---

## 3. Stripe : rôle par rapport à l’adresse

**Stripe ne récupère pas l’adresse depuis Google.** Stripe sert à :

- **Enregistrer un client** : vous créez un **Stripe Customer** en lui envoyant **email + adresse de facturation** (que vous avez déjà en base).
- **Paiement / abonnement** : Stripe Checkout ou Payment Intents peuvent afficher un formulaire où l’utilisateur saisit ou modifie son adresse ; vous pouvez aussi **pré-remplir** l’adresse à partir de votre base.

En résumé :

- **Vous** : collectez et stockez l’adresse (formulaire + Firestore).
- **Stripe** : reçoit cette adresse quand vous créez un Customer ou une session Checkout (paramètres `customer_address` / `address` selon l’API).

La facturation pourra donc **se faire avec Stripe** en utilisant l’adresse que vous avez déjà en base (celle saisie à l’inscription ou dans « Complétez votre profil » après connexion Google).

---

## 4. Flux recommandé (résumé)

| Étape | Action |
|--------|--------|
| 1 | Utilisateur se connecte (Google ou email/mot de passe). |
| 2 | Si connexion **Google** et **pas d’adresse** en base → afficher « Complétez votre profil » (pharmacie, adresse, CP, ville) avec autocomplete API Adresse, puis sauvegarder dans Firestore `users/{uid}`. |
| 3 | Pour la facturation : au moment de créer un abonnement ou un paiement Stripe, **récupérer** depuis Firestore l’email et l’adresse (rue, CP, ville) du `users/{uid}`. |
| 4 | Créer un **Stripe Customer** (ou réutiliser l’existant) avec `email` + `address` puis créer un abonnement ou une session Checkout. Stripe utilisera cette adresse pour les factures. |

---

## 5. Côté code (à faire)

- **Firestore** : étendre le document `users/{uid}` avec par exemple `pharmacyName`, `address`, `postalCode`, `city`, `country` (et éventuellement `phone` pour Stripe).
- **Flutter / Web** : après connexion Google, si `users/{uid}` n’a pas `address` (ou `postalCode`), afficher un écran ou une modale « Complétez votre adresse de facturation » (formulaire avec autocomplete adresse française), puis `set` / `update` Firestore.
- **Backend (Cloud Functions ou autre)** : pour Stripe, à la création d’un Customer ou d’une Checkout Session, lire `users/{uid}` et passer `address: { line1, postal_code, city, country }` à l’API Stripe.

Si vous voulez, on peut détailler la structure Firestore exacte et un exemple d’appel Stripe (Node ou Dart) avec cette adresse.
