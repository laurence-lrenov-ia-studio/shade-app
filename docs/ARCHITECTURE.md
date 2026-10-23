# SHADE — Architecture cible

## Statut et périmètre

Ce document formalise l'architecture cible de la V1, sans initialiser de projet technique. SHADE est une application métier pour professionnelles de l'esthétique. Le cadrage produit est défini dans [PROJECT.md](../PROJECT.md).

La V1 prioritaire couvre les consentements, le stock de produits et de lots, la traçabilité cliente ↔ séance/prestation ↔ produits/lots et le socle minimal cliente → prestation → séance.

Le scan code-barres depuis mobile ou tablette, destiné à accélérer la saisie des produits et lots, est classé en V1 bis. Il ne doit pas bloquer la sortie de la V1 et sera développé immédiatement après validation du noyau stock/lot.

Les photos avant/après, les fonctions visuelles et la retouche, l'agenda avancé / Planity, la clôture de journée, les imports complexes et l'IA / Studio sont reportés après V1/V1 bis. Les règles d'architecture, de sécurité et de conservation décrites ci-dessous restent applicables, y compris aux fonctions reportées.

## Frontières techniques

| Composant | Responsabilité cible |
| --- | --- |
| React + TypeScript + Vite | Interface PWA responsive sur tablette, petit PC et mobile |
| Hostinger | Hébergement du frontend compilé |
| Supabase Auth | Authentification des utilisatrices et utilisateurs |
| Supabase PostgreSQL | Données métier, relations, contraintes et politiques RLS |
| Supabase Storage privé | Documents et photos sensibles, originaux et versions distinctes |
| GitHub privé | Source de vérité du code, des migrations et de la documentation |

L'interface présente les données et pilote les actions autorisées. Les contrôles d'accès et les invariants de conservation doivent être imposés côté backend et stockage. Les droits ne dépendent jamais uniquement de contrôles dans le navigateur.

La cible PWA n'autorise pas implicitement la mise en cache hors ligne de documents ou photos sensibles. Une éventuelle gestion hors ligne de ces données devra faire l'objet d'une conception spécifique avant implémentation.

## Multi-tenant dès l'origine

Un tenant représente une organisation utilisatrice de SHADE. Un compte authentifié accède aux données d'une organisation uniquement selon une appartenance et des droits vérifiés côté backend.

- Chaque donnée métier et chaque objet sensible doivent être rattachables sans ambiguïté à leur tenant.
- Les relations et contraintes doivent empêcher les associations accidentelles de données appartenant à des tenants différents.
- L'identifiant de tenant envoyé par le frontend est une donnée à vérifier, jamais une preuve d'autorisation.
- Les politiques RLS contrôlent les droits sur les lignes, y compris lors des écritures et des changements de rattachement.
- Les politiques Storage doivent appliquer la même isolation aux fichiers ; un chemin de fichier seul ne suffit pas à garantir cette isolation.

Le schéma détaillé et les rôles seront définis lors de lots ultérieurs, en conservant ces invariants.

## Modèle métier configurable

Les prestations, variantes et workflows sont décrits par des données de configuration, avec un périmètre de tenant explicite. Aucun parcours ni aucune règle spécifique à une spécialité esthétique ne doit être codé en dur par métier.

La logique applicative interprète cette configuration. L'évolution d'une configuration ne doit pas modifier rétroactivement le contenu d'un document final ni les éléments de consentement déjà conservés : les versions ou instantanés nécessaires doivent être liés aux documents concernés.

## Documents, consentements et photos

Les métadonnées et relations sont conservées dans PostgreSQL ; les fichiers sensibles sont conservés dans des buckets Storage privés.

- Les accès aux fichiers nécessitent une autorisation vérifiée. Si des liens temporaires sont utilisés, leur durée doit être limitée et leur émission autorisée.
- Un document final et le fichier qui le représente ne sont pas écrasables. Une correction crée une nouvelle version, liée à la précédente ; la version antérieure demeure conservée.
- La finalisation doit préserver les informations nécessaires pour retrouver le contenu et la configuration utilisés ainsi que les éléments de consentement associés.
- Une photo originale n'est jamais remplacée ni écrasée. Une retouche, un recadrage ou une autre transformation produit un objet distinct lié à l'original.
- La base et les politiques de stockage doivent empêcher les contournements de ces règles par un appel direct, indépendamment de l'interface.

SHADE Sign ne doit jamais être présenté comme une signature électronique qualifiée eIDAS. Aucune qualification de ce type ne doit être suggérée par les libellés, la documentation ou la communication produit.

## Sécurité et secrets

Aucun secret ne doit être ajouté au dépôt Git, même privé. Les secrets d'exploitation doivent être gérés hors du dépôt dans les environnements concernés. Les clés privilégiées Supabase ne doivent jamais être livrées au navigateur.

La RLS est obligatoire sur les tables applicatives. Les politiques de base et de Storage doivent suivre les droits métier et l'appartenance au tenant, avec refus d'accès en l'absence d'autorisation explicite.

Les vérifications doivent couvrir les accès permis et refusés, les comptes sans appartenance, les tentatives d'accès entre tenants, les écritures modifiant le rattachement et les tentatives d'écrasement de documents finaux ou de photos originales. Une authentification réussie ne suffit pas à autoriser l'accès à une donnée.

## Migrations et évolution

Toute évolution de schéma Supabase doit passer par une migration versionnée dans le dépôt GitHub privé. Cela comprend les tables, colonnes, relations, contraintes, index, politiques RLS, fonctions et déclencheurs concernés.

Une modification effectuée uniquement dans le dashboard ou par SQL ponctuel ne constitue pas une évolution livrable. Chaque lot de schéma doit permettre de reproduire le changement, vérifier les droits et l'isolation, et prévoir une stratégie de retour ou de correction qui préserve les données et versions conservées.

Le développement procède par petits lots testables et réversibles. Le code, les migrations et la documentation évoluent ensemble ; aucune stack ni aucun service n'est initialisé dans ce lot documentaire.

## Lot 0 technique — 23 octobre 2026

La nouvelle demande autorise le socle frontend après le lot documentaire décrit
ci-dessus, dont les principes restent applicables. React, TypeScript et Vite sont
initialisés sans module métier. `src/app/` porte uniquement la page de contrôle et
le démarrage ; aucune couche métier ou d'accès aux données n'est encore créée.

Le SDK client Supabase est installé mais non instancié : aucun projet réel, schéma,
authentification, migration ou stockage n'est configuré. `.env.example` liste
uniquement l'URL et la clé publique publiable attendues pour un raccordement futur.

La PWA comprend un manifeste, deux icônes PNG et un service worker de production
sans interception réseau, précache ni cache dynamique. Aucun fonctionnement hors
ligne ni stockage local de données n'est fourni. Les futurs échanges sensibles
devront aussi exclure la conservation par le cache HTTP via les en-têtes adaptés.
L'installation nécessite un navigateur compatible et HTTPS ou localhost.

Le build est prévu pour la racine du domaine Hostinger ; aucun déploiement n'est
effectué dans ce lot. Les instructions de contrôle et de retour arrière figurent
dans `README.md`.
