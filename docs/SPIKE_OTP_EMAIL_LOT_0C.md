# Lot 0C — Spike OTP et email local — 23 octobre 2026

## Périmètre et méthode

Lecture préalable intégrale de PROJECT.md, AGENTS.md, docs/ARCHITECTURE.md,
README.md et docs/SPIKE_PDF_LOT_0B.md. Dépôt propre au départ du lot.

Objectif : tester un mécanisme technique de challenge/code à usage unique dans
Supabase Edge Runtime local, sans Supabase Auth, document, consentement, signature,
cliente, frontend ou donnée réelle. Aucun moteur de preuve métier n'est construit.
La séparation des fournisseurs et des secrets côté serveur est une contrainte
de ce lot ; aucune décision d'architecture existante n'est modifiée.

Le lot doit être vérifiable par HTTP local, capture d'email et tests d'expiration,
tentatives et rejeu. Retour arrière : arrêter le seul projet local
`shade-pdf-spike`, retirer `otp-spike/`, `otp-test.mjs` et ce rapport ; remettre
`local_smtp.enabled = false` et retirer la section `functions.otp-spike` dans
la configuration locale. Aucune donnée conservée de SHADE n'en dépend.

## Architecture réellement testée

Réutilisation de la CLI 2.122.0 et de la configuration Supabase locale existante
dans `spikes/server-pdf/`. Docker Engine 29.9.2 / Desktop 4.96.3 ; Edge Runtime
1.77.8, compatible Deno 2.1.4 ; Mailpit fourni par la CLI : image 1.31.3.

```text
Test Node (loopback)
  -> Edge Function otp-spike
       -> service OTP indépendant, état et journal en mémoire
       -> adaptateur send({ id, code })
            -> API HTTP Mailpit, réseau Docker local
  -> API / interface Web Mailpit pour lire les emails de test
```

La fonction est rangée dans la stack du spike PDF uniquement pour réutiliser son
runtime ; elle ne dépend ni du renderer ni de pdf-lib. Le mécanisme d'envoi est
injecté dans le service OTP. Un futur adaptateur fournisseur peut remplacer
`mailpit.mjs` sans changer la génération/vérification des codes.

La stack contient Postgres technique, Kong, PostgREST, Edge et Mailpit. Auth,
Storage, Realtime, Studio, analytics, seeds et migrations restent désactivés.
Comme lors du Lot 0B, cette version de CLI démarre PostgREST malgré l'exclusion
demandée. Aucun accès de la fonction à Postgres ou Storage, aucun SDK Supabase,
aucune table ou migration, même technique. Contrôle SQL en lecture seule : zéro
table dans `public`. Les schémas système du moteur local ne sont pas des tables
métier ni une nouvelle persistance OTP.

## Génération, protection et cycle de vie

- Code à six chiffres obtenu avec `crypto.getRandomValues` et échantillonnage par
  rejet pour éviter le biais du modulo. Aucun générateur pseudo-aléatoire faible.
- Challenge identifié par UUID aléatoire, indépendant de toute donnée métier.
- Protection : HMAC-SHA-256 Web Crypto de `identifiant:code`, avec clé aléatoire
  non extractible créée dans le worker. Le faible espace des codes rendrait un
  simple SHA-256 non salé insuffisant contre une recherche hors ligne ; le HMAC
  ajoute un secret serveur éphémère, qui n'est ni configuré ni sauvegardé.
- L'enregistrement ne contient que digest, expiration, plafond/compteur de
  tentatives et état. Aucun code brut conservé dans la Map. Le code transite
  nécessairement en mémoire pendant la génération, l'envoi et la vérification.
  JavaScript ne permet pas de garantir l'effacement physique de ses chaînes.
- Vérification avec `crypto.subtle.verify`, pas comparaison de chaînes de hash.
- Validité configurable dans les bornes du test : 1 à 60 secondes, défaut
  60 secondes. Décompte après remise réussie à Mailpit ; date serveur, vérifiée
  également après le calcul cryptographique.
- Limite configurable de 1 à 3 tentatives, défaut 3. Chaque code soumis à un
  challenge actif consomme une tentative, y compris un format de code incorrect.
  Le dernier échec atteint l'état `attempts_exceeded` ; un code ensuite correct
  ne débloque pas ce challenge.
- États retournés : `valid`, `invalid`, `expired`, `attempts_exceeded`.
  `invalid` ne ferme pas le challenge tant que le budget reste disponible.
  Une validation réussie consomme le challenge ; tout rejeu renvoie `invalid`.
- Les requêtes sont sérialisées dans le worker du spike pour éviter la double
  consommation concurrente. Cela ne garantit aucune atomicité entre workers.
- En cas d'échec d'envoi, aucun challenge utilisable n'est enregistré ; événement
  `delivery_failed` sans détail fournisseur ni code.
- Plafond de 100 challenges ; purge opportuniste des enregistrements anciens à
  l'émission. Journal circulaire limité à 200 événements en mémoire : uniquement
  UUID technique, état et date ISO. Aucune adresse, code, digest ou clé exposé
  dans le journal ; pas de `console.log` dans la fonction.

L'API de test autorise POST `issue`, `verify` et `audit` ; `issue` ne renvoie jamais
le code. Durées et plafonds sont réglables par le test local uniquement ; ces
paramètres devront être exclusivement gouvernés côté serveur en production.
Les diagnostics sont sans authentification uniquement dans ce spike local.
Les réponses portent `Cache-Control: no-store`. Aucun endpoint à déployer tel quel.

## Email local et traitement du code en clair

`local_smtp.enabled` active le Mailpit livré par la CLI, dont le nom de conteneur
historique reste `supabase_inbucket_shade-pdf-spike`. Le service OTP appelle
`http://supabase_inbucket_shade-pdf-spike:8025/api/v1/send` via son adaptateur.
C'est un envoi d'email à l'API de capture Mailpit, **pas un test de transport SMTP
externe**. Aucun relais, forwarding ou fournisseur externe n'est configuré.

Expéditeur fixé à `sender@shade.invalid`, destinataire fixé à
`recipient@shade.invalid`. Le client ne peut ni choisir une adresse ni fournir
une URL. Toute propriété d'émission supplémentaire, notamment une adresse, est
refusée. Les seules adresses utilisées appartiennent au domaine fictif `.invalid`.

Interface de capture pendant le test : `http://127.0.0.1:54324`. Le test vérifie
le chargement HTML de l'interface, la présence des messages dans sa liste et le
contenu des emails via l'API. Il lit les codes exclusivement en mémoire, sans
les afficher, enregistrer une capture d'écran ou sauvegarder un corps de message.

**Distinction nécessaire :** le code est en clair dans l'email capturé, comme
demandé, alors que l'état de vérification OTP ne stocke qu'un HMAC. Mailpit écrit
par défaut les messages dans sa base SQLite temporaire, même sans volume monté.
Il serait donc inexact d'affirmer qu'aucun octet d'email ne touche temporairement
le disque Docker. Cette capture locale est la seule exception au code non
persisté : aucun code brut dans une persistance applicative, le dépôt ou les logs.
Le test supprime uniquement ses messages par ID dans un bloc `finally`, puis
l'arrêt de Mailpit supprime sa base temporaire. Pas de volume Mailpit ni export.

Le schéma de l'API Mailpit a été lu sur l'instance locale
`/api/v1/swagger.json` avant les tests, et les champs From/To/Text et la suppression
par IDs ont été confirmés. Aucun message de test n'est envoyé à une personne.

## Tests et commandes

Depuis la racine, avec Docker démarré et la CLI du Lot 0B installée :

```powershell
docker version
spikes/server-pdf/node_modules/.bin/supabase start --help
spikes/server-pdf/node_modules/.bin/supabase functions serve --help
spikes/server-pdf/node_modules/.bin/supabase start --workdir spikes/server-pdf --exclude gotrue,realtime,storage-api,imgproxy,postgrest,postgres-meta,studio,logflare,vector,supavisor
spikes/server-pdf/node_modules/.bin/supabase functions serve otp-spike --workdir spikes/server-pdf --no-verify-jwt
# Dans un autre terminal :
node spikes/server-pdf/otp-test.mjs
npm test --prefix spikes/server-pdf
npm run build
npm run lint
git diff --check
docker exec supabase_db_shade-pdf-spike psql -U postgres -d postgres -Atc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';"
spikes/server-pdf/node_modules/.bin/supabase stop --workdir spikes/server-pdf --project-id shade-pdf-spike
docker ps --filter name=shade-pdf-spike --format "{{.Names}}"
```

Les accès Docker et loopback nécessitent une exécution hors bac à sable dans cet
environnement. Aucun login, `link`, déploiement ou appel de projet distant.
L'image Mailpit officielle a été téléchargée ; aucun paquet npm ajouté.
Une première tentative de démarrage, lancée avant que le fichier de fonction ne
soit disponible, a échoué ; la relance avec les fichiers présents a réussi.
La configuration Mailpit a été inspectée avant émission : pas de volume monté,
ni de configuration de relais ou forwarding externe.

Résultats :

| Vérification | Résultat |
| --- | --- |
| Émission et génération à six chiffres | Réussies ; aucun code retourné par `issue` |
| Capture Mailpit | Emails listés, destinataire fictif et code vérifiés en mémoire |
| Interface Mailpit | Réponse HTTP et page HTML Mailpit vérifiées |
| Code correct | `valid` |
| Code faux, puis correct avec budget disponible | `invalid`, puis `valid` |
| Expiration réelle après attente de 1,1 seconde | `expired` |
| Deux essais faux avec plafond 2 | `invalid`, puis `attempts_exceeded` |
| Code correct après blocage | `attempts_exceeded` |
| Rejeu après validation | `invalid` |
| Deux validations simultanées | Une `valid`, une `invalid` |
| JSON invalide / adresse fournie au client | HTTP 400 |
| Journal | Champs limités à identifiant, état et date |
| Codes dans logs Edge/Kong/Mailpit et fichiers versionnables | Aucune correspondance aux codes émis ; stdout et stderr contrôlés en mémoire |
| Nettoyage | Messages du test supprimés par ID, sans toucher aux autres messages |
| Build frontend / lint | Réussis |
| Tests du prototype Node PDF | Deux tests réussis |

Les assertions susceptibles de révéler un OTP sont des assertions booléennes
avec message générique ; aucun code ne passe dans les sorties du test. Les
messages Mailpit et les réponses d'audit ne sont jamais sauvegardés par le test.
Les recherches de motifs de secrets et l'inspection des fichiers complètent ces
contrôles sans constituer une preuve d'absence de toute fuite possible en production.

## Limites et décisions avant production

1. La Map et la clé disparaissent au redémarrage ; plusieurs workers ne partagent
   pas les challenges ou les compteurs. Ce choix valide le mécanisme local,
   pas une persistance de production. Prévoir un stockage protégé et des mises à
   jour atomiques, avec une migration versionnée si une base est retenue.
2. Définir autorisations et isolation tenant, rattachement immuable à une version
   documentaire et à son empreinte, contexte de vérification et idempotence.
   Aucun de ces sujets métier n'est implémenté ici.
3. Le budget de tentatives ne protège qu'un challenge. Définir aussi quotas
   d'émission, limites par destination/contexte et protection contre les abus,
   renvois de codes, renouvellement et invalidation des codes précédents.
4. Choisir une durée réelle, le nombre d'essais, la stratégie de clé HMAC/rotation
   et le stockage des secrets serveur. Le spike utilise une clé éphémère, pas un
   secret réel d'exploitation. Aucun mécanisme de récupération de clé n'est testé.
5. Choisir le fournisseur email et tester délivrabilité, transport protégé,
   erreurs, délais, retries, ambiguïtés d'envoi, observabilité sans code, coûts
   et conservation des données. Mailpit ne simule pas ces garanties.
6. Le journal en mémoire est limité et modifiable par le processus ; ce n'est pas
   un journal de preuve durable ni une signature. Définir conservation, intégrité
   des événements, accès, fuseaux et suppression avant production.
7. Le code local n'est ni une authentification Supabase Auth ni une signature
   électronique, et ne confère aucune qualification eIDAS.
8. La sérialisation du spike n'est pas un dispositif distribué ni un test de
   charge ; aucun engagement de performance ou de sécurité de production.

## Recommandation V1 et inventaire

Recommander une orchestration OTP côté serveur via Edge Function, indépendante
de Supabase Auth, avec service OTP séparé de l'adaptateur email, Web Crypto et
secret serveur. Remplacer impérativement l'état en mémoire et la clé éphémère
par une solution durable et atomique avant usage réel. Le fournisseur email reste
à choisir ; Mailpit n'est qu'un récepteur local de test. Ne pas déployer ce spike.
Décision d'architecture finale laissée à validation : ARCHITECTURE.md inchangé.

Fichiers : `spikes/server-pdf/supabase/config.toml` modifié ; dossier
`spikes/server-pdf/supabase/functions/otp-spike/` créé (`index.ts`, `otp.mjs`,
`mailpit.mjs`) ; `spikes/server-pdf/otp-test.mjs` et ce rapport créés.
Aucune dépendance ajoutée, aucune table ou migration technique nécessaire.

Aucune donnée réelle, adresse réelle, cliente, consentement, signature, parcours
cliente, fonctionnalité métier ou intégration React. Aucun secret réel, projet
Supabase distant, lien ou déploiement, fournisseur email externe, table ou
migration métier. Aucun commit ni push. La stack du spike est arrêtée après test.
