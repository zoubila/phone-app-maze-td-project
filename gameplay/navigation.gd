extends RefCounted
## Ce fichier calcule les chemins des monstres terrestres.
## Le paramètre game représente la partie en cours : on y lit la grille et les tours.
## Les distances sont des nombres de pas jusqu'au château, pas des distances graphiques à l'écran.


## Vérifie si cell désigne une case qui existe sur la carte.
## Renvoie true si ses coordonnées sont valides, ou false si elle est hors de la grille.
static func inside(game, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < game.cols and cell.y < game.rows


## Transforme une position de grille (x, y) en numéro de case.
## Ce numéro permet de ranger les distances dans une liste simple plutôt que dans un tableau à deux dimensions.
static func cell_id(game, cell: Vector2i) -> int:
	return cell.y * game.cols + cell.x


## Calcule, pour chaque case, le nombre minimal de pas nécessaires pour atteindre le château.
## Une distance de -1 signifie que la case est inaccessible ; le château a une distance de 0.
## ignored permet de faire le calcul comme si une tour avait disparu, sans vraiment la détruire.
## La liste renvoyée est un résultat temporaire : elle ne remplace pas encore le chemin utilisé par les monstres.
static func field_without(game, ignored := Vector2i(-1, -1)) -> PackedInt32Array:
	# La taille de la grille reste constante pendant ce calcul.
	var columns: int = game.cols
	var rows: int = game.rows

	# Une valeur par case indique si une tour la bloque. PackedByteArray stocke ces petites valeurs de façon compacte.
	var blocked: PackedByteArray = PackedByteArray()
	blocked.resize(columns * rows)

	for cell in game.towers:
		if cell != ignored:
			blocked[game.cell_id(cell)] = 1

	# Au départ, toutes les cases sont supposées inaccessibles (-1). La recherche remplacera les valeurs atteintes.
	var distances: PackedInt32Array = PackedInt32Array()
	distances.resize(columns * rows)
	distances.fill(-1)

	# La file garde les numéros de cases à examiner : head lit la prochaine case, tail ajoute la suivante.
	# On part du château et on découvre ses voisins, puis les voisins de ses voisins : c'est un parcours en largeur.
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(columns * rows)

	var head: int = 0
	var tail: int = 1
	var goal: int = game.cell_id(game.exit_cell)
	queue[0] = goal
	distances[goal] = 0

	# Toutes les étapes ont le même coût. La première visite d'une case donne donc son nombre minimal de pas.
	while head < tail:
		var current: int = queue[head]
		head += 1

		var x: int = current % columns
		var y: int = current / columns

		for neighbor in [
			current + 1 if x + 1 < columns else -1,
			current + columns if y + 1 < rows else -1,
			current - columns if y > 0 else -1,
			current - 1 if x > 0 else -1,
		]:
			if neighbor >= 0 and distances[neighbor] == -1 and blocked[neighbor] == 0:
				distances[neighbor] = distances[current] + 1
				queue[tail] = neighbor
				tail += 1
	return distances


## Choisit le prochain déplacement d'un monstre depuis la case cell.
## Il faut une case voisine dont la distance au château est plus petite que la distance actuelle.
## Les déplacements diagonaux sont interdits. Sans voisin accessible, la fonction renvoie la case de départ.
static func next_cell(game, cell: Vector2i, distances: PackedInt32Array) -> Vector2i:
	var distance = distances[game.cell_id(cell)]

	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
		var next: Vector2i = cell + direction

		if game.inside(next) and distances[game.cell_id(next)] >= 0 and distances[game.cell_id(next)] < distance:
			return next
	return cell


## Met à jour les distances et le chemin affiché après l'ajout ou le retrait d'une tour.
## Un monstre entre deux cases termine son déplacement avant de choisir un nouveau chemin.
## Le compteur revision prévient le dessin du plateau que la ligne du chemin doit être reconstruite.
static func rebuild_flow(game) -> void:
	game.flow = game.field_without()
	game.route.clear()

	var cell = game.entry

	if game.flow[game.cell_id(cell)] >= 0:
		game.route.append(cell)

		while cell != game.exit_cell:
			cell = game.next_cell(cell, game.flow)
			game.route.append(cell)

	for enemy in game.enemies:
		if not enemy.air and enemy.hp > 0 and enemy.fraction <= 0.000001:
			enemy.next = game.next_cell(enemy.cell, game.flow)

	# Le dessinateur compare ce numéro à celui de son dernier dessin du chemin pour savoir si son cache est périmé.
	game.revision += 1
