# Embarquer l’app Offibox sur la page Wix /connected

La page **https://www.offibox.fr/connected** affiche l’application Offibox (version web) **uniquement pour les clients connectés**. Après connexion (email/mot de passe ou Google), ils sont redirigés vers cette page où l’app est chargée dans une iframe.

## Intégration rapide dans Wix

1. **Ouvrir l’éditeur Wix** de ton site (offibox.fr).
2. **Aller sur la page « connected »** (celle dont l’URL est `https://www.offibox.fr/connected`).
3. **Supprimer** tout contenu existant dans la zone principale si tu veux que la page ne montre que l’app (ou garder en-tête / footer).
4. **Ajouter un embed :**
   - Menu **Ajouter** (+) → **Intégrer** → **Code personnalisé** (ou **HTML iframe**).
   - Choisir **Code personnalisé**.
5. **Coller le code ci‑dessous** (une seule ligne possible selon Wix, sinon le bloc complet) :

```html
<iframe 
  src="https://alexandreperrault.github.io/offibox-web/website/app-embed.html" 
  width="100%" 
  height="800" 
  style="border: none; min-height: 800px; display: block;"
  title="Application Offibox">
</iframe>
```

6. **Ajuster la hauteur** si besoin : tu peux mettre `height="100%"` et `min-height: 90vh` pour que l’iframe prenne presque toute la hauteur de l’écran (selon ce que Wix autorise).
7. **Enregistrer** et **publier** le site.

## Comportement

- **Non connecté :** l’iframe charge `app-embed.html`, qui vérifie Firebase Auth. S’il n’y a pas de session, l’utilisateur est redirigé vers la page de connexion (login-wix.html). Tu peux héberger la connexion sur le même domaine ou sur GitHub Pages (offibox-web).
- **Connecté :** l’app Flutter (version web) s’affiche dans l’iframe. L’utilisateur reste connecté selon l’option **« Rester connecté »** (voir ci‑dessous).

## Rester connecté

Sur la page de connexion (login-wix.html), la case **« Rester connecté »** est proposée :

- **Cochée (défaut) :** la session Firebase est persistée en **local** (localStorage). Le client reste connecté après fermeture du navigateur.
- **Décochée :** la session est en **session** (sessionStorage). Le client est déconnecté à la fermeture de l’onglet ou du navigateur.

Aucune action supplémentaire côté Wix : tout est géré dans les pages hébergées (login + app-embed).

## URLs à utiliser

| Rôle | URL |
|------|-----|
| **Page Wix « app » (à embed)** | https://www.offibox.fr/connected |
| **Iframe (app + vérif. connexion)** | https://alexandreperrault.github.io/offibox-web/website/app-embed.html |
| **Page de connexion** | À héberger (ex. offibox.fr ou offibox-web) et à mettre dans **Authorized domains** Firebase + Google |

Après connexion, la redirection depuis la page de connexion pointe vers `https://www.offibox.fr/connected` pour que le client arrive directement sur la page Wix qui contient l’iframe.
