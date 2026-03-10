# Largeur des pages mobile Offibox

Pour éviter un rendu « trop large » sur mobile, toutes les pages de ce dossier doivent respecter :

- **Bloc de contenu principal** : `max-width: 360px` et `margin: 0 auto` pour centrer.
- **Marges latérales** : au moins `padding: 0 1.25rem` (ou 1rem minimum) sur le conteneur ou le body.
- **Texte** : sur les listes et titres, utiliser `word-wrap: break-word; overflow-wrap: break-word; word-break: break-word; hyphens: auto` pour éviter les coupures (ex. « officine », « essai gratuit »).

Exemple de wrapper page :
```css
.page-wrap { width: 100%; max-width: 360px; margin: 0 auto; min-width: 0; }
```
Et sur le body : `padding: 0.75rem 1.25rem …`

Référence visuelle : capture « correcte » avec bloc étroit centré et marges visibles à gauche et à droite.
