# SHADE — Lot 0 technique

Socle React + TypeScript + Vite. Aucun module métier ni raccordement backend.

## Exécution

Node.js 22.12 minimum (Node 24 LTS recommandé), npm et accès au registre npm.

```sh
npm ci
npm run dev
npm run lint
npm run build
npm run preview
```

`src/app/` contient la composition et le démarrage de l'application ; `public/`
contient uniquement les ressources publiques PWA. Les modules métier et la couche
d'accès aux données seront ajoutés dans des lots autorisés ultérieurs, selon
`PROJECT.md`, `AGENTS.md` et `docs/ARCHITECTURE.md`.

## Configuration future

`.env.example` décrit uniquement l'URL et la clé publique publiable Supabase.
Ces variables Vite sont publiques par construction. Ne jamais y mettre une clé
secrète ou privilégiée. Le SDK est installé mais aucun client n'est créé et aucune
variable n'est lue : aucun fichier `.env` n'est nécessaire pour lancer ce lot.

## PWA et hébergement futur

Le manifeste, les icônes PNG et le service worker permettent l'installation sur les
navigateurs compatibles, sous HTTPS (ou localhost). Le service worker est enregistré
uniquement en production ; tester avec `npm run build` puis `npm run preview`.
Les icônes sont des repères techniques provisoires.

Aucune requête n'est interceptée : aucun précache, cache dynamique ou mécanisme
hors ligne n'est implémenté. Aucune donnée métier n'est persistée dans le navigateur.
Le cache HTTP ordinaire reste distinct : les futurs endpoints sensibles devront
envoyer des directives adaptées, notamment `Cache-Control: no-store`.

Le build `dist/` vise la racine du domaine Hostinger. Aucun déploiement n'est
réalisé. Lors du déploiement, servir sous HTTPS, avec le bon type MIME pour le
manifeste et sans cache durable pour `sw.js` et le HTML. La validation d'installation
sur les appareils cibles reste à effectuer sur l'hébergement HTTPS final.

## Réversibilité

Le Lot 0 ajoute seulement le socle frontend et un complément d'architecture.
Il peut être retiré en supprimant ses fichiers et ce complément, sans toucher aux
documents de gouvernance préexistants ni à des données (aucune donnée créée).
