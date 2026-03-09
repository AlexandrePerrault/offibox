Editez ce fichier avant chaque build avec -PushToGitHub true.
Son contenu sera affiché dans Historique des versions (Release GitHub).

---

**Dernières modifications :**

- **Annuaire professionnels de santé** : clic sur l’adresse MSSanté ouvre Mailiz (connexion sécurisée) dans la page sous la barre, copie l’adresse du professionnel et affiche un message avec bouton « Fermer » pour envoyer un message sécurisé.
- **Annuaire** : pour une même personne, la profession « Médecin généraliste » est affichée en priorité avant « Ostéopathe » (ou autre).
- **Installateur Windows (MSI)** : correction des variables WiX (bannières) et des doublons dans le dialogue Options.
- **Export outils métier (Apps Script)** : 6 feuilles exportées vers GitHub avec retry en cas de conflit 409.
- **GitHub Pages** : workflow dédié avec concurrency pour limiter les annulations de déploiement.
