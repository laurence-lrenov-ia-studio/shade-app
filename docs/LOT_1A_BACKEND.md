# SHADE — Lot 1A backend stock, produits et lots

## Périmètre validé

Le backend local du Lot 1A couvre :

- `tenants` ;
- `tenant_memberships` ;
- `products` ;
- `product_lots` ;
- `stock_movements` ;
- calcul du stock courant ;
- politiques RLS ;
- tests d'isolation tenant et de journal de stock ;
- Storage privé optionnel pour la photo/scan d'étiquette d'un lot.

Aucune interface, aucune cliente, aucune séance, aucun `session_lot_usage`, aucun
scan code-barres et aucune intégration externe ne sont ajoutés.

## Modèle métier

`products` décrit un produit générique et porte son unité. Cette unité est immuable après création afin de préserver le sens des quantités historiques.

`product_lots` porte le numéro de lot, la quantité initiale, les dates de réception,
d'ouverture et de péremption, l'emplacement et, de façon optionnelle,
`label_object_path` vers l'étiquette privée du lot.

`stock_movements` est un journal append-only. La quantité initiale d'un lot produit
automatiquement le premier mouvement de type `initial`. Le stock courant n'est
pas stocké dans une colonne modifiable : la vue `product_lot_stock` le calcule par
somme des mouvements.

Les mouvements sont génériques : `initial`, `receipt`, `issue`, `adjustment` et
`loss`. Ils ne dépendent d'aucune prestation esthétique.

## Isolation tenant

Chaque table métier porte `tenant_id`. Les relations lot → produit et mouvement →
lot utilisent des clés étrangères composites incluant `tenant_id`, afin qu'une
association inter-tenant soit refusée au niveau relationnel en plus de la RLS.

Les politiques RLS autorisent un utilisateur authentifié uniquement lorsqu'une
ligne `tenant_memberships` existe pour son `auth.uid()` et le tenant visé. La
création d'un tenant crée automatiquement l'appartenance de son créateur.

## Journal de stock

`stock_movements` est non modifiable par le rôle applicatif : les erreurs sont
corrigées par un nouveau mouvement. Un trigger sérialise les écritures par lot et
refuse un mouvement qui rendrait le stock négatif.

## Storage étiquette

Le bucket `lot-labels` est privé. Les objets suivent la convention :

`<tenant_id>/<product_lot_id>/<filename>`

Les politiques sur `storage.objects` n'autorisent la lecture et l'ajout que si
l'utilisateur authentifié est membre du tenant et si le lot du chemin appartient
à ce même tenant. Aucun accès `anon` n'est ouvert.

Dans cette passe, aucune politique applicative `UPDATE` ou `DELETE` n'est ajoutée
pour les objets d'étiquette. La référence du lot peut pointer vers un nouvel objet,
mais l'ancien objet n'est pas écrasé par cette logique.

## Tests locaux exécutés

Après initialisation de la stack Supabase locale, les migrations 1A.1 à 1A.4 ont
été appliquées, puis les tests pgTAP ont été exécutés avec succès : 24 tests sur 24.

Un `supabase db reset` a ensuite recréé la base à vide, réappliqué les quatre
migrations et les 24 tests ont de nouveau obtenu `Result: PASS`.

La migration Storage et son test pgTAP doivent être validés de la même manière :
reset local, puis `supabase test db`.
