# Cahier de liaison partagé

Le cahier de liaison est un fil de messages **partagé en temps réel** entre tous les postes (web ou desktop) d’**une même officine**. Il repose sur Firestore : pas besoin de Google Docs ni d’autre outil externe.

## Fonctionnement

- **Regroupement** : tous les utilisateurs dont le **nom de pharmacie** (`pharmacyName` dans le profil) est identique voient le même cahier. Le nom est normalisé (minuscules, sans accents, espaces → tirets) pour former un `groupId`.
- **Temps réel** : chaque poste connecté reçoit les nouveaux messages dès qu’un collègue en ajoute un (écoute Firestore).
- **Sécurité** : les règles Firestore n’autorisent la lecture/écriture que si le `pharmacyNameNormalized` de l’utilisateur correspond au groupe du cahier.

## Côté utilisateur

1. S’assurer que le **nom de la pharmacie** est renseigné dans le profil (inscription / première connexion).
2. Depuis l’écran connecté (web ou desktop), cliquer sur **« Cahier de liaison (partagé entre les postes) »**.
3. Lire les messages et en ajouter : ils sont visibles par toute l’équipe sur tous les postes.

Si le nom de pharmacie n’est pas renseigné, un message invite à le compléter dans le profil pour activer le partage.

## Technique

- **Service** : `lib/services/cahier_liaison_service.dart` (groupId, stream des entrées, ajout).
- **UI** : `lib/ui/screens/cahier_liaison_screen.dart` (liste + formulaire d’envoi).
- **Firestore** :
  - Structure : `cahier_liaison/{groupId}/entries/{entryId}`.
  - Chaque entrée : `authorUid`, `authorName`, `text`, `createdAt`.
- **Règles** : dans `firestore.rules`, bloc `cahier_liaison/{groupId}/entries/{entryId}` (lecture si même `pharmacyNameNormalized`, création avec `authorUid == auth.uid`, modification/suppression par l’auteur).

Après modification des règles, les déployer avec :

```bash
firebase deploy --only firestore:rules
```
