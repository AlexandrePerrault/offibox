# URLs Offibox — Web (offibox-web) et version PC

**offibox-web** = version **web embarquée** de l’app pour les clients qui veulent utiliser Offibox en navigateur (sans installer la version PC). Elle doit rester **publique** pour que GitHub Pages la serve à tout le monde ; en privé, seuls les comptes avec accès au dépôt pourraient y accéder.

## Ce que le push vers offibox-web contient

Quand tu lances `.\installer\deploy_web_offibox_web.ps1 -PushTo "C:\...\offibox-web" -DoGitPush`, le dépôt **offibox-web** reçoit :

- **App Flutter web** (build avec `base-href /offibox-web/`)
- **Dossier `website/`** (copie de `website/` du projet)
- **Dossier `html/`** (copie de `website/pages/html/`)

La **version PC (.exe)** n’est **pas** dans offibox-web. Elle est soit sur GitHub Releases (dépôt offibox), soit sur ton site (offibox.fr/download).

---

## URLs — Dépôt offibox-web (GitHub Pages)

Base : **https://alexandreperrault.github.io/offibox-web/**

| Type | URL |
|------|-----|
| **App web (accueil)** | https://alexandreperrault.github.io/offibox-web/ |
| **Dossier website** | https://alexandreperrault.github.io/offibox-web/website/ |
| **Dossier html** | https://alexandreperrault.github.io/offibox-web/html/ |

### Exemples de pages (website/)

- https://alexandreperrault.github.io/offibox-web/website/telechargement.html  
- https://alexandreperrault.github.io/offibox-web/website/telechargement-pc.html  
- https://alexandreperrault.github.io/offibox-web/website/inscription.html  
- https://alexandreperrault.github.io/offibox-web/website/validation.html  
- https://alexandreperrault.github.io/offibox-web/website/login-wix.html  
- https://alexandreperrault.github.io/offibox-web/website/app.html  
- https://alexandreperrault.github.io/offibox-web/website/demo/demo-app-animation.html  
- https://alexandreperrault.github.io/offibox-web/website/plateformes.html  
- https://alexandreperrault.github.io/offibox-web/website/projet-offibox.html  
- https://alexandreperrault.github.io/offibox-web/website/bandeau-offibox.html  
- (+ autres .html dans website/, website/mobile/, website/archive/)

### Exemples de pages (html/)

- https://alexandreperrault.github.io/offibox-web/html/login-wix.html  
- https://alexandreperrault.github.io/offibox-web/html/inscription.html  
- https://alexandreperrault.github.io/offibox-web/html/validation.html  
- https://alexandreperrault.github.io/offibox-web/html/telechargement.html  
- https://alexandreperrault.github.io/offibox-web/html/telechargement-pc.html  
- https://alexandreperrault.github.io/offibox-web/website/demo/demo-app-animation.html  
- https://alexandreperrault.github.io/offibox-web/html/app.html  
- https://alexandreperrault.github.io/offibox-web/html/plateformes.html  
- https://alexandreperrault.github.io/offibox-web/html/conditions-utilisation.html  
- https://alexandreperrault.github.io/offibox-web/html/definir-mot-de-passe.html  

---

## Version PC (installateur Windows)

Elle n’est **pas** poussée vers offibox-web. Elle est :

| Source | URL |
|--------|-----|
| **Ton site (recommandé si dépôt privé)** | https://offibox.fr/download (page) et `latest.json` + `Offibox-Setup-X.Y.Z.exe` |
| **GitHub Releases (dépôt offibox, si public)** | https://github.com/AlexandrePerrault/offibox/releases/latest |

---

## Récap

- **Push offibox-web** = app web + pages `website/` + pages `html/` → visibles sur `https://alexandreperrault.github.io/offibox-web/`.
- **Version PC** = à déposer toi-même sur offibox.fr/download (et mettre à jour `latest.json`) ou à publier en release sur le dépôt offibox.
