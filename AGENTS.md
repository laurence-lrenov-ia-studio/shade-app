# Consignes de travail pour Codex

## Lecture préalable obligatoire

Avant toute modification structurante, Codex doit lire intégralement [PROJECT.md](PROJECT.md) et [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), puis vérifier que l'intervention respecte leurs principes.

Une modification structurante comprend notamment : initialisation de la stack, ajout de dépendances structurantes, organisation des modules, modèle de données, authentification, autorisations, stockage, cycle de vie documentaire ou déploiement.

## Périmètre et méthode

- Respecter le périmètre autorisé par l'utilisateur et éviter les ajouts accessoires.
- Pour l'intervention de fondation actuelle, créer uniquement `PROJECT.md`, `AGENTS.md` et `docs/ARCHITECTURE.md`. Ne développer aucune fonctionnalité et ne pas initialiser React, Vite ou Supabase. Toute implémentation ultérieure nécessite une nouvelle demande de l'utilisateur.
- Travailler par petits lots cohérents, testables et réversibles.
- Avant chaque lot, identifier le comportement attendu, les vérifications utiles et le moyen de revenir en arrière sans compromettre les données conservées.
- Vérifier les changements avec des contrôles adaptés au lot ; ne pas déclarer un contrôle réussi s'il n'a pas été exécuté.
- Préserver le travail existant de l'utilisateur et documenter les décisions structurantes.
- Utiliser le dépôt GitHub privé comme source de vérité du code, des migrations et de la documentation.

## Architecture et configuration métier

- Respecter la cible React + TypeScript + Vite, PWA responsive tablette/petit PC/mobile, Supabase et hébergement frontend Hostinger.
- Concevoir toute fonctionnalité avec l'isolation multi-tenant dès l'origine.
- Rendre les prestations, variantes et workflows configurables ; ne jamais coder en dur les règles propres à un métier.
- Ne pas considérer un filtre d'interface ou un identifiant de tenant fourni par le navigateur comme une autorisation.

## Données, migrations et sécurité

- Ne placer aucun secret dans Git. Les clés privilégiées ne doivent jamais être intégrées au frontend.
- Faire passer toute évolution de schéma Supabase par une migration versionnée, y compris les changements de contraintes, politiques RLS, fonctions ou déclencheurs liés au schéma.
- Ne pas effectuer de modification de schéma uniquement dans le dashboard ou par SQL ponctuel sans migration versionnée correspondante.
- Activer la RLS sur les tables applicatives et protéger les accès aux objets Storage par des politiques adaptées.
- Tester les accès autorisés et refusés, notamment entre tenants, pour la lecture, la création, la modification et la suppression selon les opérations disponibles.
- Garder les documents et photos sensibles dans un Storage privé ; vérifier les droits avant tout accès ou partage temporaire.

## Conservation et communication

- Ne jamais écraser un document final : une correction produit une nouvelle version liée à la précédente, qui reste conservée.
- Ne jamais écraser une photo originale : créer un objet distinct pour chaque dérivé ou retouche.
- Faire respecter ces invariants au niveau des données et du stockage, pas seulement dans l'interface.
- Ne jamais présenter SHADE Sign comme une signature électronique qualifiée eIDAS, dans le code visible, l'interface, la documentation ou les textes commerciaux.

## Restitution d'un lot

Indiquer ce qui a changé, les fichiers concernés, les vérifications exécutées et les limites éventuelles. Pour un lot documentaire, confirmer explicitement l'absence de code applicatif ajouté.
