# Lot 0B — Spike PDF serveur — 23 octobre 2026

## Périmètre et socle constaté

Lecture intégrale préalable de PROJECT.md, AGENTS.md, docs/ARCHITECTURE.md et
README.md. Le dépôt fournit React/TypeScript/Vite, une PWA sans cache de données
et un SDK Supabase non instancié. Aucun service backend n'est configuré.
L'architecture décrit les frontières frontend/Hostinger et backend/Supabase,
mais ne choisit pas encore de runtime de génération PDF.

Ce lot autorisé après la fondation ne crée qu'un prototype technique autonome.
Comportement attendu : un serveur local transforme des données techniques
fictives en octets PDF, sans navigateur ni raccordement externe à l'exécution.
Vérifications : HTTP, lecture du PDF, texte, empreinte, rendu visuel, build et lint.
Retour arrière : supprimer `spikes/server-pdf/`, ce document et le lien ajouté au
README. Aucun frontend ni aucune donnée conservée ne dépend de ces fichiers.

## Comparaison et recommandation V1

| Critère | Supabase Edge Function | Service serveur Hostinger |
| --- | --- | --- |
| Simplicité | Backend déjà prévu sur Supabase ; pas de second service à administrer | Service et configuration serveur supplémentaires ; offre réelle à vérifier |
| Fiabilité | Runtime géré, mais limites strictes CPU/mémoire | Ressources et disponibilité liées au plan, au processus et à son exploitation |
| Maintenance | TypeScript/JavaScript, dépendances npm, proximité Auth/Storage | Même générateur possible en Node ; maintenance du service et de ses accès en plus |
| Données structurées | Adapté à un rendu direct via pdf-lib | Adapté avec la même bibliothèque |
| Futur moteur documentaire | Séparer orchestration, autorisations et rendu ; pagination à concevoir | Même séparation possible ; alternative si les besoins dépassent l'Edge |
| SHA-256 | Web Crypto sur les octets finaux | Web Crypto ou crypto Node sur les octets finaux |
| Secrets | Variables/secrets de fonction, jamais Vite | Variables serveur hors fichiers publics et hors Git, jamais Vite |
| Déploiement futur | Fonction versionnée, backend Supabase ; frontend statique Hostinger | Déploiement backend distinct ; hébergement statique seul insuffisant |

**Recommandation : Supabase Edge Function + générateur JavaScript portable
pdf-lib, pour une V1 de documents simples issus de données structurées.**
Cette recommandation privilégie les frontières déjà prévues et évite un second
backend d'exploitation. Elle reste conditionnelle : le spike valide le générateur
sous Node, pas une Edge Function ni le runtime Supabase.

Les limites publiées Supabase sont notamment 256 Mo et 2 secondes de CPU par
requête : elles imposent de mesurer des documents représentatifs avant adoption
en production. La durée murale autorisée ne remplace pas ce budget CPU.
Hostinger propose Node sur certaines offres Business/Cloud ; le plan SHADE n'a
pas été consulté. Un service Node n'est donc pas acquis du seul fait que le
frontend y sera hébergé. La documentation Hostinger indique aussi un délai de
requête de 120 secondes sur ces offres et des restrictions sur les workers.

Pas de Chromium, moteur HTML/CSS, service PDF externe, ni bibliothèque PDF dans
le bundle React. pdf-lib est choisi ici pour sa génération directe en JavaScript
et sa portabilité annoncée Node/Deno, pas comme moteur de mise en page métier.
ReportLab n'est pas retenu pour le prototype car il introduirait un runtime Python
dans la solution cible. L'architecture reste inchangée : aucun déploiement cible
n'a été validé pendant ce spike.

## Prototype réellement exécuté

`spikes/server-pdf/` est un paquet npm indépendant, sans workspace ni dépendance
depuis le paquet racine :

- `render.mjs` : fonction `renderPdf({ text, date, id })` vers `Uint8Array`, sans
  API Node, HTTP, SDK Supabase, données métier ou import frontend.
- `server.mjs` : adaptateur HTTP Node de test ; seule la route GET `/test.pdf`
  génère les données fictives et une date ISO UTC. Aucun contenu utilisateur
  n'est accepté ; réponse `application/pdf` et `Cache-Control: no-store`.
- `test.mjs` : démarre le serveur sur loopback et port libre, télécharge le PDF,
  vérifie le statut, les en-têtes, la structure, une page, SHA-256 et les 404,
  puis ferme le serveur. Un second test change le texte et rejette les entrées
  trop longues ou non prises en charge par ce prototype.
- `package.json`, `package-lock.json` : pdf-lib épinglé en 1.17.1, avec quatre
  dépendances transitives verrouillées ; scripts d'installation désactivés.
- `.gitignore` : exclut les dépendances et les résultats locaux.

Le fichier contient seulement un titre de test, un texte dynamique fictif, une
date technique et `TEST-0001`. Aucun document métier SHADE n'est créé.
L'empreinte est calculée avec Web Crypto après la génération des octets reçus
et conservée dans un fichier technique séparé. Elle démontre la faisabilité du
calcul, sans constituer un mécanisme de preuve ou de conservation.

À terme, la couche d'accès backend du frontend appellera une opération applicative
indépendante du moteur PDF. Le backend vérifiera les droits et construira les
données structurées de référence avant d'appeler le renderer. Ni pdf-lib, ni le
choix Node/Deno, ni les chemins de stockage ne devront entrer dans les composants
React. Aucun contrat métier ni endpoint de production n'est implémenté ici.

## Reproduire et résultats

Depuis la racine, Node 22.12 minimum et accès npm à l'installation uniquement :

```sh
npm ci --prefix spikes/server-pdf --ignore-scripts
npm test --prefix spikes/server-pdf
npm run build
npm run lint
pdfinfo spikes/server-pdf/output/technical-test.pdf
pdftoppm -scale-to 1000 -png -singlefile spikes/server-pdf/output/technical-test.pdf spikes/server-pdf/output/preview
```

Résultats locaux au 23 octobre 2026 (Node 24.22.1, npm 11.19.1) :

- Installation isolée réussie : 5 paquets ajoutés, audit npm : 0 vulnérabilité
  signalée au moment de l'installation. Aucun manifeste/lockfile racine modifié.
- Tests Node : 2 réussis, 0 échec. Le test produit `output/technical-test.pdf`
  et `output/technical-test.sha256` ; ce dossier est ignoré par Git.
- Build frontend : réussi (TypeScript et Vite).
- Lint : réussi après déclaration/import des globals Node du test.
- pdfinfo : PDF 1.7, A4, 1 page, 1 071 octets, sans formulaire ni JavaScript.
- Rendu PNG via Poppler et inspection visuelle : quatre lignes lisibles,
  accents corrects, aucun chevauchement ou texte tronqué. Poppler a émis des
  avertissements sur les polices de remplacement Symbol/ArialUnicode.
- Lecture indépendante avec pypdf du runtime d'outillage : texte dynamique,
  date ISO et identifiant confirmés, empreinte recalculée avec hashlib identique.
  pypdf/Poppler ne sont pas des dépendances du projet.

La commande indépendante exécutée avec le Python du runtime d'outillage :

```sh
python -c "from pypdf import PdfReader; from pathlib import Path; import hashlib; p=Path('spikes/server-pdf/output/technical-test.pdf'); r=PdfReader(p); t=r.pages[0].extract_text(); assert len(r.pages)==1; assert 'Texte dynamique : génération serveur fictive' in t; assert 'Date : 2026-10-23T' in t; assert 'Identifiant fictif : TEST-0001' in t; assert hashlib.sha256(p.read_bytes()).hexdigest()==p.with_suffix('.sha256').read_text().strip(); print(t); print('Independent text and SHA-256 checks: OK')"
```

Le contrôle de date ci-dessus décrit cette exécution ; adapter la date lors d'un
nouveau test. `pdftotext` était indisponible, d'où le recours à pypdf.
Le bac à sable bloquait l'accès npm (ENOTFOUND) et le test HTTP loopback (EACCES) :
les deux opérations ont réussi hors bac à sable après autorisation. Aucune
connexion à un projet Supabase ou service de génération distant n'a eu lieu.

## Limites et travaux futurs

- Deno/CLI Supabase absents de l'environnement : import npm, démarrage Edge,
  déploiement et ressources réelles non testés. Aucun SLA ni test de charge.
- Une page, texte latin court et police standard seulement ; pas de moteur
  HTML/CSS, pagination automatique, tableaux, longs textes, polices Unicode
  embarquées, PDF/A ou vérification d'accessibilité. Ces besoins peuvent changer
  le choix de renderer ; aucune promesse de conformité documentaire.
- Évaluer la maintenance de pdf-lib et ses mises à jour avant production ;
  garder son utilisation derrière la fonction de rendu remplaçable.
- Pas de déterminisme binaire entre générations (date et métadonnées variables).
  Une empreinte devra porter sur les octets effectivement conservés, après toute
  transformation, sans régénérer le PDF pour retrouver cette empreinte.
- Avant tout raccordement réel : autorisations serveur et isolation tenant,
  validation des entrées, limites de taille, erreurs, délais, reprise/idempotence,
  secrets hors Git, stockage privé et versions immuables à concevoir et tester.
  Le serveur local n'a pas d'authentification et ne doit pas être déployé tel quel.
- Aucun cache applicatif ni service worker modifié. Le no-store du prototype
  ne valide pas les futurs accès aux documents depuis Storage.

Aucun secret, table, migration, modèle métier, consentement, signature, OTP,
email, donnée réelle ou fonctionnalité métier ajouté. Aucun déploiement, commit
ou push. Aucun changement du design, du frontend ou des décisions existantes.

## Sources officielles consultées

- [pdf-lib : bibliothèque JavaScript, Node et Deno](https://pdf-lib.js.org/)
- [Supabase : dépendances npm](https://supabase.com/docs/guides/functions/dependencies)
- [Supabase : limites Edge Functions](https://supabase.com/docs/guides/functions/limits)
- [Supabase : secrets serveur](https://supabase.com/docs/guides/functions/secrets)
- [Hostinger : déployer un serveur Node et variables d'environnement](https://www.hostinger.com/support/how-to-deploy-a-nodejs-website-in-hostinger/)
- [Hostinger : limites Node](https://www.hostinger.com/support/hostinger-node-js-limits-for-web-and-cloud-plans/)
- [Changelog Supabase](https://supabase.com/changelog.md) : consulté avant analyse.
  Le changement TLS annoncé pour novembre 2026 a été lu ; il ne touche pas le
  prototype local sans connexion Supabase.

## Complément — tentative de validation Edge locale, 23 octobre 2026

### Résultat : arrêt au contrôle des prérequis

Les cinq documents demandés ont été relus intégralement avant modification :
PROJECT.md, AGENTS.md, docs/ARCHITECTURE.md, ce rapport et README.md.
Comportement attendu de ce complément : valider le renderer existant dans le
runtime Supabase Edge local seulement si ses prérequis sont disponibles.
Retour arrière : retirer cette section ; aucun code ou donnée à restaurer.

| Prérequis | Constat dans l'environnement accessible |
| --- | --- |
| Node | 24.22.1, disponible |
| npm | 11.19.1, disponible |
| CLI Supabase | Non détectée dans PATH ; binaire local `node_modules/supabase/bin/supabase.exe` absent |
| Docker | Commande non détectée ; exécutables Docker Desktop absents des chemins usuels Program Files et LocalAppData |
| Runtime compatible | Commandes podman et nerdctl non détectées |
| Deno | Commande non détectée ; pas indispensable au service local via la CLI Supabase |

La recherche de services Docker/Podman/Rancher n'a pas pu être effectuée : accès
au gestionnaire des services Windows refusé. Le constat porte sur les exécutables
et chemins accessibles, pas sur un inventaire exhaustif des logiciels installés.
Un moteur Docker utilisable n'a donc pas pu être établi.

La [méthode officielle Supabase locale](https://supabase.com/docs/guides/functions/quickstart)
utilise la CLI et Docker (ou un runtime compatible), puis le service local des
fonctions. L'[explication du runtime](https://supabase.com/docs/guides/functions/development-environment)
précise que la CLI sert les fonctions avec Supabase Edge Runtime, pas avec le
binaire Deno standard. Un succès sous Deno seul ne remplacerait donc pas ce test.
Le runtime autonome officiel a également été consulté dans le
[dépôt Supabase Edge Runtime](https://github.com/supabase/edge-runtime) ; aucune
compilation ou installation de remplacement n'a été entreprise.

**Aucune méthode de lancement n'a été exécutée**, puisque le prérequis Docker
manque dans l'environnement détecté. Conformément à la demande, arrêt du test
runtime : aucune installation de Docker, CLI ou autre prérequis, aucun recours
distant, aucune initialisation Supabase, aucune Edge Function non testée créée.
La sélection du chemin local le plus léger sera confirmée avec l'aide de la CLI
disponible lors de la reprise ; aucune stack complète n'a été démarrée ici.

### Commandes exécutées et vérifications

```powershell
Get-Command docker,supabase,deno,node,npm -ErrorAction SilentlyContinue
Get-Command docker,podman,nerdctl,supabase,deno -All -ErrorAction SilentlyContinue
Test-Path 'C:/Program Files/Docker/Docker/resources/bin/docker.exe'
Test-Path "$env:LOCALAPPDATA/Docker/resources/bin/docker.exe"
Test-Path node_modules/supabase/bin/supabase.exe
Get-Service -Name '*docker*','*podman*','*rancher*' -ErrorAction SilentlyContinue
node --version
npm --version
npm run build
npm run lint
npm test --prefix spikes/server-pdf
git diff --check
```

- Détection : résultats du tableau ci-dessus ; requête des services refusée.
- Build TypeScript/Vite : réussi ; lint : réussi.
- Prototype Node inchangé : 2 tests réussis, 0 échec. Réexécution hors bac à sable
  pour permettre l'appel HTTP loopback, sans connexion distante.
- Test Node HTTP/PDF/SHA-256/routes refusées : environ 63,7 ms ; test de données
  structurées et entrées invalides : environ 6,7 ms ; suite : environ 324 ms.
  Ce sont des durées de tests Node incluant d'autres opérations, **pas** le temps
  de génération Edge ni une mesure isolée du renderer.
- Aucun démarrage Edge, appel HTTP Edge, PDF Edge, empreinte Edge ou entrée
  invalide Edge testé. Temps de génération et ressources Edge : non mesurables.
- Aucun accès en écriture à une base ou à Storage : aucun runtime/service
  Supabase lancé et aucun code de raccordement ajouté.

### Conclusion et reprise

La compatibilité de pdf-lib avec Supabase Edge reste **non vérifiée** : impossible
de classer le résultat en « sans adaptation », « adaptation mineure » ou
« incompatible » sans exécution. Le renderer Node n'a subi aucune adaptation.

La préférence reste Supabase Edge Function pour les raisons de la comparaison
précédente, mais aucune décision définitive n'est justifiée par cette tentative.
L'absence de prérequis locaux ne démontre pas une incompatibilité et ne justifie
pas à elle seule de basculer vers Hostinger. docs/ARCHITECTURE.md reste inchangé.

Pour reprendre : disposer d'un moteur Docker compatible démarré et accessible
depuis ce terminal, ainsi que de la CLI Supabase. Vérifier leurs versions et l'aide
locale avant de préparer la fonction isolée réutilisant `render.mjs`, puis tester
HTTP, contenu, empreinte serveur, entrée invalide et durée dans Edge Runtime.
Aucun projet Supabase distant ni liaison de projet ne sera nécessaire au test.

Seul ce rapport est modifié dans ce complément. Aucune dépendance ajoutée,
aucun code applicatif ajouté, aucun raccordement React et aucune modification
du renderer, de l'architecture ou du design. Les fichiers non commités du spike
précédent ont été préservés. Aucun secret réel, projet distant, déploiement,
table ou migration métier, donnée réelle, authentification métier, Storage réel,
consentement, signature, OTP, email ou fonctionnalité métier utilisé ou ajouté.
Aucun commit ni push.

## Reprise — validation Edge locale réussie, 23 octobre 2026

Cette section actualise le blocage précédent sans supprimer son historique.
Les cinq documents de cadrage demandés ont été relus avant modification.
Le dépôt était propre au début de la reprise. L'objectif de ce lot est uniquement
la validation du runtime, pas un endpoint de production.

### Environnement et méthode réellement utilisés

- Docker Desktop 4.96.3 ; client et moteur Docker 29.9.2, contexte desktop-linux.
  `docker version` fonctionne hors bac à sable (accès au pipe refusé à l'intérieur).
- CLI Supabase 2.122.0 installée comme dépendance de développement épinglée dans
  `spikes/server-pdf/` seulement ; aucun changement du paquet frontend.
- Supabase Edge Runtime 1.77.8, annoncé compatible Deno 2.1.4 par les logs.
- Initialisation locale officielle via la CLI, dans `spikes/server-pdf/supabase/`.
  Aucun login, lien ou projet distant. Le `project_id` est un nom de conteneurs
  locaux, pas une référence de projet Supabase hébergé.

La tentative `functions serve` seule a répondu `ServeLocalDbNotRunningError`.
La CLI demande donc un démarrage local préalable. Configuration réduite : Auth,
Storage, Realtime, Studio, SMTP, analytics, seeds et migrations désactivés.
Le démarrage avec exclusions explicites a réellement lancé quatre conteneurs :
Postgres 17.11.0.006, Kong 2.8.1, PostgREST 16.5 et Edge Runtime 1.77.8.
PostgREST a été démarré malgré son exclusion demandée par cette version de CLI.
Aucune stack métier, Auth, Storage ou messagerie n'a été utilisée.

Les téléchargements npm et images officielles utilisent Internet pour l'outillage.
Cela n'est pas une connexion à un projet Supabase distant : le test HTTP est fixé
à `http://127.0.0.1:54321/functions/v1/pdf-spike`. Le code de la fonction n'effectue
aucun appel réseau applicatif, ne lit aucun secret et n'importe aucun SDK Supabase.

### Code et adaptations

- Le corps de `render.mjs` est déplacé sans changement dans
  `supabase/functions/_shared/render.mjs`. L'ancien chemin réexporte la même
  fonction : une seule implémentation reste partagée par Node et Edge.
- `supabase/functions/deno.json` associe l'import `pdf-lib` à
  `npm:pdf-lib@1.17.1`. Aucun remplacement de bibliothèque, navigateur embarqué,
  adaptation de logique PDF ou dépendance native nécessaire.
- `supabase/functions/pdf-spike/index.ts` sert la fonction technique : POST JSON,
  données limitées aux deux fixtures fictives A/B, réponse PDF `no-store`,
  empreinte serveur Web Crypto SHA-256 dans `X-PDF-SHA256`, durée du renderer
  dans `Server-Timing`. JSON invalide ou fixture non autorisée : 400 ; GET : 405.
  L'absence de vérification JWT est limitée à ce spike local sans donnée réelle.
- `edge-test.mjs` teste les deux fixtures par HTTP, vérifie PDF/une page,
  empreinte recalculée, en-têtes, trois entrées invalides et méthode refusée.
  Les PDF et métriques sont écrits par le client de test dans `output/`, ignoré.
  Le serveur Edge ne fait aucune écriture de fichier, base ou Storage.
- `supabase/config.toml` et `.gitignore` isolent la configuration et les fichiers
  techniques temporaires. Aucun secret réel ou fichier `.env` créé.
- `package.json` et son lockfile ajoutent seulement la CLI locale et ses
  dépendances de développement ; pdf-lib reste en 1.17.1.

**Compatibilité réelle : pdf-lib fonctionne dans Supabase Edge Runtime local,
sans adaptation de son code de rendu.** Seuls l'emplacement partagé, la résolution
npm dans Deno et l'adaptateur HTTP sont spécifiques à l'environnement.

### Commandes de reprise et de reproduction

Depuis la racine, Docker démarré. Les commandes CLI ci-dessous ont été précédées
de la lecture de `--help`, `init --help`, `start --help`, `functions serve --help`
et `stop --help`. Elles utilisent uniquement le binaire installé dans le spike.

```powershell
docker version
npm view supabase version
npm install --prefix spikes/server-pdf --save-dev --save-exact supabase@2.122.0
spikes/server-pdf/node_modules/.bin/supabase --version
spikes/server-pdf/node_modules/.bin/supabase init --workdir spikes/server-pdf --yes
# Après création de la fonction et réduction de config.toml :
spikes/server-pdf/node_modules/.bin/supabase start --workdir spikes/server-pdf --exclude gotrue,realtime,storage-api,imgproxy,mailpit,postgrest,postgres-meta,studio,logflare,vector,supavisor
spikes/server-pdf/node_modules/.bin/supabase functions serve pdf-spike --workdir spikes/server-pdf --no-verify-jwt
# Dans un autre terminal :
node spikes/server-pdf/edge-test.mjs
npm test --prefix spikes/server-pdf
npm run build
npm run lint
docker ps --filter name=shade-pdf-spike --format "{{.Names}} {{.Image}}"
docker exec supabase_db_shade-pdf-spike psql -U postgres -d postgres -Atc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';"
docker logs --tail 25 supabase_edge_runtime_shade-pdf-spike
spikes/server-pdf/node_modules/.bin/supabase stop --workdir spikes/server-pdf --project-id shade-pdf-spike
git diff --check
```

Sur un clone, `npm ci --prefix spikes/server-pdf` restaure aussi la CLI ; son
installation nécessite ses scripts d'installation, contrairement au seul renderer
PDF du premier spike. Ne pas relancer `init` sur la configuration déjà présente.
Les accès Docker, téléchargements et HTTP loopback ont été exécutés hors bac à
sable après autorisation. Aucune installation système supplémentaire effectuée.

### Résultats constatés

| Contrôle | Résultat |
| --- | --- |
| Démarrage local | Réussi ; logs de service de `pdf-spike` dans Edge Runtime |
| HTTP POST A/B | 200, application/pdf, no-store |
| PDF | 1 page, 1 033 octets par fixture, structure relue avec pdf-lib |
| Texte/date/identifiant | Confirmés pour A et B par lecture indépendante pypdf |
| SHA-256 serveur | Identique au recalcul Node et au recalcul indépendant Python |
| Entrées `{}`, `null`, JSON tronqué | 400 avec erreur JSON technique |
| Méthode GET | 405 |
| Base/Storage | Aucune écriture applicative ; zéro table dans public ; aucun conteneur Storage |
| Tests Node existants | 2 réussis, 0 échec après déplacement du renderer |
| Build frontend | Réussi, bundle frontend inchangé |
| Lint | Réussi après déclaration des globals du test Edge |

Les deux PDF ont été lus avec pypdf, leur date et leurs identifiants vérifiés et
leurs empreintes recalculées via hashlib. Le PDF A a aussi été rendu avec Poppler
et inspecté : quatre lignes lisibles, sans troncature ni chevauchement. Les mêmes
avertissements de polices de remplacement Poppler que lors du spike Node restent
sans défaut visible. Ces outils ne sont pas des dépendances du projet.

| Mesure ponctuelle | Fixture A (premier appel) | Fixture B (appel suivant) |
| --- | --- | --- |
| Renderer côté Edge, performance.now | 15,587 ms | 2,630 ms |
| Test client jusqu'à lecture et vérifications | 979,972 ms | 11,256 ms |

Ces durées sont des mesures murales ponctuelles, pas des mesures CPU ni un test
de charge. Le premier appel inclut l'initialisation et la résolution des modules.
La durée serveur exclut le hash et la réponse HTTP. Aucun problème évident de
compatibilité ou épuisement de ressources observé sur ces deux petits fichiers.

La CLI initialise ses schémas techniques locaux et rôles dans Postgres au
démarrage : il serait incorrect de présenter ce démarrage comme une absence
absolue d'écritures système. Il n'y a aucune table/migration métier, ni aucune
écriture de données par le renderer ou la fonction. Les services du spike ont
été arrêtés après vérification, sans suppression de volumes techniques.

### Recommandation après validation

**Retenir Supabase Edge Function pour la V1 de PDF simples à données structurées.**
La portabilité du renderer et le hash serveur sont maintenant validés dans le
runtime local officiel ; maintenir un service Hostinger supplémentaire n'est pas
justifié pour ce périmètre. La décision n'est pas encore inscrite dans
docs/ARCHITECTURE.md, conformément à la demande.

Restent à tester dans des lots ultérieurs : documents représentatifs, budgets CPU
et mémoire de la plateforme hébergée, mise en page avancée, droits multi-tenant,
finalisation et conservation immuable. Ce spike ne valide ni la production ni
la sécurité d'un endpoint métier. La fonction volontairement sans authentification
ne doit pas être déployée telle quelle.

Réversibilité : arrêter seulement le projet local `shade-pdf-spike`, retirer les
fichiers Edge et la dépendance CLI, puis replacer le renderer à son ancien chemin.
Aucune donnée métier ou interface ne dépend de ce lot.

Aucun projet/infrastructure Supabase distant, lien, déploiement, secret réel,
table/migration métier, donnée réelle, Storage réel, authentification métier,
OTP, email, consentement, signature ou fonctionnalité métier utilisé ou ajouté.
Frontend, design et architecture inchangés. Aucun commit ni push.
