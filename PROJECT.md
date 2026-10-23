# SHADE — Cadrage du projet

## Finalité et priorité V1

SHADE est une application métier destinée aux professionnelles de l'esthétique. La V1 prioritaire couvre :

- les consentements ;
- le stock de produits et de lots ;
- la traçabilité cliente ↔ séance/prestation ↔ produits/lots ;
- le socle minimal cliente → prestation → séance.

Les prestations, leurs variantes et leurs workflows doivent être configurables. Le fonctionnement d'un métier ou d'une spécialité ne doit jamais être codé en dur.

## V1 bis

Le scan code-barres depuis mobile ou tablette accélérera la saisie des produits et lots. Cette fonction est classée en V1 bis et ne doit pas bloquer la sortie de la V1. Elle sera développée immédiatement après validation du noyau stock/lot.

## Périmètre reporté après V1/V1 bis

- Photos avant/après.
- Fonctions visuelles et retouche.
- Agenda avancé / Planity.
- Clôture de journée.
- Imports complexes.
- IA / Studio.

## Stack et hébergement cibles

- Frontend : React + TypeScript + Vite.
- Expérience : PWA responsive, utilisable sur tablette, petit PC et mobile.
- Backend : Supabase PostgreSQL, Auth, Storage privé et Row Level Security (RLS).
- Hébergement cible du frontend : Hostinger ; les services backend restent portés par Supabase.
- Dépôt GitHub privé : source de vérité du code, des migrations et de la documentation.

Ces choix définissent une cible. Cette intervention pose uniquement le socle documentaire : aucune fonctionnalité, aucune initialisation React, Vite ou Supabase.

## Principes non négociables

- Architecture multi-tenant dès l'origine, avec isolation des données entre organisations.
- Aucun secret dans Git, y compris dans les exemples, les logs ou l'historique.
- Toute évolution de schéma Supabase passe par une migration versionnée dans le dépôt.
- RLS obligatoire et testée pour protéger les données et vérifier l'isolation entre tenants.
- Documents et photos sensibles privés, avec accès limité aux personnes autorisées.
- Un document final ne peut pas être écrasé : toute correction crée une nouvelle version.
- Une photo originale ne peut jamais être écrasée : les transformations créent des fichiers distincts.
- SHADE Sign ne doit jamais être présenté comme une signature électronique qualifiée eIDAS. Son intitulé ne constitue pas une qualification juridique ou une certification.
- Le développement avance par petits lots testables et réversibles.

## Documents de référence

- [AGENTS.md](AGENTS.md) fixe les consignes de travail applicables à Codex.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) décrit les frontières techniques et les invariants de sécurité et de conservation.

Toute évolution structurante doit rester cohérente avec ces documents et mettre à jour la documentation concernée.
